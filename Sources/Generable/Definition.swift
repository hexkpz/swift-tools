//
//  Created by Anton Spivak
//

// MARK: - Definition

struct Definition: Sendable {
    // MARK: Lifecycle

    init(
        _ kind: Kind,
        title: String? = nil,
        description: String? = nil,
    ) {
        self.init(
            kind,
            annotations: .init(title: title, description: description),
        )
    }

    init(
        _ kind: Kind,
        annotations: Annotations,
        validations: [AnyGenerationSchemaValidator] = [],
    ) {
        self.kind = kind
        self.annotations = annotations
        self.validations = validations
    }

    // MARK: Internal

    indirect enum Kind: Sendable {
        case reference(Graph.Reference)

        case never
        case null

        case boolean
        case integer([GenerationSchema.Constraint])
        case number([GenerationSchema.Constraint])
        case string([GenerationSchema.Constraint])

        case array(GenerationSchema, [GenerationSchema.Constraint])
        case dictionary(GenerationSchema)
        case structure([GenerationSchema.Property])
        case enumeration([String])

        case optional(GenerationSchema, [GenerationSchema.Constraint])

        case anyOf([GenerationSchema])
        case oneOf([GenerationSchema])
    }

    var kind: Kind
    var annotations: Annotations
    var validations: [AnyGenerationSchemaValidator]
}

extension Definition {
    func registry() throws(Error) -> Graph.Registry {
        switch kind {
        case .reference, .never, .null, .boolean, .integer, .number, .string, .enumeration:
            return .init()
        case let .array(element, _),
             let .dictionary(element),
             let .optional(element, _):
            return element.graph.registry
        case let .structure(properties):
            var registry = Graph.Registry()
            for property in properties {
                try registry.merge(property.schema.graph.registry)
            }
            return registry
        case let .anyOf(schemas), let .oneOf(schemas):
            var registry = Graph.Registry()
            for schema in schemas {
                try registry.merge(schema.graph.registry)
            }
            return registry
        }
    }
}

extension Definition {
    func applying(
        _ modifiers: Modifiers,
    ) throws(Error) -> Self {
        var definition = self
        definition.annotations.apply(modifiers.annotations)
        definition.kind = try kind.applying(modifiers.constraints)
        definition.validations.append(contentsOf: modifiers.validations)
        return definition
    }
}

private extension Definition.Kind {
    func applying(
        _ constraints: [GenerationSchema.Constraint],
    ) throws(Error) -> Self {
        guard !constraints.isEmpty else { return self }

        switch self {
        case let .integer(current):
            return .integer(current.appending(constraints))
        case let .number(current):
            return .number(current.appending(constraints))
        case let .string(current):
            return .string(current.appending(constraints))
        case let .array(element, current):
            return .array(element, current.appending(constraints))
        case let .optional(wrapped, current):
            return .optional(wrapped, current.appending(constraints))
        default:
            throw .unsupported(constraints[0], for: "this schema")
        }
    }
}

private extension [GenerationSchema.Constraint] {
    func appending(_ constraints: Self) -> Self {
        guard !isEmpty else { return constraints }

        var result = self
        result.reserveCapacity(count + constraints.count)
        result.append(contentsOf: constraints)

        return result
    }
}
