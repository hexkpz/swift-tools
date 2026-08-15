//
//  Created by Anton Spivak
//

// MARK: - GenerationEncoder

/// A schema-bound encoding context for manual ``Generable`` implementations.
///
/// Use ``GeneratedContentEncoder`` to start a root encoding operation. Values receive this
/// lower-level encoder while writing their generated representation.
///
/// ```swift
/// func encode(to encoder: inout GenerationEncoder) throws {
///     try encoder.encode(title, forProperty: "title")
///     try encoder.encode(year, forProperty: "year")
/// }
/// ```
public struct GenerationEncoder {
    // MARK: Lifecycle

    init(
        node: Graph.Node,
        references: [Graph.Reference.ID: Graph.Node],
    ) throws(Error) {
        let resolution = try node.resolving(references: references)

        self.node = resolution.node
        self.references = references
        self.validations = resolution.validations

        if case let .structure(structure) = resolution.node {
            encodedProperties.reserveCapacity(structure.properties.count)
            encodedPropertyNames.reserveCapacity(structure.properties.count)
        }
    }

    // MARK: Public

    /// Encodes `null`.
    public mutating func encodeNil() throws {
        guard case .null = node else {
            throw Error.invalidValue(expected: "null")
        }
        try set(content: .null)
    }

    // MARK: Private

    private let node: Graph.Node
    private let references: [Graph.Reference.ID: Graph.Node]
    private let validations: [AnyGenerationSchemaValidator]

    private var content: GeneratedContent?

    private var encodedProperties: [GeneratedContent.Property] = []
    private var encodedPropertyNames: Set<String> = []
}

public extension GenerationEncoder {
    /// Encodes a required property.
    ///
    /// - Parameters:
    ///   - value: The property value.
    ///   - name: The property name.
    mutating func encode<Value: Generable>(
        _ value: Value,
        forProperty name: String,
    ) throws {
        try encode(forProperty: name) { encoder in
            try value.encode(to: &encoder)
        }
    }

    /// Encodes an optional property.
    ///
    /// A `nil` value omits the property instead of encoding `null`.
    ///
    /// - Parameters:
    ///   - value: The optional property value.
    ///   - name: The property name.
    mutating func encode<Value: Generable>(
        _ value: Value?,
        forProperty name: String,
    ) throws {
        guard value != nil else {
            let property = try property(named: name)
            guard case .structure = node, property.isOptional else {
                throw Error.missingProperty(name)
            }

            encodedPropertyNames.insert(name)
            return
        }

        try encode(forProperty: name) { encoder in
            try value.encode(to: &encoder)
        }
    }

    /// Encodes a property with a closure.
    ///
    /// - Parameters:
    ///   - name: The property name.
    ///   - body: The encoding closure.
    mutating func encode(
        forProperty name: String,
        _ body: (inout GenerationEncoder) throws -> Void,
    ) throws {
        let property = try property(named: name)
        let content = try encode(using: property.node, body)
        let encodedProperty = GeneratedContent.Property(name, content)

        if case .oneOf = node {
            let content = GeneratedContent.object(.init([encodedProperty]))
            try property.validations.validate(content)

            try set(content: content)
            return
        }

        encodedPropertyNames.insert(name)
        encodedProperties.append(encodedProperty)
    }
}

// MARK: Primitive encoding

extension GenerationEncoder {
    mutating func encode(_ value: Bool) throws {
        guard case .boolean = node
        else { throw Error.invalidValue(expected: "a boolean") }

        try set(content: .boolean(value))
    }

    mutating func encode(_ value: some GeneratedBinaryInteger) throws {
        guard case let .integer(bounds) = node
        else { throw Error.invalidValue(expected: "an integer") }
        if let error = bounds.error(for: value) { throw error }

        try set(content: .integer(value))
    }

    mutating func encode(_ value: some BinaryFloatingPoint) throws {
        guard case let .number(bounds) = node
        else { throw Error.invalidValue(expected: "a number") }

        let number = Double(value)

        guard value.isFinite, number.isFinite
        else { throw Error.unrepresentableValue(String(describing: value)) }
        if let error = bounds.error(for: number) { throw error }

        try set(content: .number(number))
    }

    mutating func encode(_ value: consuming String) throws {
        guard case let .string(allowedStrings) = node
        else { throw Error.invalidValue(expected: "a string") }
        if let error = allowedStrings.error(for: value) { throw error }

        try set(content: .string(value))
    }

