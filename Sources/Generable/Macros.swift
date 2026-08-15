//
//  Created by Anton Spivak
//

/// Synthesizes a ``Generable`` conformance for a structure or enumeration.
///
/// Stored properties and enumeration cases define the generated representation.
///
/// ```swift
/// @Generable(description: "A movie recommendation")
/// struct Movie {
///     @Guide(description: "The title")
///     var title: String
///
///     @Guide(description: "A score from 1 through 5", .range(1 ... 5))
///     var score: Int
/// }
/// ```
///
/// - Parameter description: The schema description.
@attached(
    extension,
    conformances: Generable,
    names:
    named(generationSchema),
    named(init(from:)),
    named(encode(to:))
)
public macro Generable(
    description: String? = nil,
) = #externalMacro(module: "GenerableMacros", type: "GenerableMacro")

/// Excludes a stored property from generated schemas and content.
///
/// The property must declare a default value, which it keeps when the containing value is decoded.
///
/// ```swift
/// @Generable
/// struct Request {
///     var query: String
///
///     @GenerableIgnored
///     var attempt = 0
/// }
/// ```
@attached(peer)
public macro GenerableIgnored() = #externalMacro(
    module: "GenerableMacros",
    type: "GenerableIgnoredMacro",
)

/// Adds a description to a generated property.
///
/// - Parameter description: The property description.
@attached(peer)
public macro Guide(
    description: String,
) = #externalMacro(module: "GenerableMacros", type: "GuideMacro")

/// Adds guides and a description to a generated property.
///
/// - Parameters:
///   - description: The property description.
///   - guides: The guides to apply.
@attached(peer)
public macro Guide<Value: Generable>(
    description: String? = nil,
    _ guides: GenerationGuide<Value>...,
) = #externalMacro(module: "GenerableMacros", type: "GuideMacro")
