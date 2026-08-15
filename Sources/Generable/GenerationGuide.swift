//
//  Created by Anton Spivak
//

// MARK: - GenerationGuide

/// A constraint or local validator for a generated property.
///
/// Constraints appear in JSON Schema; local validators run only in Swift.
public struct GenerationGuide<Value>: Sendable {
    // MARK: Lifecycle

    init(_ constraints: GenerationSchema.Constraint...) {
        self.constraints = constraints
        self.validations = []
    }

    init(_ validations: AnyGenerationSchemaValidator...) {
        self.constraints = []
        self.validations = validations
    }

    // MARK: Internal

    let constraints: [GenerationSchema.Constraint]
    let validations: [AnyGenerationSchemaValidator]
}

public extension GenerationGuide {
    /// Creates a guide from a local validator.
    ///
    /// - Parameter validator: The validator to apply.
    static func validation<Validator: GenerationSchema.Validator>(
        _ validator: Validator,
    ) -> Self where Value == Validator.Value {
        .init(AnyGenerationSchemaValidator(validator))
    }
}

// MARK: CustomStringConvertible

extension GenerationGuide: CustomStringConvertible {
    public var description: String {
        let constraints = constraints.map { "constraint(\($0.description))" }
        let validations = validations.map { "validation(\($0.description))" }
        return (constraints + validations).joined(separator: ", ")
    }
}

// MARK: CustomDebugStringConvertible

extension GenerationGuide: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        GenerationGuide<\(String(reflecting: Value.self))>(
          constraints: \(String(reflecting: constraints)),
          validators: [\(validations.map(\.debugDescription).joined(separator: ", "))]
        )
        """
    }
}
