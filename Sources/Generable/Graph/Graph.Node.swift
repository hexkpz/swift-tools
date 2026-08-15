//
//  Created by Anton Spivak
//

// MARK: - Graph.Node

extension Graph {
    indirect enum Node: Sendable {
        case never
        case null

        case boolean
        case integer(NumericBounds)
        case number(NumericBounds)
        case string(AllowedStrings)

        case array(Node, CountBounds)
        case dictionary(Node)
        case structure(Structure)
        case reference(Reference)

        case optional(Node)
        case anyOf([Node])
        case oneOf([Node])

        case refinement(Node, [AnyGenerationSchemaValidator])
    }
}

extension Graph.Node {
    func applying(_ validators: [AnyGenerationSchemaValidator]) -> Self {
        guard !validators.isEmpty else { return self }

        if case let .refinement(node, current) = self {
            var combined = current
            combined.reserveCapacity(current.count + validators.count)
            combined.append(contentsOf: validators)
            return .refinement(node, combined)
        }

        return .refinement(self, validators)
    }
}

extension Graph.Node {
    func validate(
        _ content: GeneratedContent,
        references: [Graph.Reference.ID: Graph.Node],
    ) throws(Error) {
        switch self {
        case .never:
            throw .invalidValue(expected: "no value")
        case .null:
            guard case .null = content else { throw typeMismatch() }
        case .boolean:
            guard case .boolean = content else { throw typeMismatch() }
        case let .integer(bounds):
            guard case let .integer(value) = content else { throw typeMismatch() }
            if let error = bounds.error(for: value) { throw error }
        case let .number(bounds):
            switch content {
            case let .integer(value):
                if let error = bounds.error(for: value) { throw error }
            case let .number(value):
                if let error = bounds.error(for: value) { throw error }
            default:
                throw typeMismatch()
            }
        case let .string(allowedStrings):
            guard case let .string(value) = content else { throw typeMismatch() }
            if let error = allowedStrings.error(for: value) { throw error }
        case let .array(element, bounds):
            guard case let .array(values) = content else { throw typeMismatch() }
            if let error = bounds.error(for: values.count) { throw error }
            for value in values {
                try element.validate(value, references: references)
            }
        case let .dictionary(valueSchema):
            guard case let .object(properties) = content else { throw typeMismatch() }
            guard properties.hasUniquePropertyNames else {
                throw Error.duplicateObjectPropertyNames()
            }
            for property in properties {
                try valueSchema.validate(property.value, references: references)
            }
        case let .structure(structure):
            guard case let .object(properties) = content else { throw typeMismatch() }
            try structure.validate(properties, references: references)
        case let .reference(reference):
            guard let node = references[reference.id] else {
                throw Error.undefinedReference(reference.pointer)
            }
            try node.validate(content, references: references)
        case let .optional(wrapped):
            if case .null = content { return }
            try wrapped.validate(content, references: references)
        case let .anyOf(nodes):
            try validateAnyOf(nodes, content: content, references: references)
        case let .oneOf(nodes):
            try validateOneOf(nodes, content: content, references: references)
        case let .refinement(node, validators):
            try node.validate(content, references: references)
            try validators.validate(content)
        }
    }

    private func validateAnyOf(
        _ nodes: [Self],
        content: GeneratedContent,
        references: [Graph.Reference.ID: Graph.Node],
    ) throws(Error) {
        var firstError: Error?

        for node in nodes {
            do {
                try node.validate(content, references: references)
                return
            } catch {
                if firstError == nil { firstError = error }
            }
        }

        throw firstError ?? .invalidValue(expected: "one of the declared schemas")
    }

    private func validateOneOf(
        _ nodes: [Self],
        content: GeneratedContent,
        references: [Graph.Reference.ID: Graph.Node],
    ) throws(Error) {
        var hasMatch = false

        for node in nodes {
            do {
                try node.validate(content, references: references)
            } catch {
                continue
            }

            guard !hasMatch
            else { throw Error.invalidValue(expected: "exactly one of the declared schemas") }

            hasMatch = true
        }

        guard hasMatch else {
            throw Error.invalidValue(expected: "exactly one of the declared schemas")
        }
    }

    private func typeMismatch() -> Error {
        .invalidValue(expected: "content matching the compiled schema")
    }
}

extension Graph.Node {
    func forEachReference(
        _ body: (Graph.Reference) throws(Error) -> Void,
    ) throws(Error) {
        switch self {
        case let .array(node, _),
             let .dictionary(node),
             let .optional(node),
             let .refinement(node, _):
            try node.forEachReference(body)
        case let .structure(structure):
            for property in structure.properties {
                try property.node.forEachReference(body)
            }
        case let .reference(reference):
            try body(reference)
        case let .anyOf(nodes), let .oneOf(nodes):
            for node in nodes {
                try node.forEachReference(body)
            }
        default:
            return
        }
    }
}

extension Graph.Node {
    func forEachTransparentReference(
        _ body: (Graph.Reference) throws(Error) -> Void,
    ) throws(Error) {
        switch self {
        case let .reference(reference):
            try body(reference)
        case let .optional(node), let .refinement(node, _):
            try node.forEachTransparentReference(body)
        case let .anyOf(nodes), let .oneOf(nodes):
            for node in nodes {
                try node.forEachTransparentReference(body)
            }
        default:
            return
        }
    }
}
