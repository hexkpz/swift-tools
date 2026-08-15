//
//  Created by Anton Spivak
//

import Testing
import Tools

// MARK: - InvalidSchema

private struct InvalidSchema: Generable {
    // MARK: Lifecycle

    init(from _: inout GenerationDecoder) throws {
        throw Generable::Error.undefinedReference("Missing")
    }

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) { throw .undefinedReference("Missing") }
    }

    func encode(to _: inout GenerationEncoder) throws {
        throw Generable::Error.undefinedReference("Missing")
    }
}

// MARK: - InvalidDeclarationTool

private struct InvalidDeclarationTool: Tool {
    let name = "invalid"
    let description = "Has an invalid argument schema."

    func perform(with _: InvalidSchema, in _: ApplicationContext) async throws -> String {
        "unreachable"
    }
}

@Test
func `library exposes declarations and removes tools by name`() throws {
    let library = Library<ApplicationContext>()
    let tool = prefixTool()

    try library.insert(tool)
    try library.insert(suffixTool())

    let declaration = try #require(library.declaration(named: tool.name))
    #expect(declaration.name == tool.name)
    #expect(declaration.description == tool.description)
    #expect(try declaration.arguments == Arguments.generationSchema)
    #expect(try declaration.output == String.generationSchema)
    #expect(library.declarations.map(\.name) == ["prefix", "suffix"])

    let removed = library.remove(named: tool.name)
    #expect(removed)
    #expect(library.declaration(named: tool.name) == nil)

    let removedAgain = library.remove(named: tool.name)
    #expect(!removedAgain)
}

@Test
func `library rejects empty and duplicate names`() throws {
    let library = Library<ApplicationContext>()
    try library.insert(prefixTool())

    #expect(throws: Tools::Error.invalidName) {
        try library.insert(StringTool(name: "") { arguments, _ in arguments.value })
    }
    #expect(throws: Tools::Error.duplicateName("prefix")) {
        try library.insert(prefixTool())
    }
}

@Test
func `invalid declarations don't mutate the library`() {
    let library = Library<ApplicationContext>()

    #expect {
        try library.insert(InvalidDeclarationTool())
    } throws: { error in
        guard let error = error as? Tools::Error,
              case let .invalidDeclaration(name, _) = error
        else { return false }
        return name == "invalid"
    }

    #expect(library.declaration(named: "invalid") == nil)
}

@Test
func `library copies share their state`() throws {
    let library = Library<ApplicationContext>(name: "shared")
    #expect(library.logger?.label == nil)

    let copy = library
    let independent = Library<ApplicationContext>(name: "shared")

    try copy.insert(prefixTool())
    copy.logger = Logger(label: "updated")

    #expect(library.declaration(named: "prefix") != nil)
    #expect(library.logger?.label == "updated")
    #expect(independent.declaration(named: "prefix") == nil)

    library.remove(named: "prefix")
    #expect(copy.declaration(named: "prefix") == nil)
}

@Test
func `library dispatches calls with their shared context`() async throws {
    let library = Library<ApplicationContext>()
    try library.insert(prefixTool())
    try library.insert(suffixTool())

    let results = try await library.perform(
        [
            Call(id: "first", named: "prefix", with: content()),
            Call(id: "second", named: "suffix", with: content()),
        ],
        in: context,
    )

    #expect(results.map(\.id) == ["first", "second"])
    #expect(try generatedContentDecoder.decode(
        String.self,
        from: results[0].output.get(),
    ) == "before value")
    #expect(try generatedContentDecoder.decode(
        String.self,
        from: results[1].output.get(),
    ) == "value after")
}

@Test
func `library performs a single call with its shared context`() async throws {
    let library = Library<ApplicationContext>()
    try library.insert(prefixTool())

    let result = try await library.perform(
        Call(id: "single", named: "prefix", with: content()),
        in: context,
    )

    #expect(result.id == "single")
    #expect(try generatedContentDecoder.decode(
        String.self,
        from: result.output.get(),
    ) == "before value")
}

@Test
func `void library performs calls without an explicit context`() async throws {
    let library = Library<Void>()
    try library.insert(StringTool(name: "identity") { arguments, _ in arguments.value })

    let results = try await library.perform([
        Call(named: "identity", with: content("hello")),
    ])

    #expect(try generatedContentDecoder.decode(
        String.self,
        from: results[0].output.get(),
    ) == "hello")
}

@Test
func `void library performs a single call without an explicit context`() async throws {
    let library = Library<Void>()
    try library.insert(StringTool(name: "identity") { arguments, _ in arguments.value })

    let result = try await library.perform(
        Call(id: "single", named: "identity", with: content("hello")),
    )

    #expect(result.id == "single")
    #expect(try generatedContentDecoder.decode(
        String.self,
        from: result.output.get(),
    ) == "hello")
}
