//
//  Created by Anton Spivak
//

// MARK: - Compiler

enum Compiler {}

// MARK: Compiler.JSONType

extension Compiler {
    enum JSONType: String {
        case null
        case boolean
        case integer
        case number
        case string
        case array
        case object
    }
}

extension Compiler {
    static func compile(_ definition: Definition) throws(Error) -> Graph.Fragment {
        let fragment = try compile(definition.kind, annotations: definition.annotations)
        return .init(
            node: fragment.node.applying(definition.validations),
            content: fragment.content,
        )
    }

    private static func compile(
        _ kind: Definition.Kind,
        annotations: Definition.Annotations,
    ) throws(Error) -> Graph.Fragment {
        switch kind {
        case let .reference(reference):
            let node = Graph.Node.reference(reference)
            let content = GeneratedContent(properties: [("$ref", .string(reference.pointer))])

            guard !annotations.isEmpty
            else { return .init(node: node, content: content) }

            // Keep annotations outside `$ref`; treating them as siblings has draft-dependent
            // semantics, while this wrapper composes consistently across supported drafts.
            return .init(node: node, content: Self.content(
                of: .anyOf,
                schemas: [content],
                annotations: annotations,
            ))
        case .never:
            return .init(node: .never, content: never(annotations: annotations))
        case .null:
            return .init(node: .null, content: schema(type: .null, annotations: annotations))
        case .boolean:
            return .init(node: .boolean, content: schema(
                type: .boolean,
                annotations: annotations,
            ))
        case let .integer(constraints):
            let bounds = try Graph.NumericBounds(constraints)
            return .init(node: .integer(bounds), content: schema(
                type: .integer,
                annotations: annotations,
                properties: bounds.generatedProperties.map { ($0.rawValue, $1) },
            ))
        case let .number(constraints):
            let bounds = try Graph.NumericBounds(constraints)
            return .init(node: .number(bounds), content: schema(
                type: .number,
                annotations: annotations,
                properties: bounds.generatedProperties.map { ($0.rawValue, $1) },
            ))
        case let .string(constraints):
            return try string(
                annotations: annotations,
                allowedStrings: .init(constraints),
            )
        case let .array(element, constraints):
            let bounds = try Graph.CountBounds(constraints)
            let element = element.graph.root

            var properties = bounds.generatedProperties.map { ($0.rawValue, $1) }
            properties.append(("items", element.content))

            return .init(node: .array(element.node, bounds), content: schema(
                type: .array,
                annotations: annotations,
                properties: properties,
            ))
        case let .dictionary(value):
            let value = value.graph.root
            return .init(node: .dictionary(value.node), content: schema(
                type: .object,
                annotations: annotations,
                properties: [("additionalProperties", value.content)],
            ))
        case let .structure(properties):
            return try structure(
                annotations: annotations,
                properties: properties,
            )
        case let .enumeration(values):
            return try string(
                annotations: annotations,
                allowedStrings: .init(enumeration: values),
            )
        case let .optional(schema, constraints):
            // Constraints describe the wrapped value, not the `null` alternative.
            let wrapped: Graph.Fragment =
                if constraints.isEmpty {
                    schema.graph.root
                } else {
                    try compile(schema.definition.applying(.init(constraints: constraints)))
                }

            return .init(node: .optional(wrapped.node), content: content(
                of: .anyOf,
                schemas: [wrapped.content, Self.schema(type: .null)],
                annotations: annotations,
            ))
        case let .anyOf(schemas):
            return try composition(
                .anyOf,
                schemas: schemas,
                annotations: annotations,
            )
        case let .oneOf(schemas):
            return try composition(
                .oneOf,
                schemas: schemas,
                annotations: annotations,
            )
        }
    }
}

extension Compiler {
    static func string(
        annotations: Definition.Annotations,
        allowedStrings: Graph.AllowedStrings,
    ) -> Graph.Fragment {
        .init(node: .string(allowedStrings), content: schema(
            type: .string,
            annotations: annotations,
            properties: allowedStrings.generatedProperties.map { ($0.rawValue, $1) },
        ))
    }

    static func schema(
        type: JSONType,
        annotations: Definition.Annotations = .init(),
        properties additionalProperties: [(String, GeneratedContent)] = [],
    ) -> GeneratedContent {
        let capacity =
            1 +
            annotations.generatedPropertyCount +
            additionalProperties.count

        var properties: [GeneratedContent.Property] = []
        properties.reserveCapacity(capacity)
        properties.append(.init("type", .string(type.rawValue)))

        annotations.appendGeneratedProperties(to: &properties)
        for (name, value) in additionalProperties {
            properties.append(.init(name, value))
        }

        return .object(.init(properties))
    }

    static func content(
        of composition: Composition,
        schemas: [GeneratedContent],
        annotations: Definition.Annotations,
    ) -> GeneratedContent {
        let capacity =
            1 + annotations.generatedPropertyCount

        var properties: [GeneratedContent.Property] = []
        properties.reserveCapacity(capacity)

        annotations.appendGeneratedProperties(to: &properties)
        properties.append(.init(composition.rawValue, .array(schemas)))

        return .object(.init(properties))
    }

    private static func never(
        annotations: Definition.Annotations,
    ) -> GeneratedContent {
        guard !annotations.isEmpty else { return .boolean(false) }

        var properties: [GeneratedContent.Property] = []
        properties.reserveCapacity(annotations.generatedPropertyCount + 1)

        annotations.appendGeneratedProperties(to: &properties)
        properties.append(.init("not", .object(.init([]))))

        return .object(.init(properties))
    }
}
