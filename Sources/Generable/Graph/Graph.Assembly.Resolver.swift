//
//  Created by Anton Spivak
//

// MARK: - Graph.Assembly.Resolver

extension Graph.Assembly {
    struct Resolver: ~Copyable {
        // MARK: Lifecycle

        init(
            registry: consuming Graph.Registry,
            // swiftformat:disable:next spaceAroundBrackets
            counts: consuming [Graph.Reference.ID: Int],
        ) {
            self.registry = registry
            self.counts = counts
        }

        // MARK: Internal

        mutating func resolve(
            _ content: borrowing GeneratedContent,
        ) throws(Error) -> GeneratedContent {
            if let replacement = try replacement(in: content) {
                return replacement
            }
            return copy content
        }

        consuming func takeRenderedDefinitions() -> [Graph.Reference.ID: GeneratedContent] {
            renderedDefinitions
        }

        // MARK: Private

        private let registry: Graph.Registry
        private let counts: [Graph.Reference.ID: Int]

        private var renderedDefinitions: [Graph.Reference.ID: GeneratedContent] = [:]
        private var rendering: Set<Graph.Reference.ID> = []

        private mutating func replacement(
            in content: borrowing GeneratedContent,
        ) throws(Error) -> GeneratedContent? {
            if let pointer = content.referencePointer {
                return try replacement(forReferenceAt: pointer)
            }

            switch content {
            case let .array(values):
                return try replacement(in: values)
            case let .object(properties):
                return try replacement(in: properties)
            default:
                return nil
            }
        }

        private mutating func replacement(
            forReferenceAt pointer: String,
        ) throws(Error) -> GeneratedContent? {
            guard let entry = registry.entry(forPointer: pointer)
            else { throw .undefinedReference(pointer) }

            let id = entry.reference.id
            if counts[id, default: 0] > 1 {
                // Reused definitions stay as `$ref` and are rendered once into `$defs`.
                // Single-use definitions are inlined below to keep the schema compact.
                if renderedDefinitions[id] == nil, rendering.insert(id).inserted {
                    defer { rendering.remove(id) }
                    renderedDefinitions[id] = try resolve(entry.fragment.content)
                }
                return nil
            }

            guard rendering.insert(id).inserted
            else { throw .unproductiveReferenceCycle(entry.reference.pointer) }
            defer { rendering.remove(id) }

            return try resolve(entry.fragment.content)
        }

        private mutating func replacement(
            in values: [GeneratedContent],
        ) throws(Error) -> GeneratedContent? {
            var resolvedValues: [GeneratedContent]?
            for index in values.indices {
                guard let resolved = try replacement(in: values[index]) else { continue }

                if resolvedValues == nil { resolvedValues = values }
                resolvedValues?[index] = resolved
            }

            guard let resolvedValues else { return nil }
            return .array(resolvedValues)
        }

        private mutating func replacement(
            in properties: GeneratedContent.Object,
        ) throws(Error) -> GeneratedContent? {
            var resolvedProperties: [GeneratedContent.Property]?
            for index in properties.indices {
                guard let resolved = try replacement(in: properties[index].value) else { continue }

                if resolvedProperties == nil { resolvedProperties = Array(properties) }
                resolvedProperties?[index] = .init(properties[index].name, resolved)
            }

            guard let resolvedProperties else { return nil }
            return .object(.init(resolvedProperties))
        }
    }
}

private extension GeneratedContent {
    var referencePointer: String? {
        guard case let .object(properties) = self,
              properties.count == 1,
              properties[0].name == "$ref",
              case let .string(pointer) = properties[0].value
        else { return nil }
        return pointer
    }
}
