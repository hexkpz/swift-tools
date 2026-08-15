//
//  Created by Anton Spivak
//

extension Compiler {
    static func structure(
        annotations: Definition.Annotations,
        properties: [GenerationSchema.Property],
    ) throws(Error) -> Graph.Fragment {
        var compiledProperties: [Graph.Structure.Property] = []
        compiledProperties.reserveCapacity(properties.count)

        var contentProperties: [GeneratedContent.Property] = []
        contentProperties.reserveCapacity(properties.count)

        var required: [GeneratedContent] = []
        required.reserveCapacity(properties.count)

        for property in properties.sorted(by: { $0.name < $1.name }) {
            guard compiledProperties.last?.name != property.name else {
                throw .constraintViolation("Schema contains duplicate property \(property.name).")
            }

            let isOptional = property.schema.isOptional
            compiledProperties.append(.init(
                name: property.name,
                node: property.schema.graph.root.node,
                isOptional: isOptional,
            ))

            contentProperties.append(.init(property.name, property.schema.graph.root.content))
            if !isOptional { required.append(.string(property.name)) }
        }

        return .init(
            node: .structure(Graph.Structure(properties: compiledProperties)),
            content: Self.schema(
                type: .object,
                annotations: annotations,
                properties: [
                    ("properties", .object(.init(contentProperties))),
                    ("required", .array(required)),
                    ("additionalProperties", .boolean(false)),
                ],
            ),
        )
    }
}

private extension GenerationSchema {
    var isOptional: Bool {
        if case .optional = definition.kind { true }
        else { false }
    }
}
