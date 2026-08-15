//
//  Created by Anton Spivak
//

// MARK: - GeneratedContent

/// A JSON-compatible generated value.
///
/// Integers preserve their precision, and object properties are sorted by name.
///
/// ```swift
/// let content = GeneratedContent(properties: [
///     ("name", .string("Ada")),
///     ("age", .integer(36)),
/// ])
/// ```
@frozen
public enum GeneratedContent: Sendable {
    /// The JSON null value.
    case null

    /// A Boolean value.
    case boolean(Bool)

    /// An integer stored without loss of precision.
    indirect case integer(any GeneratedBinaryInteger)

    /// A floating-point number.
    ///
    /// JSON encoding rejects nonfinite values.
    case number(Double)

    /// A string value.
    case string(String)

    /// An array value.
    case array([GeneratedContent])

    /// An object with properties sorted by name.
    case object(Object)
}

public extension GeneratedContent {
    /// Creates an object from named values.
    ///
    /// Names are sorted, while duplicates are preserved for validation.
    ///
    /// - Parameter properties: The object properties.
    @inlinable
    // swiftformat:disable:next spaceAroundBrackets
    init(properties: consuming [(String, GeneratedContent)]) {
        var properties = consume properties

        var result: [Property] = []
        result.reserveCapacity(properties.count)

        let isStrictlyOrdered = properties.indices.dropFirst().allSatisfy { index in
            properties[properties.index(before: index)].0 < properties[index].0
        }

        // Preserve the common canonical-order path and consume unordered input from the end.
        // `Object` performs the final sort and duplicate-name check.
        if isStrictlyOrdered {
            for (name, value) in consume properties {
                result.append(.init(name, value))
            }
        } else {
            while let (name, value) = properties.popLast() {
                result.append(.init(name, value))
            }
        }

        self = .object(.init(result))
    }
}

public extension GeneratedContent {
    /// Whether this value is null.
    var isNull: Bool {
        guard case .null = self else { return false }
        return true
    }

    /// The associated Boolean, or `nil` when this value has another kind.
    var boolean: Bool? {
        guard case let .boolean(value) = self else { return nil }
        return value
    }

    /// The associated integer, or `nil` when this value has another kind.
    var integer: (any GeneratedBinaryInteger)? {
        guard case let .integer(value) = self else { return nil }
        return value
    }

    /// Returns the associated integer converted exactly to `Value`.
    func integer<Value: BinaryInteger>(as _: Value.Type) -> Value? {
        guard case let .integer(value) = self else { return nil }
        return Value(exactly: value)
    }

    /// The associated floating-point number, or `nil` when this value has another kind.
    var number: Double? {
        guard case let .number(value) = self else { return nil }
        return value
    }

    /// The associated string, or `nil` when this value has another kind.
    var string: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }
}

public extension GeneratedContent {
    /// The associated array, or `nil` when this value has another kind.
    var array: [GeneratedContent]? {
        guard case let .array(value) = self else { return nil }
        return value
    }

    /// Returns an array element by index.
    ///
    /// - Parameter index: The element index.
    /// - Returns: The value, or `nil` if the content isn't an array or the index is out of bounds.
    @inlinable
    @inline(__always)
    func element(at index: Int) -> GeneratedContent? {
        guard case let .array(elements) = self, elements.indices.contains(index)
        else { return nil }
        return elements[index]
    }
}

public extension GeneratedContent {
    /// The associated object, or `nil` when this value has another kind.
    var object: Object? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    /// Returns an object property by name.
    ///
    /// - Parameter name: The property name.
    /// - Returns: The value, or `nil` if the content isn't an object or the property is absent.
    @inlinable
    @inline(__always)
    func property(_ name: String) -> GeneratedContent? {
        guard case let .object(properties) = self else { return nil }
        return properties.value(forProperty: name)
    }
}

// MARK: Equatable

extension GeneratedContent: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): true
        case let (.boolean(lhs), .boolean(rhs)): lhs == rhs
        case let (.integer(lhs), .integer(rhs)): AnyHashable(lhs) == AnyHashable(rhs)
        case let (.number(lhs), .number(rhs)): lhs == rhs
        case let (.string(lhs), .string(rhs)): lhs == rhs
        case let (.array(lhs), .array(rhs)): lhs == rhs
        case let (.object(lhs), .object(rhs)): lhs == rhs
        default: false
        }
    }
}

// MARK: Hashable

extension GeneratedContent: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .null:
            hasher.combine(0)
        case let .boolean(value):
            hasher.combine(1)
            hasher.combine(value)
        case let .integer(value):
            hasher.combine(2)
            hasher.combine(AnyHashable(value))
        case let .number(value):
            hasher.combine(3)
            hasher.combine(value)
        case let .string(value):
            hasher.combine(4)
            hasher.combine(value)
        case let .array(values):
            hasher.combine(5)
            hasher.combine(values)
        case let .object(object):
            hasher.combine(6)
            hasher.combine(object)
        }
    }
}

// MARK: CustomDebugStringConvertible

extension GeneratedContent: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .null: "GeneratedContent.null"
        case let .boolean(value): "GeneratedContent.boolean(\(String(reflecting: value)))"
        case let .integer(value): "GeneratedContent.integer(\(String(reflecting: value)))"
        case let .number(value): "GeneratedContent.number(\(String(reflecting: value)))"
        case let .string(value): "GeneratedContent.string(\(String(reflecting: value)))"
        case let .array(values): "GeneratedContent.array(\(String(reflecting: values)))"
        case let .object(properties): "GeneratedContent.object(\(String(reflecting: properties)))"
        }
    }
}

