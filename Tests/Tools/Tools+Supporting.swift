//
//  Created by Anton Spivak
//

import Tools

// MARK: - Arguments

@Generable
struct Arguments: Equatable {
    var value: String
}

// MARK: - ApplicationContext

struct ApplicationContext: Sendable {
    let prefix: String
    let suffix: String
}

let context = ApplicationContext(prefix: "before ", suffix: " after")

// MARK: - StringTool

struct StringTool<Context: Sendable>: Tool {
    // MARK: Lifecycle

    init(
        name: String,
        description: String = "A test tool.",
        perform: @escaping @Sendable (Arguments, Context) async throws -> String,
    ) {
        self.name = name
        self.description = description
        self.operation = perform
    }

    // MARK: Internal

    let name: String
    let description: String

    func perform(
        with arguments: Arguments,
        in context: Context,
    ) async throws -> String {
        try await operation(arguments, context)
    }

    // MARK: Private

    private let operation: @Sendable (Arguments, Context) async throws -> String
}

func prefixTool(name: String = "prefix") -> StringTool<ApplicationContext> {
    StringTool(name: name, description: "Adds the context prefix.") { arguments, context in
        context.prefix + arguments.value
    }
}

func suffixTool(name: String = "suffix") -> StringTool<ApplicationContext> {
    StringTool(name: name, description: "Adds the context suffix.") { arguments, context in
        arguments.value + context.suffix
    }
}

func content(_ value: String = "value") throws -> GeneratedContent {
    try GeneratedContent(Arguments(value: value))
}

extension Swift.Result {
    var error: Failure? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}
