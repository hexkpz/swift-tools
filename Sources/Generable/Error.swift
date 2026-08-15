//
//  Created by Anton Spivak
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

// MARK: - Error

/// An error from schema construction or generated content conversion.
public enum Error: Swift::Error, Sendable, Hashable {
    /// A schema constraint is invalid or violated.
    case constraintViolation(String)

    /// Generated content doesn't match its schema.
    case invalidValue(expected: String)

    /// A required object property is missing.
    case missingProperty(String)

    /// Two definitions use the same reference name.
    case duplicateDefinition(String)

    /// A value can't be represented as generated content.
    case unrepresentableValue(String)

    /// A schema references an undefined definition.
    case undefinedReference(String)

    /// Schema references form an unproductive cycle.
    case unproductiveReferenceCycle(String)

    /// An object contains an undeclared property.
    case unexpectedProperty(String)
}

extension Error {
    static func duplicateObjectPropertyNames() -> Self {
        .invalidValue(expected: "unique object property names")
    }

    static func unsupported(_ constraint: GenerationSchema.Constraint, for schema: String) -> Self {
        .constraintViolation("\(constraint) is not supported by \(schema).")
    }
}

#if canImport(FoundationEssentials) || canImport(Foundation)

extension Error: LocalizedError {
    public var errorDescription: String? { description }
}

#endif

// MARK: CustomStringConvertible

extension Error: CustomStringConvertible {
    // swiftformat:disable wrap wrapArguments
    public var description: String {
        switch self {
        case let .constraintViolation(message): message
        case let .invalidValue(expected): "Expected \(expected)."
        case let .missingProperty(property): "Missing property \(property)."
        case let .duplicateDefinition(definition): "Duplicate schema definition \(definition)."
        case let .unrepresentableValue(value): "Cannot represent \(value) as generated content."
        case let .undefinedReference(reference): "Undefined schema reference \(reference)."
        case let .unproductiveReferenceCycle(reference): "Schema reference cycle at \(reference) does not consume generated content."
        case let .unexpectedProperty(property): "Unexpected property \(property)."
        }
    }
    // swiftformat:enable wrap wrapArguments
}

// MARK: CustomDebugStringConvertible

extension Error: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .constraintViolation(message):
            "Generable::Error.constraintViolation(\(String(reflecting: message)))"
        case let .invalidValue(expected):
            "Generable::Error.invalidValue(expected: \(String(reflecting: expected)))"
        case let .missingProperty(property):
            "Generable::Error.missingProperty(\(String(reflecting: property)))"
        case let .duplicateDefinition(definition):
            "Generable::Error.duplicateDefinition(\(String(reflecting: definition)))"
        case let .unrepresentableValue(value):
            "Generable::Error.unrepresentableValue(\(String(reflecting: value)))"
        case let .undefinedReference(reference):
            "Generable::Error.undefinedReference(\(String(reflecting: reference)))"
        case let .unproductiveReferenceCycle(reference):
            "Generable::Error.unproductiveReferenceCycle(\(String(reflecting: reference)))"
        case let .unexpectedProperty(property):
            "Generable::Error.unexpectedProperty(\(String(reflecting: property)))"
        }
    }
}
