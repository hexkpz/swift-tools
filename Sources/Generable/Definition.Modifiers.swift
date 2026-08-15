//
//  Created by Anton Spivak
//

extension Definition {
    struct Modifiers: Sendable {
        // MARK: Lifecycle

        init(
            description: String? = nil,
            constraints: [GenerationSchema.Constraint] = [],
            validations: [AnyGenerationSchemaValidator] = [],
        ) {
            self.annotations = .init(description: description)

            self.constraints = constraints
            self.validations = validations
        }

        init<Value>(
            description: String?,
            guides: [GenerationGuide<Value>],
        ) {
            var constraints: [GenerationSchema.Constraint] = []
            var validations: [AnyGenerationSchemaValidator] = []

            for guide in guides {
                constraints.append(contentsOf: guide.constraints)
                validations.append(contentsOf: guide.validations)
            }

            self.init(
                description: description,
                constraints: constraints,
                validations: validations,
            )
        }

        // MARK: Internal

        let annotations: Annotations

        let constraints: [GenerationSchema.Constraint]
        let validations: [AnyGenerationSchemaValidator]

        var isEmpty: Bool {
            annotations.isEmpty && constraints.isEmpty && validations.isEmpty
        }
    }
}
