//
//  Created by Anton Spivak
//

// MARK: - AnyGenerationSchemaValidator

struct AnyGenerationSchemaValidator: Sendable {
    // MARK: Lifecycle

    init<Validator: GenerationSchema.Validator>(_ validator: Validator) {
        // The existential lets one graph retain validators for different generated value types.
        self.validator = validator
    }

    // MARK: Internal

    func validate(_ content: borrowing GeneratedContent) throws(Error) {
        guard validator.matches(content)
        else { throw .invalidValue(expected: validator.expected) }
    }

    // MARK: Private

    private let validator: any GenerationSchema.Validator
}

extension Collection where Element == AnyGenerationSchemaValidator {
    func validate(_ content: borrowing GeneratedContent) throws(Error) {
        for validator in self {
            try validator.validate(content)
        }
    }
}

// MARK: - AnyGenerationSchemaValidator + CustomStringConvertible

extension AnyGenerationSchemaValidator: CustomStringConvertible {
    var description: String { validator.description }
}

// MARK: - AnyGenerationSchemaValidator + CustomDebugStringConvertible

extension AnyGenerationSchemaValidator: CustomDebugStringConvertible {
    var debugDescription: String {
        "\(String(reflecting: Swift.type(of: validator)))(\(String(reflecting: validator)))"
    }
}
