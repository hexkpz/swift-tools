//
//  Created by Anton Spivak
//

// MARK: - GenerationDecoder

/// A schema-bound decoding context for manual ``Generable`` implementations.
///
/// Use ``GeneratedContentDecoder`` to start a root decoding operation. Values receive this
/// lower-level decoder while reading their generated representation.
///
/// ```swift
/// init(from decoder: inout GenerationDecoder) throws {
///     title = try decoder.decode(forProperty: "title")
///     year = try decoder.decode(forProperty: "year")
/// }
/// ```
public struct GenerationDecoder {
    // MARK: Lifecycle

    init(
        node: Graph.Node,
        references: [Graph.Reference.ID: Graph.Node],
        content: consuming GeneratedContent,
    ) throws(Error) {
        let resolution = try node.resolving(references: references)

        if case let .structure(structure) = resolution.node {
            guard case let .object(object) = content else {
                throw Error.invalidValue(expected: "a structure")
            }
            try structure.validate(shapeOf: object)
        }

        self.node = resolution.node
        self.references = references
        self.content = content
        self.validations = resolution.validations

        if case let .structure(structure) = resolution.node {
            decodedProperties.reserveCapacity(structure.properties.count)
        }
    }

    // MARK: Public

    /// Decodes `null`.
    public mutating func decodeNil() throws {
        guard case .null = node, case .null = content else {
            throw Error.invalidValue(expected: "null")
        }
        try consumeValue()
    }

    // MARK: Private

    private let node: Graph.Node
    private let references: [Graph.Reference.ID: Graph.Node]
    private let content: GeneratedContent
    private let validations: [AnyGenerationSchemaValidator]

    private var consumed = false
    private var decodedProperties: Set<String> = []
}

public extension GenerationDecoder {
    /// Decodes a required property.
    ///
    /// - Parameters:
    ///   - type: The property type.
    ///   - name: The property name.
    mutating func decode<Value: Generable>(
        _ type: Value.Type = Value.self,
        forProperty name: String,
    ) throws -> Value {
        try decode(forProperty: name) { decoder in
            try type.init(from: &decoder)
        }
    }

    /// Decodes an optional property.
    ///
    /// Returns `nil` if the property is absent or contains `null`.
    ///
    /// - Parameters:
    ///   - type: The property type.
    ///   - name: The property name.
    mutating func decode<Value: Generable>(
        _ type: Value?.Type = Value?.self,
        forProperty name: String,
    ) throws -> Value? {
        try requireUndecodedProperty(name)
        guard let property = try property(named: name, required: false) else {
            decodedProperties.insert(name)
            return nil
        }

        let value = try decode(type, from: property.content, using: property.node)
        try consumeProperty(name, validations: property.validations)
        return value
    }

    /// Decodes a property with a closure.
    ///
    /// - Parameters:
    ///   - name: The property name.
    ///   - body: The decoding closure.
    mutating func decode<Result>(
        forProperty name: String,
        _ body: (inout GenerationDecoder) throws -> Result,
    ) throws -> Result {
        try requireUndecodedProperty(name)
        guard let property = try property(named: name, required: true)
        else { throw Error.missingProperty(name) }

        let result = try decode(
            from: property.content,
            using: property.node,
            body,
        )

        try consumeProperty(name, validations: property.validations)
        return result
    }

    /// Returns the property name of a single-property `oneOf` value.
    func singlePropertyName() throws -> String {
        guard case .oneOf = node,
              case let .object(object) = content,
              object.count == 1,
              let property = object.first
        else {
            throw Error.invalidValue(expected: "an object with one property")
        }

        return property.name
    }
}

// MARK: Primitive decoding

extension GenerationDecoder {
    mutating func decode(_ type: Bool.Type = Bool.self) throws -> Bool {
        guard case .boolean = node, case let .boolean(value) = content
        else { throw Error.invalidValue(expected: "a boolean") }

        try consumeValue()
        return value
    }

    mutating func decode<Value: GeneratedBinaryInteger>(
        _ type: Value.Type = Value.self,
    ) throws -> Value {
        guard case let .integer(bounds) = node,
              case let .integer(contentValue) = content,
              let value = Value(exactly: contentValue)
        else { throw Error.invalidValue(expected: "an integer") }
        if let error = bounds.error(for: contentValue) { throw error }

        try consumeValue()
        return value
    }

    mutating func decode<Value: BinaryFloatingPoint>(
        _ type: Value.Type = Value.self,
    ) throws -> Value {
        guard case let .number(bounds) = node
        else { throw Error.invalidValue(expected: "a number") }

        let value: Value
        switch content {
        case let .integer(contentValue):
            if let error = bounds.error(for: contentValue) { throw error }
            value = Value(contentValue)
        case let .number(contentValue):
            if let error = bounds.error(for: contentValue) { throw error }
            value = Value(contentValue)
        default:
            throw Error.invalidValue(expected: "a number")
        }

        guard value.isFinite
        else { throw Error.invalidValue(expected: "a finite number") }

        try consumeValue()
        return value
    }

    mutating func decode(_ type: String.Type = String.self) throws -> String {
        guard case let .string(allowedStrings) = node,
              case let .string(value) = content
        else { throw Error.invalidValue(expected: "a string") }
        if let error = allowedStrings.error(for: value) { throw error }

        try consumeValue()
        return value
    }

