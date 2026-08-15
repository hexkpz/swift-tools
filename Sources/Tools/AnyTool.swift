//
//  Created by Anton Spivak
//

import Generable

// MARK: - AnyTool

struct AnyTool<Context: Sendable>: Sendable {
    // MARK: Lifecycle

    init<ToolType: Tool>(
        _ tool: ToolType,
        name: String,
        description: String,
    ) throws where ToolType.Context == Context {
        try Task.checkCancellation()

        let declaration: Declaration
        do {
            declaration = try Declaration(tool, name: name, description: description)
        } catch {
            // Building a schema can run custom Generable code. Preserve cancellation instead of
            // reporting it as an invalid declaration.
            try Task.checkCancellation()
            throw Error.invalidDeclaration(name: name, reason: String(describing: error))
        }

        self.declaration = declaration

        self._perform = {
            let arguments: ToolType.Arguments
            do {
                let decoder = GeneratedContentDecoder()
                let schema = declaration.arguments

                arguments = try decoder.decode(ToolType.Arguments.self, from: $0, using: schema)
            } catch let error as CancellationError {
                throw error
            } catch {
                // Argument errors can help the model correct its call. Cancellation must remain
                // cancellation.
                try Task.checkCancellation()
                throw Failure("Invalid arguments for tool \(String(reflecting: name)): \(error)")
            }

            try Task.checkCancellation()
            let output: ToolType.Output
            do {
                output = try await tool.perform(with: arguments, in: $1)
            } catch {
                // Prefer cancellation when the task was canceled while the tool was running.
                try Task.checkCancellation()
                throw error
            }

            try Task.checkCancellation()
            do {
                let encoder = GeneratedContentEncoder()
                let schema = declaration.output

                return try encoder.encode(output, using: schema)
            } catch let error as CancellationError {
                throw error
            } catch {
                // An unencodable output violates the tool contract and must not reach the model.
                try Task.checkCancellation()
                throw Error.invalidOutput(name: name, reason: String(describing: error))
            }
        }
    }

    // MARK: Internal

    let declaration: Declaration

    @inline(__always)
    func perform(
        with arguments: GeneratedContent,
        in context: Context,
    ) async throws -> GeneratedContent {
        try await _perform(arguments, context)
    }

    // MARK: Private

    private let _perform: @Sendable (GeneratedContent, Context) async throws -> GeneratedContent
}
