//
//  Created by Anton Spivak
//

// MARK: - GenerationSchema.Validator

public extension GenerationSchema {
    /// A local validator for generated content.
    ///
    /// Validators aren't encoded in JSON Schema and may run more than once. They must be
    /// deterministic and have no side effects.
    ///
    /// ```swift
    /// struct EvenInteger: GenerationSchema.Validator {
    ///     typealias Value = Int
    ///
    ///     let expected = "an even integer"
    ///
    ///     func matches(_ content: GeneratedContent) -> Bool {
    ///         guard case let .integer(integer) = content,
    ///               let value = Int(exactly: integer)
    ///         else { return false }
    ///
    ///         return value.isMultiple(of: 2)
    ///     }
    /// }
    ///
    /// let schema = try Int.generationSchema.validating(EvenInteger())
    /// ```
    protocol Validator: Hashable, Sendable, CustomStringConvertible {
        /// The type of value the validator applies to.
        associatedtype Value: Generable

        /// A description of valid content.
        var expected: String { get }

        /// Tests generated content.
        ///
        /// - Parameter content: The content to test.
        /// - Returns: `true` if the content is valid.
        func matches(_ content: GeneratedContent) -> Bool
    }
}

public extension GenerationSchema.Validator {
    var description: String { expected }
}
