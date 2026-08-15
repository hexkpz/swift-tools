//
//  Created by Anton Spivak
//

// MARK: - GeneratedContentDecoder

/// A decoder that converts ``GeneratedContent`` to ``Generable`` values.
///
/// The decoder obtains the value type's ``Generable/generationSchema`` and validates the input
/// against that schema.
///
/// ```swift
/// let decoder = GeneratedContentDecoder()
/// let value = try decoder.decode(Value.self, from: content)
/// ```
public struct GeneratedContentDecoder: Sendable {
    // MARK: Lifecycle

    /// Creates a generated-content decoder.
    public init() {}

    // MARK: Public

    /// Decodes and validates a generable value.
    ///
    /// - Parameters:
    ///   - type: The value type.
    ///   - content: The content to decode.
    /// - Returns: The decoded value.
    public func decode<Value: Generable>(
        _ type: Value.Type = Value.self,
        from content: consuming GeneratedContent,
    ) throws -> Value {
        try decode(type, from: consume content, using: Value.generationSchema)
    }

    /// Decodes and validates a generable value using a supplied schema.
    ///
    /// Use this overload to reuse a previously constructed schema. The schema must describe the
    /// generated representation of `Value`.
    ///
    /// - Parameters:
    ///   - type: The value type.
    ///   - content: The content to decode.
    ///   - schema: The schema used to decode and validate the value.
    /// - Returns: The decoded value.
    public func decode<Value: Generable>(
        _ type: Value.Type = Value.self,
        from content: consuming GeneratedContent,
        using schema: GenerationSchema,
    ) throws -> Value {
        var decoder = try GenerationDecoder(
            node: schema.graph.root.node,
            references: schema.graph.references,
            content: consume content,
        )

        let value = try type.init(from: &decoder)
        try decoder.finish()

        return value
    }
}
