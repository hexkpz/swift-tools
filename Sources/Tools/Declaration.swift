//
//  Created by Anton Spivak
//

import Generable

// MARK: - Declaration

/// A tool's name, description, and schemas.
public struct Declaration: Sendable {
    // MARK: Lifecycle

    init<ToolType: Tool>(
        _ tool: ToolType,
        name: String,
        description: String,
    ) throws {
        try self.init(
            name: name,
            description: description,
            arguments: ToolType.Arguments.generationSchema,
            output: ToolType.Output.generationSchema,
        )
    }

    /// Creates a tool declaration.
    ///
    /// - Parameters:
    ///   - name: The tool name.
    ///   - description: The description exposed to the model.
    ///   - arguments: The argument schema.
    ///   - output: The output schema.
    public init(
        name: String,
        description: String,
        arguments: GenerationSchema,
        output: GenerationSchema,
    ) {
        self.name = name
        self.description = description
        self.arguments = arguments
        self.output = output
    }

    // MARK: Public

    /// The tool name.
    public let name: String

    /// The description exposed to the model.
    public let description: String

    /// The argument schema.
    public let arguments: GenerationSchema

    /// The output schema.
    public let output: GenerationSchema
}

// MARK: Identifiable

extension Declaration: Identifiable {
    public var id: String { name }
}

// MARK: CustomStringConvertible

extension Declaration: CustomStringConvertible {}

// MARK: CustomDebugStringConvertible

extension Declaration: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        Declaration(
          name: \(String(reflecting: name)),
          description: \(String(reflecting: description)),
          arguments: \(String(reflecting: arguments)),
          output: \(String(reflecting: output))
        )
        """
    }
}
