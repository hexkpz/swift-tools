//
//  Created by Anton Spivak
//

// MARK: - Context

final class Context: @unchecked Sendable {
    // MARK: Internal

    @TaskLocal
    static var current: Context?

    // MARK: Private

    private enum State {
        case resolving(Graph.Reference)
        case resolved(Graph.Entry)

        // MARK: Internal

        var reference: Graph.Reference {
            switch self {
            case let .resolving(reference): reference
            case let .resolved(entry): entry.reference
            }
        }
    }

    private var states: [Graph.Reference.ID: State] = [:]
}

extension Context {
    func define<Value: Generable>(
        _ type: Value.Type,
        name: String,
        body: () throws(Error) -> GenerationSchema,
    ) throws(Error) -> GenerationSchema {
        let id = Graph.Reference.ID(type: ObjectIdentifier(type))
        if let state = states[id] {
            guard state.reference.name == name else { throw .duplicateDefinition(name) }
            return try .init(.init(.reference(state.reference)))
        }

        let reference = Graph.Reference(id: id, name: name)
        let isRoot = states.isEmpty

        // Publish the reference before running the body so recursive definitions resolve to
        // `$ref` instead of recursively rebuilding the same schema.
        states[id] = .resolving(reference)
        do {
            let schema = try body()
            states[id] = .resolved(.init(reference: reference, fragment: schema.graph.root))
            return isRoot ? schema : try .init(.init(.reference(reference)))
        } catch {
            states[id] = nil
            throw error
        }
    }
}

extension Context {
    func finalize(
        _ schema: consuming GenerationSchema,
    ) throws(Error) -> GenerationSchema {
        var registry = schema.graph.registry

        for state in states.values {
            guard case let .resolved(entry) = state else {
                throw .undefinedReference(state.reference.pointer)
            }
            try registry.insert(entry)
        }

        return try .init(
            definition: schema.definition,
            graph: .init(root: schema.graph.root, registry: registry),
        )
    }
}