// MARK: GeneratedContent.Object

public extension GeneratedContent {
    /// A collection of object properties sorted by name.
    @frozen
    struct Object: Sendable {
        // MARK: Lifecycle

        /// Creates an object from properties.
        ///
        /// Names are sorted, while duplicates are preserved for validation.
        ///
        /// - Parameter properties: The object properties.
        @inlinable
        // swiftformat:disable:next spaceAroundBrackets
        public init(_ properties: consuming [Property]) {
            var properties = consume properties
            var hasUniquePropertyNames = true

            // Most compiler-produced objects are already sorted. Scan them once, and only sort
            // and rescan for duplicates after finding the first out-of-order property.
            for index in properties.indices.dropFirst() {
                let previous = properties[properties.index(before: index)]
                let current = properties[index]

                if current.name < previous.name {
                    properties.sort { $0.name < $1.name }
                    hasUniquePropertyNames = properties.namesAreUnique
                    break
                }

                if current.name == previous.name { hasUniquePropertyNames = false }
            }

            self.hasUniquePropertyNames = hasUniquePropertyNames
            self.properties = properties
        }

        // MARK: Internal

        @usableFromInline
        let hasUniquePropertyNames: Bool

        @usableFromInline
        let properties: [Property]
    }
}

// MARK: - GeneratedContent.Object + Equatable

extension GeneratedContent.Object: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.properties == rhs.properties
    }
}

// MARK: - GeneratedContent.Object + Hashable

extension GeneratedContent.Object: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(properties)
    }
}

// MARK: - GeneratedContent.Object + ExpressibleByArrayLiteral

extension GeneratedContent.Object: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: GeneratedContent.Property...) {
        self.init(elements)
    }
}

// MARK: - GeneratedContent.Object + RandomAccessCollection

extension GeneratedContent.Object: RandomAccessCollection {
    @inlinable @inline(__always) public var startIndex: Int { properties.startIndex }

    @inlinable @inline(__always) public var endIndex: Int { properties.endIndex }

    @inlinable @inline(__always)
    public subscript(position: Int) -> GeneratedContent.Property {
        // Yield the stored element directly so callers can borrow it without an intermediate copy.
        _read { yield properties[position] }
    }

    @inlinable @inline(__always)
    public func index(after index: Int) -> Int {
        properties.index(after: index)
    }

    @inlinable @inline(__always)
    public func index(before index: Int) -> Int {
        properties.index(before: index)
    }
}

extension GeneratedContent.Object {
    @usableFromInline
    @inline(__always)
    func value(forProperty name: String) -> GeneratedContent? {
        let lowerBound = properties.lowerBound(for: name, by: \.name)
        guard lowerBound < properties.endIndex, properties[lowerBound].name == name
        else { return nil }
        return properties[lowerBound].value
    }
}

// MARK: - GeneratedContent.Object + CustomStringConvertible

extension GeneratedContent.Object: CustomStringConvertible {
    public var description: String {
        "[\(lazy.map(\.description).joined(separator: ", "))]"
    }
}

// MARK: - GeneratedContent.Object + CustomDebugStringConvertible

extension GeneratedContent.Object: CustomDebugStringConvertible {
    public var debugDescription: String {
        "GeneratedContent.Object(\(String(reflecting: properties)))"
    }
}

// MARK: - GeneratedContent.Property

public extension GeneratedContent {
    /// A property in a ``GeneratedContent`` object.
    @frozen
    struct Property: Sendable {
        // MARK: Lifecycle

        /// Creates an object property.
        ///
        /// - Parameters:
        ///   - name: The property name.
        ///   - value: The property value.
        @inlinable
        @inline(__always)
        public init(_ name: consuming String, _ value: consuming GeneratedContent) {
            self.name = name
            self.value = value
        }

        // MARK: Public

        /// The property name.
        public let name: String

        /// The property value.
        public let value: GeneratedContent
    }
}

// MARK: - GeneratedContent.Property + Equatable

extension GeneratedContent.Property: Equatable {}

// MARK: - GeneratedContent.Property + Hashable

extension GeneratedContent.Property: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(value)
    }
}

// MARK: - GeneratedContent.Property + CustomStringConvertible

extension GeneratedContent.Property: CustomStringConvertible {
    public var description: String { "\(name): \(value)" }
}

// MARK: - GeneratedContent.Property + CustomDebugStringConvertible

extension GeneratedContent.Property: CustomDebugStringConvertible {
    public var debugDescription: String {
        "GeneratedContent.Property(\(String(reflecting: name)), \(String(reflecting: value)))"
    }
}

extension [GeneratedContent.Property] {
    @usableFromInline var namesAreUnique: Bool {
        !indices.dropFirst().contains { index in
            self[self.index(before: index)].name == self[index].name
        }
    }
}

extension GeneratedContent {
    var setElementKey: [UInt8] {
        // Sets need a stable key for ordering and for detecting distinct Swift values that encode
        // to the same content. Canonical JSON provides that key when Foundation is available.
        // Swift considers 0.0 and -0.0 equal, although their encodings may differ.
        if case let .number(value) = self, value == 0 { return Array("0".utf8) }

        #if canImport(FoundationEssentials) || canImport(Foundation)
        if let data = try? data() { return Array(data) }
        #endif

        return Array(debugDescription.utf8)
    }
}
