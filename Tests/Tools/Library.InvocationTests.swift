//
//  Created by Anton Spivak
//

import Testing
import Synchronization
import Tools

// MARK: - SchemaAccesses

private enum SchemaAccesses {
    static let counts = Mutex((arguments: 0, output: 0))

    static var value: (arguments: Int, output: Int) {
        counts.withLock { $0 }
    }

    static func reset() {
        counts.withLock { $0 = (0, 0) }
    }

    static func incrementArguments() {
        counts.withLock { $0.arguments += 1 }
    }

    static func incrementOutput() {
        counts.withLock { $0.output += 1 }
    }
}

// MARK: - SchemaTrackedArguments

private struct SchemaTrackedArguments: Generable {
    // MARK: Lifecycle

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: inout GenerationDecoder) throws {
        self.value = try String(from: &decoder)
    }

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) {
            SchemaAccesses.incrementArguments()
            return try .string()
        }
    }

    let value: String

    func encode(to encoder: inout GenerationEncoder) throws {
        try value.encode(to: &encoder)
    }
}

// MARK: - SchemaTrackedOutput

private struct SchemaTrackedOutput: Generable {
    // MARK: Lifecycle

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: inout GenerationDecoder) throws {
        self.value = try String(from: &decoder)
    }

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) {
            SchemaAccesses.incrementOutput()
            return try .string()
        }
    }

    let value: String

    func encode(to encoder: inout GenerationEncoder) throws {
        try value.encode(to: &encoder)
    }
}

// MARK: - SchemaTrackedTool

private struct SchemaTrackedTool: Tool {
    let name = "schema-tracked"
    let description = "Tracks schema construction."

    func perform(
        with arguments: SchemaTrackedArguments,
        in _: ApplicationContext,
    ) async throws -> SchemaTrackedOutput {
        .init(arguments.value)
    }
}

// MARK: - ConsumerError

private enum ConsumerError: Swift.Error {
    case unavailable
}

// MARK: - InvalidOutput

private struct InvalidOutput: Generable {
    // MARK: Lifecycle

    init() {}

    init(from _: inout GenerationDecoder) throws {
        throw ConsumerError.unavailable
    }

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) { try String.generationSchema }
    }

    func encode(to _: inout GenerationEncoder) throws {
        throw ConsumerError.unavailable
    }
}

// MARK: - InvalidOutputTool

private struct InvalidOutputTool: Tool {
    let name = "invalid-output"
    let description = "Produces an output that can't be encoded."

    func perform(
        with _: Arguments,
        in _: ApplicationContext,
    ) async throws -> InvalidOutput {
        InvalidOutput()
    }
}

@Test
func `model-facing failures are isolated from successful calls`() async throws {
    let library = Library<ApplicationContext>()
    try library.insert(prefixTool())
    try library.insert(StringTool(name: "failing") { _, _ in
        throw Tools::Failure("Try another value.")
    })

    let results = try await library.perform(
        [
            Call(id: "unknown", named: "missing", with: content()),
            Call(id: "invalid", named: "prefix", with: .string("invalid")),
            Call(id: "failure", named: "failing", with: content()),
            Call(id: "success", named: "prefix", with: content()),
        ],
        in: context,
    )

    let unknown = try #require(results[0].output.error as? Tools::Failure)
    let invalid = try #require(results[1].output.error as? Tools::Failure)
    let failure = try #require(results[2].output.error as? Tools::Failure)

    #expect(unknown.message.contains("Unknown tool"))
    #expect(invalid.message.contains("Invalid arguments"))
    #expect(failure.message == "Try another value.")
    #expect(try generatedContentDecoder.decode(
        String.self,
        from: results[3].output.get(),
    ) == "before value")
}

@Test
func `consumer-facing errors retain their type`() async throws {
    let library = Library<ApplicationContext>()
    try library.insert(StringTool(name: "throwing") { _, _ in
        throw ConsumerError.unavailable
    })
    try library.insert(InvalidOutputTool())

    let results = try await library.perform(
        [
            Call(named: "throwing", with: content()),
            Call(named: "invalid-output", with: content()),
        ],
        in: context,
    )

    #expect(results[0].output.error is ConsumerError)
    guard let error = results[1].output.error as? Tools::Error,
          case let .invalidOutput(name, _) = error
    else {
        Issue.record("Expected an invalid output error.")
        return
    }

    #expect(name == "invalid-output")
}

@Test
func `invocations reuse their declared schemas`() async throws {
    SchemaAccesses.reset()

    let library = Library<ApplicationContext>()
    try library.insert(SchemaTrackedTool())
    #expect(SchemaAccesses.value == (arguments: 1, output: 1))

    let results = try await library.perform(
        [
            Call(named: "schema-tracked", with: .string("first")),
            Call(named: "schema-tracked", with: .string("second")),
        ],
        in: context,
    )

    #expect(SchemaAccesses.value == (arguments: 1, output: 1))
    #expect(results.count == 2)
    for result in results {
        guard case .string = try result.output.get() else {
            Issue.record("Expected a string output.")
            continue
        }
    }
}
