//
//  Created by Anton Spivak
//

// MARK: - GeneratedContentEncoder

/// An encoder that converts ``Generable`` values to ``GeneratedContent``.
///
/// The encoder obtains the value's ``Generable/generationSchema`` and validates the completed
/// content against that schema.
///
/// ```swift
/// let encoder = GeneratedContentEncoder()
/// let content = try encoder.encode(value)
/// ```
public struct GeneratedContentEncoder: Sendable {
    // MARK: Lifecycle

    /// Creates a generated-content encoder.
    public init() {}

    // MARK: Public

    /// Encodes and validates a generable value.
    ///
    /// - Parameter value: The value to encode.
    /// - Returns: The encoded content.
    public func encode<Value: Generable>(_ value: borrowing Value) throws -> GeneratedContent {
        try encode(value, using: Value.generationSchema)
    }

    /// Encodes and validates a generable value using a supplied schema.
    ///
    /// Use this overload to reuse a previously constructed schema. The schema must describe the
    /// generated representation of `Value`.
    ///
    /// - Parameters:
    ///   - value: The value to encode.
    ///   - schema: The schema used to encode and validate the value.
    /// - Returns: The encoded content.
    public func encode<Value: Generable>(
        _ value: borrowing Value,
        using schema: borrowing GenerationSchema,
    ) throws -> GeneratedContent {
        var encoder = try GenerationEncoder(
            node: schema.graph.root.node,
            references: schema.graph.references,
        )

        try value.encode(to: &encoder)
        return try encoder.finish()
    }
}