    mutating func decode<Values>(
        _ type: Values.Type = Values.self,
    ) throws -> Values where
        Values: RandomAccessCollection & RangeReplaceableCollection,
        Values.Element: Generable
    {
        guard case let .array(element, bounds) = node,
              case let .array(contents) = content
        else { throw Error.invalidValue(expected: "an array") }
        if let error = bounds.error(for: contents.count) { throw error }

        var result = Values()
        result.reserveCapacity(contents.count)
        for content in contents {
            try result.append(decode(Values.Element.self, from: content, using: element))
        }

        try consumeValue()
        return result
    }

    mutating func decode<Element: Generable & Hashable>(
        _ type: Set<Element>.Type = Set<Element>.self,
    ) throws -> Set<Element> {
        guard case let .array(element, bounds) = node,
              case let .array(contents) = content
        else { throw Error.invalidValue(expected: "an array") }
        if let error = bounds.error(for: contents.count) { throw error }

        var result = Set<Element>(minimumCapacity: contents.count)
        for content in contents {
            try result.insert(decode(Element.self, from: content, using: element))
        }

        try consumeValue()
        return result
    }

    mutating func decode<Value: Generable>(
        _ type: [String: Value].Type = [String: Value].self,
    ) throws -> [String: Value] {
        guard case let .dictionary(valueNode) = node,
              case let .object(object) = content
        else { throw Error.invalidValue(expected: "a dictionary") }

        guard object.hasUniquePropertyNames
        else { throw Error.duplicateObjectPropertyNames() }

        var result: [String: Value] = [:]
        result.reserveCapacity(object.count)
        for property in object {
            result[property.name] = try decode(
                Value.self,
                from: property.value,
                using: valueNode,
            )
        }

        try consumeValue()
        return result
    }

    mutating func decode<Wrapped: Generable>(
        _ type: Wrapped?.Type = Wrapped?.self,
    ) throws -> Wrapped? {
        guard case let .optional(wrapped) = node
        else { throw Error.invalidValue(expected: "an optional value") }

        guard case .null = content else {
            let value = try decode(Wrapped.self, from: content, using: wrapped)
            try consumeValue()
            return value
        }

        try consumeValue()
        return nil
    }

    mutating func decode(_ type: Never.Type = Never.self) throws -> Never {
        throw Error.invalidValue(expected: "no value")
    }
}

// MARK: State

extension GenerationDecoder {
    func finish() throws {
        if case let .structure(structure) = node {
            guard case let .object(object) = content
            else { throw Error.invalidValue(expected: "a structure") }

            if decodedProperties.count != structure.properties.count {
                for property in object where !decodedProperties.contains(property.name) {
                    throw Error.unexpectedProperty(property.name)
                }
            }

            try validations.validate(content)
            return
        }

        guard consumed
        else { throw Error.invalidValue(expected: "a decoded value") }

        try validations.validate(content)
    }
}

private extension GenerationDecoder {
    private mutating func consumeValue() throws {
        guard !consumed
        else { throw Error.invalidValue(expected: "a single decoded value") }

        consumed = true
    }

    private func decode<Value: Generable>(
        _ type: Value.Type,
        from content: consuming GeneratedContent,
        using node: Graph.Node,
    ) throws -> Value {
        try decode(from: consume content, using: node) { decoder in
            try type.init(from: &decoder)
        }
    }

    private func decode<Result>(
        from content: consuming GeneratedContent,
        using node: Graph.Node,
        _ body: (inout Self) throws -> Result,
    ) throws -> Result {
        var decoder = try Self(
            node: node,
            references: references,
            content: consume content,
        )

        let result = try body(&decoder)
        try decoder.finish()

        return result
    }

    private func requireUndecodedProperty(_ name: String) throws {
        guard !consumed, !decodedProperties.contains(name)
        else { throw Error.constraintViolation("Property \(name) was decoded more than once.") }
    }

    private mutating func consumeProperty(
        _ name: String,
        validations: [AnyGenerationSchemaValidator],
    ) throws {
        if case .oneOf = node {
            try validations.validate(content)
            try consumeValue()
            return
        }

        decodedProperties.insert(name)
    }

    private mutating func property(
        named name: String,
        required: Bool,
    ) throws -> (
        node: Graph.Node,
        content: GeneratedContent,
        validations: [AnyGenerationSchemaValidator],
    )? {
        switch node {
        case let .structure(structure):
            guard case let .object(object) = content
            else { throw Error.invalidValue(expected: "a structure") }

            guard let property = structure.property(named: name)
            else { throw Error.unexpectedProperty(name) }

            guard let content = object.value(forProperty: name) else {
                if required { throw Error.missingProperty(name) }
                return nil
            }

            return (property.node, content, [])
        case .oneOf:
            let selected = try resolveSingleProperty(
                named: name,
                in: node,
                references: references,
            )

            guard case let .object(object) = content,
                  let content = object.value(forProperty: name)
            else { throw Error.missingProperty(name) }

            return (selected.property.node, content, selected.validations)
        default:
            throw Error.invalidValue(expected: "an object")
        }
    }
}
