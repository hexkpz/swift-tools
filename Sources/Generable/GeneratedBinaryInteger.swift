//
//  Created by Anton Spivak
//

/// A binary integer type that preserves its precision in generated content.
///
/// Conforming types must encode themselves as a single integer value. If an encoder can't
/// represent a value, the implementation must throw instead of encoding another JSON type.
public protocol GeneratedBinaryInteger: BinaryInteger, Encodable, Sendable {}
