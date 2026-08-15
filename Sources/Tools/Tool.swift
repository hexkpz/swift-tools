//
//  Created by Anton Spivak
//

@_exported import Generable

// MARK: - Tool

/// A tool that a model can call.
///
/// Throw ``Failure`` for an error that the model can act on.
///
/// ```swift
/// struct GreetingTool: Tool {
///     @Generable
///     struct Arguments {
///         @Guide(description: "The person's name")
///         var name: String
///     }
///
///     let name = "greet"
///     let description = "Creates a greeting."
///
///     func perform(with arguments: Arguments, in _: Void) async throws -> String {
///         guard !arguments.name.isEmpty else {
///             throw Failure("Provide a name.")
///         }
///         return "Hello, \(arguments.name)!"
///     }
/// }
/// ```
public protocol Tool<Context>: Sendable {
    /// Information passed to the tool when it runs.
    associatedtype Context: Sendable = Void

    /// The arguments accepted by the tool.
    associatedtype Arguments: Generable

    /// The tool's output.
    associatedtype Output: Generable

    /// The tool name.
    var name: String { get }

    /// The description exposed to the model.
    var description: String { get }

    /// Runs the tool.
    ///
    /// - Parameters:
    ///   - arguments: The decoded arguments for the call.
    ///   - context: The context for this call.
    /// - Returns: The tool output.
    /// - Throws: ``Failure`` for a problem that the model can correct, or another error if the
    ///   operation fails.
    func perform(with arguments: Arguments, in context: Context) async throws -> Output
}

// MARK: - Tool where Context == Void

public extension Tool where Context == Void {
    /// Runs a tool that doesn't require a context value.
    ///
    /// - Parameter arguments: The decoded arguments for the call.
    /// - Returns: The tool output.
    /// - Throws: ``Failure`` for a problem that the model can correct, or another error if the
    ///   operation fails.
    func perform(with arguments: Arguments) async throws -> Output {
        try await perform(with: arguments, in: ())
    }
}
