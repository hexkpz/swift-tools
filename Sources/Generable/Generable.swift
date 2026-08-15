//
//  Created by Anton Spivak
//

// MARK: - Generable

/// A type that can be represented as ``GeneratedContent``.
///
/// Use ``Generable(description:)`` to synthesize a conformance.
/// Implement the requirements directly when the generated representation needs custom behavior:
///
/// ```swift
/// struct Coordinate: Generable {
///     let x: Int
///     let y: Int
///
///     static var generationSchema: GenerationSchema {
///         get throws(Generable::Error) {
///             try .structure(
///                 name: "Coordinate",
///                 properties: [
///                     .init(name: "x", type: Int.self),
///                     .init(name: "y", type: Int.self),
///                 ]
///             )
///         }
///     }
///
///     init(from decoder: inout GenerationDecoder) throws {
///         x = try decoder.decode(forProperty: "x")
///         y = try decoder.decode(forProperty: "y")
///     }
///
///     func encode(to encoder: inout GenerationEncoder) throws {
///         try encoder.encode(x, forProperty: "x")
///         try encoder.encode(y, forProperty: "y")
///     }
/// }
/// ```
public protocol Generable: Sendable {
    /// The schema for this type's generated representation.
    static var generationSchema: GenerationSchema { get throws(Error) }

    /// Decodes a value.
    ///
    /// - Parameter decoder: The generation decoder.
    init(from decoder: inout GenerationDecoder) throws

    /// Encodes the value.
    ///
    /// - Parameter encoder: The generation encoder.
    func encode(to encoder: inout GenerationEncoder) throws
}
