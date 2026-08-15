//
//  Created by Anton Spivak
//

// MARK: - Compiler.Composition

extension Compiler {
    enum Composition: String {
        case anyOf
        case oneOf
    }
}

extension Compiler {
    static func composition(
        _ composition: Composition,
        schemas: [GenerationSchema],
        annotations: Definition.Annotations,
    ) throws(Error) -> Graph.Fragment {
        guard !schemas.isEmpty else {
            throw .constraintViolation("A schema composition must contain at least one schema.")
        }

        var nodes: [Graph.Node] = []
        nodes.reserveCapacity(schemas.count)

        var contents: [GeneratedContent] = []
        contents.reserveCapacity(schemas.count)

        for schema in schemas {
            nodes.append(schema.graph.root.node)
            contents.append(schema.graph.root.content)
        }

        let node: Graph.Node = switch composition {
        case .anyOf: .anyOf(nodes)
        case .oneOf: .oneOf(nodes)
        }

        return .init(node: node, content: Self.content(
            of: composition,
            schemas: contents,
            annotations: annotations,
        ))
    }
}
