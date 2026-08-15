//
//  Created by Anton Spivak
//

// MARK: - Graph.Assembly

extension Graph {
    enum Assembly {
        static func assemble(
            root: Fragment,
            registry: Registry,
        ) throws(Error) -> (
            content: GeneratedContent,
            references: [Reference.ID: Node],
            registry: Registry,
        ) {
            var reachable: [Reference.ID: Entry] = [:]
            var counts: [Reference.ID: Int] = [:]

            try Self.collectReferences(
                in: root.node,
                registry: registry,
                reachable: &reachable,
                counts: &counts,
            )

            guard !reachable.isEmpty else {
                return (
                    content: root.content,
                    references: [:],
                    registry: .init(),
                )
            }

            // Cycles are only invalid when every edge is transparent. A container edge consumes
            // input before recursion and therefore gives validation a way to make progress.
            try Self.validateReferenceCycles(in: reachable)

            var resolver = Resolver(registry: registry, counts: counts)
            let rootContent = try resolver.resolve(root.content)
            let renderedDefinitions = resolver.takeRenderedDefinitions()

            var definitionProperties: [GeneratedContent.Property] = []
            definitionProperties.reserveCapacity(renderedDefinitions.count)
            for entry in reachable.values {
                guard let content = renderedDefinitions[entry.reference.id]
                else { continue }
                definitionProperties.append(.init(entry.reference.name, content))
            }

            let references = reachable.mapValues(\.fragment.node)
            let registry = try Registry(entries: reachable)

            guard !definitionProperties.isEmpty else {
                return (
                    content: rootContent,
                    references: references,
                    registry: registry,
                )
            }

            guard case let .object(rootProperties) = rootContent
            else { throw .constraintViolation("Schema references require an object root.") }

            var properties: [GeneratedContent.Property] = []
            properties.reserveCapacity(rootProperties.count + 1)
            properties.append(.init("$defs", .object(.init(definitionProperties))))
            properties.append(contentsOf: rootProperties)

            return (
                content: .object(.init(properties)),
                references: references,
                registry: registry,
            )
        }
    }
}

extension Graph.Assembly {
    static func collectReferences(
        in node: Graph.Node,
        registry: Graph.Registry,
        reachable: inout [Graph.Reference.ID: Graph.Entry],
        counts: inout [Graph.Reference.ID: Int],
    ) throws(Error) {
        try node.forEachReference { (reference: Graph.Reference) throws(Error) in
            let id = reference.id
            guard let entry = registry.entry(for: id)
            else { throw .undefinedReference(reference.pointer) }

            counts[id, default: 0] += 1
            guard reachable[id] == nil else { return }
            reachable[id] = entry

            try collectReferences(
                in: entry.fragment.node,
                registry: registry,
                reachable: &reachable,
                counts: &counts,
            )
        }
    }

    static func validateReferenceCycles(
        in entries: [Graph.Reference.ID: Graph.Entry],
    ) throws(Error) {
        enum State {
            case visiting
            case visited
        }

        var states: [Graph.Reference.ID: State] = [:]
        states.reserveCapacity(entries.count)

        func visit(_ entry: Graph.Entry) throws(Error) {
            let id = entry.reference.id

            switch states[id] {
            case .visiting: throw .unproductiveReferenceCycle(entry.reference.pointer)
            case .visited: return
            case nil: break
            }

            states[id] = .visiting
            try entry.fragment.node.forEachTransparentReference { reference throws(Error) in
                guard let target = entries[reference.id]
                else { throw .undefinedReference(reference.pointer) }
                try visit(target)
            }
            states[id] = .visited
        }

        for entry in entries.values.sorted(by: { $0.reference.pointer < $1.reference.pointer }) {
            try visit(entry)
        }
    }
}
