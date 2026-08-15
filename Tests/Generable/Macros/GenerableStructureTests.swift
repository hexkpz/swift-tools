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

    let value = try generatedContentDecoder.decode(
        Sample.self,
        from: GeneratedContent(properties: properties),
    )
    #expect(value.note == note)
}

@Test
func `generated optional properties accept explicit null`() throws {
    let value = try generatedContentDecoder.decode(
        Sample.self,
        from: GeneratedContent(properties: [
            ("title", .string("Value")),
            ("score", .integer(10)),
            ("note", .null),
        ]),
    )

    #expect(value.note == nil)
    #expect(try generatedContentEncoder.encode(value).property("note") == nil)
}

@Test
func `empty generated structures round trip`() throws {
    let content = try generatedContentEncoder.encode(EmptyValue())

    guard case let .object(properties) = content else {
        Issue.record("Expected object content.")
        return
    }

    #expect(properties.isEmpty)
    #expect(try generatedContentDecoder.decode(EmptyValue.self, from: content) == EmptyValue())
}

@Test
func `generic generated structures round trip`() throws {
    let value = Box(value: 42)

    let content = try generatedContentEncoder.encode(value)
    #expect(try generatedContentDecoder.decode(Box<Int>.self, from: content) == value)
}

@Test
func `generated structures include only stored instance properties`() throws {
    let content = GeneratedContent(properties: [
        ("identifier", .integer(42)),
        ("repeat", .string("value")),
    ])

    let value = try generatedContentDecoder.decode(StoredPropertySelection.self, from: content)
    let encoded = try generatedContentEncoder.encode(value)

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
        _ = try generatedContentDecoder.decode(
            Sample.self,
            from: GeneratedContent(properties: [
                ("title", .string("Invalid")),
                ("score", .integer(11)),
            ]),
        )
    }
}

@Test
func `multiple bindings and observed properties are generated`() throws {
    let value = ObservedValues(first: 1, second: 2, observed: 3)
    let content = try generatedContentEncoder.encode(value)
    let decoded = try generatedContentDecoder.decode(ObservedValues.self, from: content)

    #expect(decoded.first == value.first)
    #expect(decoded.second == value.second)
    #expect(decoded.observed == value.observed)
}

@Test
func `inferred count guides reject empty arrays`() throws {
    _ = try generatedContentDecoder.decode(
        DefaultedValues.self,
        from: GeneratedContent(properties: [
            ("values", .array([.integer(1)])),
        ]),
    )
    #expect(throws: Generable::Error.self) {
        _ = try generatedContentDecoder.decode(
            DefaultedValues.self,
            from: GeneratedContent(properties: [
                ("values", .array([])),
            ]),
        )
    }
}

@Test
func `ignored properties retain their defaults outside generated content`() throws {
    var value = IgnoredProperties(value: 42)
    value.state.value = "changed"
    value.snapshot.value = "changed"

    let content = try generatedContentEncoder.encode(value)
    var decoded = try generatedContentDecoder.decode(IgnoredProperties.self, from: content)

    let valueContent = try #require(content.property("value"))
    #expect(try generatedContentDecoder.decode(Int.self, from: valueContent) == 42)
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
    let value = try generatedContentDecoder.decode(
        AliasedOptionalValue.self,
        from: GeneratedContent(properties: []),
    )

    #expect(value.number == nil)
    #expect(try generatedContentEncoder.encode(value).property("number") == nil)
}

@Test
func `nested values use their manual Generable initializer`() throws {
    let value = try generatedContentDecoder.decode(
        ValidatedContainer.self,
        from: GeneratedContent(properties: [
            ("leaf", .integer(1)),
            ("leaves", .array([.integer(2), .integer(3)])),
        ]),
    )

    #expect(value.leaf.value == 1)
    #expect(value.leaves.map(\.value) == [2, 3])
    #expect(throws: Generable::Error.self) {
        _ = try generatedContentDecoder.decode(
            ValidatedContainer.self,
            from: GeneratedContent(properties: [
                ("leaf", .string("invalid")),
                ("leaves", .array([])),
            ]),
        )
    }
}
