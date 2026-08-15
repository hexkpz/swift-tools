//
//  Created by Anton Spivak
//

import Testing
import Generable

// MARK: - Sample

@Generable
private struct Sample {
    var title: String

    @Guide(.range(0 ... 10))
    var score: Int

    var note: String?
}

// MARK: - EmptyValue

@Generable
private struct EmptyValue: Equatable {}

// MARK: - Box

@Generable
private struct Box<Value: Generable & Equatable>: Equatable {
    var value: Value
}

// MARK: - StoredPropertySelection

@Generable
private struct StoredPropertySelection: Equatable {
    static let shared = "shared"

    let identifier: Int
    var `repeat`: String

    var computed: String { "\(identifier):\(`repeat`)" }
}

// MARK: - ObservedValues

@Generable
private struct ObservedValues {
    var first: Int, second: Int

    var observed: Int {
        didSet {}
    }
}

// MARK: - DefaultedValues

@Generable
private struct DefaultedValues {
    @Guide(.minimum(count: 1))
    var values: [Int] = [1]
}

// MARK: - IgnoredState

private struct IgnoredState: Equatable {
    var value: String
}

// MARK: - IgnoredProperties

@Generable
private struct IgnoredProperties {
    var value: Int

    @GenerableIgnored
    var state = IgnoredState(value: "initial")

    @GenerableIgnored
    let source = "local"

    @GenerableIgnored
    lazy var snapshot = IgnoredState(value: "snapshot")
}

private typealias Maybe<Value> = Value?

// MARK: - AliasedOptionalValue

@Generable
private struct AliasedOptionalValue {
    var number: Maybe<Int>
}

// MARK: - ValidatedLeaf

private struct ValidatedLeaf: Generable {
    // MARK: Lifecycle

    init(from decoder: inout GenerationDecoder) throws {
        self.value = try Int(from: &decoder)
    }

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) { try .integer() }
    }

    let value: Int

    func encode(to encoder: inout GenerationEncoder) throws {
        try value.encode(to: &encoder)
    }
}

// MARK: - ValidatedContainer

@Generable
private struct ValidatedContainer {
    var leaf: ValidatedLeaf
    var leaves: [ValidatedLeaf]
}

private let optionalNotes: [String?] = [nil, "value"]

@Test(arguments: optionalNotes)
func `generated structures handle optional fields`(_ note: String?) throws {
    var properties: [(String, GeneratedContent)] = [
        ("title", .string("Value")),
        ("score", .integer(10)),
    ]
    if let note {
        properties.append(("note", .string(note)))
    }

    let value = try GeneratedContent(properties: properties).decode(Sample.self)
    #expect(value.note == note)
}

@Test
func `generated optional properties accept explicit null`() throws {
    let value = try GeneratedContent(properties: [
        ("title", .string("Value")),
        ("score", .integer(10)),
        ("note", .null),
    ]).decode(Sample.self)

    #expect(value.note == nil)
    #expect(try GeneratedContent(value).property("note") == nil)
}

@Test
func `empty generated structures round trip`() throws {
    let content = try GeneratedContent(EmptyValue())

    guard case let .object(properties) = content else {
        Issue.record("Expected object content.")
        return
    }

    #expect(properties.isEmpty)
    #expect(try content.decode(EmptyValue.self) == EmptyValue())
}

@Test
func `generic generated structures round trip`() throws {
    let value = Box(value: 42)

    #expect(try GeneratedContent(value).decode(Box<Int>.self) == value)
}

@Test
func `generated structures include only stored instance properties`() throws {
    let content = GeneratedContent(properties: [
        ("identifier", .integer(42)),
        ("repeat", .string("value")),
    ])

    let value = try content.decode(StoredPropertySelection.self)
    let encoded = try GeneratedContent(value)

    #expect(value.identifier == 42)
    #expect(value.repeat == "value")
    #expect(value.computed == "42:value")
    #expect(encoded.property("identifier") != nil)
    #expect(encoded.property("repeat") != nil)
    #expect(encoded.property("computed") == nil)
    #expect(encoded.property("shared") == nil)
}

@Test
func `generated structures enforce guides`() {
    #expect(throws: Generable::Error.self) {
        _ = try GeneratedContent(properties: [
            ("title", .string("Invalid")),
            ("score", .integer(11)),
        ]).decode(Sample.self)
    }
}

@Test
func `multiple bindings and observed properties are generated`() throws {
    let value = ObservedValues(first: 1, second: 2, observed: 3)
    let decoded = try GeneratedContent(value).decode(ObservedValues.self)

    #expect(decoded.first == value.first)
    #expect(decoded.second == value.second)
    #expect(decoded.observed == value.observed)
}

@Test
func `inferred count guides reject empty arrays`() throws {
    _ = try GeneratedContent(properties: [
        ("values", .array([.integer(1)])),
    ]).decode(DefaultedValues.self)
    #expect(throws: Generable::Error.self) {
        _ = try GeneratedContent(properties: [
            ("values", .array([])),
        ]).decode(DefaultedValues.self)
    }
}

@Test
func `ignored properties retain their defaults outside generated content`() throws {
    var value = IgnoredProperties(value: 42)
    value.state.value = "changed"
    value.snapshot.value = "changed"

    let content = try GeneratedContent(value)
    var decoded = try content.decode(IgnoredProperties.self)

    #expect(try content.property("value")?.decode(Int.self) == 42)
    #expect(content.property("state") == nil)
    #expect(content.property("source") == nil)
    #expect(content.property("snapshot") == nil)
    #expect(decoded.state == IgnoredState(value: "initial"))
    #expect(decoded.source == "local")
    #expect(decoded.snapshot == IgnoredState(value: "snapshot"))

    let unexpected = GeneratedContent(properties: [
        ("state", .string("external")),
        ("value", .integer(42)),
    ])

    #expect(throws: Generable::Error.self) {
        try IgnoredProperties.generationSchema.validate(unexpected)
    }
}

@Test
func `optional aliases select the optional decoding overload`() throws {
    let value = try GeneratedContent(properties: []).decode(AliasedOptionalValue.self)

    #expect(value.number == nil)
    #expect(try GeneratedContent(value).property("number") == nil)
}

@Test
func `nested values use their manual Generable initializer`() throws {
    let value = try GeneratedContent(properties: [
        ("leaf", .integer(1)),
        ("leaves", .array([.integer(2), .integer(3)])),
    ]).decode(ValidatedContainer.self)

    #expect(value.leaf.value == 1)
    #expect(value.leaves.map(\.value) == [2, 3])
    #expect(throws: Generable::Error.self) {
        _ = try GeneratedContent(properties: [
            ("leaf", .string("invalid")),
            ("leaves", .array([])),
        ]).decode(ValidatedContainer.self)
    }
}