    mutating func encode<Elements: Sequence>(
        _ elements: Elements,
    ) throws where Elements.Element: Generable {
        guard case let .array(elementNode, bounds) = node
        else { throw Error.invalidValue(expected: "an array") }

        var contents: [GeneratedContent] = []
        contents.reserveCapacity(elements.underestimatedCount)
        for element in elements {
            try contents.append(encode(element, using: elementNode))
        }
        if let error = bounds.error(for: contents.count) { throw error }

        try set(content: .array(contents))
    }

    mutating func encode<Element: Generable>(
        _ elements: Set<Element>,
    ) throws {
        guard case let .array(elementNode, bounds) = node
        else { throw Error.invalidValue(expected: "an array") }

        var keyedContents: [(content: GeneratedContent, key: [UInt8])] = []
        keyedContents.reserveCapacity(elements.count)
        // Swift sets have no stable iteration order. Sort their encoded forms so equivalent sets
        // always produce the same generated content.
        for element in elements {
            let content = try encode(element, using: elementNode)
            keyedContents.append((content, content.setElementKey))
        }

        keyedContents.sort { lhs, rhs in
            lhs.key.lexicographicallyPrecedes(rhs.key)
        }

        for index in keyedContents.indices.dropFirst() {
            let previous = keyedContents[keyedContents.index(before: index)]
            guard previous.key != keyedContents[index].key
            else { throw Error.invalidValue(expected: "unique generated set elements") }
        }

        if let error = bounds.error(for: keyedContents.count) { throw error }
        try set(content: .array(keyedContents.map(\.content)))
    }

    mutating func encode<Value: Generable>(
        _ dictionary: [String: Value],
    ) throws {
        guard case let .dictionary(valueNode) = node
        else { throw Error.invalidValue(expected: "a dictionary") }

        var properties: [GeneratedContent.Property] = []
        properties.reserveCapacity(dictionary.count)
        for (name, value) in dictionary {
            try properties.append(.init(name, encode(value, using: valueNode)))
        }

        try set(content: .object(.init(properties)))
    }

    mutating func encode<Wrapped: Generable>(_ value: Wrapped?) throws {
        guard case let .optional(wrapped) = node
        else { throw Error.invalidValue(expected: "an optional value") }

        guard let value else {
            try set(content: .null)
            return
        }

        try set(content: encode(value, using: wrapped))
    }
}

// MARK: State

extension GenerationEncoder {
    consuming func finish() throws -> GeneratedContent {
        let content: GeneratedContent
        switch node {
        case let .structure(structure):
            if encodedPropertyNames.count != structure.properties.count {
                for property in structure.properties
                    where
                    !property.isOptional &&
                    !encodedPropertyNames.contains(property.name)
                {
                    throw Error.missingProperty(property.name)
                }
            }

            content = .object(.init(encodedProperties))
        default:
            guard let encodedContent = self.content
            else { throw Error.invalidValue(expected: "an encoded value") }

            content = encodedContent
        }

        try validations.validate(content)
        return content
    }
}

private extension GenerationEncoder {
    private mutating func set(content: consuming GeneratedContent) throws {
        guard case nil = self.content
        else { throw Error.invalidValue(expected: "a single encoded value") }

        self.content = content
    }

    private func encode<Value: Generable>(
        _ value: Value,
        using node: Graph.Node,
    ) throws -> GeneratedContent {
        try encode(using: node) { encoder in
            try value.encode(to: &encoder)
        }
    }

    private func encode(
        using node: Graph.Node,
        _ body: (inout Self) throws -> Void,
    ) throws -> GeneratedContent {
        var encoder = try Self(node: node, references: references)
        try body(&encoder)

        return try encoder.finish()
    }

    private func property(named name: String) throws -> (
        node: Graph.Node,
        isOptional: Bool,
        validations: [AnyGenerationSchemaValidator],
    ) {
        switch node {
        case let .structure(structure):
            guard !encodedPropertyNames.contains(name)
            else { throw Error.constraintViolation("Property \(name) was encoded more than once.") }

            guard let property = structure.property(named: name)
            else { throw Error.unexpectedProperty(name) }

            return (property.node, property.isOptional, [])
        case .oneOf:
            guard case nil = content, encodedProperties.isEmpty
            else { throw Error.invalidValue(expected: "a single encoded value") }

            let resolution = try resolveSingleProperty(
                named: name,
                in: node,
                references: references,
            )

            return (resolution.property.node, false, resolution.validations)
        default:
            throw Error.invalidValue(expected: "an object")
        }
    }
}
