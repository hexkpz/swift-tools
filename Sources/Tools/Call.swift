//
//  Created by Anton Spivak
//

import Generable

// MARK: - Call

/// A request to call a tool.
public struct Call: Sendable {
    // MARK: Lifecycle

    /// Creates a tool call.
    ///
    /// - Parameters:
    ///   - id: An optional identifier for matching the result.
    ///   - name: The tool name.
    ///   - arguments: The tool arguments.
    public init(
        id: String? = nil,
        named name: String,
        with arguments: consuming GeneratedContent,
    ) {
        self.id = id
        self.name = name
        self.arguments = consume arguments
    }

    // MARK: Public

    /// An optional identifier for matching the result.
    public let id: String?

    /// The tool name.
    public let name: String

    /// The tool arguments.
    public let arguments: GeneratedContent
}

// MARK: Call.Result

public extension Call {
    /// The result of a tool call.
    struct Result: Sendable {
        // MARK: Lifecycle

        init(
            call: consuming Call,
            output: consuming Swift.Result<Output, any Swift.Error>,
        ) {
            self.call = consume call
            self.output = consume output
        }

        // MARK: Public

        /// Preserves ignored properties on the Swift value.
        public typealias Output = (value: any Generable, content: GeneratedContent)

        /// The original call.
        public let call: Call

        /// The output or error.
        public let output: Swift.Result<Output, any Swift.Error>

        /// The call identifier.
        public var id: String? { call.id }

        /// The tool name.
        public var name: String { call.name }
    }
}

// MARK: CustomStringConvertible

extension Call: CustomStringConvertible {
    public var description: String {
        "\(id ?? "nil") -> \(name)(\(arguments.description))"
    }
}

// MARK: CustomDebugStringConvertible

extension Call: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        Call(
          id: \(String(reflecting: id)),
          name: \(String(reflecting: name)),
          arguments: \(arguments.description)
        )
        """
    }
}

// MARK: - Call.Result + CustomStringConvertible

extension Call.Result: CustomStringConvertible {
    public var description: String {
        "\(id ?? "nil") <- \(name)(\(outputDescription))"
    }

    private var outputDescription: String {
        switch output {
        case let .success(output): output.content.description
        case let .failure(error): "error: \(String(describing: error))"
        }
    }
}

// MARK: - Call.Result + CustomDebugStringConvertible

extension Call.Result: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        Call.Result(
          id: \(String(reflecting: id)),
          name: \(String(reflecting: name)),
          output: \(outputDebugDescription)
        )
        """
    }

    private var outputDebugDescription: String {
        switch output {
        case let .success(output): ".success(\(String(reflecting: output.content)))"
        case let .failure(error): ".failure(\(String(reflecting: error)))"
        }
    }
}
