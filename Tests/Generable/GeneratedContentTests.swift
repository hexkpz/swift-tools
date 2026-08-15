//
//  Created by Anton Spivak
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

import Testing
import Generable

// MARK: - CanonicalObjectCase

private struct CanonicalObjectCase: Sendable, CustomTestStringConvertible {
    let testDescription: String
    let content: GeneratedContent
}

private extension String {
    init(_ value: Int, zeroPaddedTo length: Int) {
        let value = String(value)
        self = String(repeating: "0", count: Swift.max(0, length - value.count)) + value
    }
}

private let canonicalObjectCases: [CanonicalObjectCase] = [
    .init(
        testDescription: "object initializer",
        content: .object([
            .init("z", .integer(1)),
            .init("a", .integer(2)),
        ]),
    ),
    .init(
        testDescription: "unsorted property tuples",
        content: .init(properties: [
            ("z", .integer(1)),
            ("a", .integer(2)),
        ]),
    ),
    .init(
        testDescription: "already sorted property tuples",
        content: .init(properties: [
            ("a", .integer(2)),
            ("z", .integer(1)),
        ]),
    ),
]

private let indexedObject = GeneratedContent.object(.init(
    (0 ..< 128).reversed().map { index in .init(String(index, zeroPaddedTo: 3), .integer(index)) },
))

#if canImport(FoundationEssentials) || canImport(Foundation)
private var wideIntegerContents: [GeneratedContent] {
    var values = [
        GeneratedContent.integer(Int64.min),
        .integer(UInt64.max),
    ]
    if #available(macOS 15, iOS 18, macCatalyst 18, *) {
        values.append(.integer(Int128.min))
        values.append(.integer(UInt128.max))
    }
    return values
}
#endif

@Test(arguments: canonicalObjectCases)
private func `object construction canonicalizes property order`(_ testCase: CanonicalObjectCase) {
    guard case let .object(properties) = testCase.content else {
        Issue.record("Expected object content.")
        return
    }

    #expect(properties.map(\.name) == ["a", "z"])
}

@Test(arguments: zip(
    ["000", "064", "127", "128"],
    [0, 64, 127, nil] as [Int?],
))
func `object lookup handles boundaries`(_ property: String, _ expected: Int?) {
    #expect(integerValue(indexedObject.property(property), as: Int.self) == expected)
}

@Test
func `hashing follows canonical generated content equality`() {
    let signed = GeneratedContent.integer(Int8(1))
    let unsigned = GeneratedContent.integer(UInt64(1))

    #expect(signed == unsigned)
    #expect(Set([signed, unsigned]).count == 1)

    let first = GeneratedContent(properties: [("z", .integer(1)), ("a", .boolean(true))])
    let second = GeneratedContent(properties: [("a", .boolean(true)), ("z", .integer(1))])
    #expect(first == second)
    #expect(first.hashValue == second.hashValue)
}

@Test
func `dictionary schemas and JSON encoding reject duplicate properties`() throws {
    let content = GeneratedContent.object([
        .init("value", .integer(1)),
        .init("value", .integer(2)),
    ])
    let dictionary = try GenerationSchema.dictionary(.integer())

    #expect(throws: Generable::Error.self) {
        try dictionary.validate(content)
    }

    #if canImport(FoundationEssentials) || canImport(Foundation)
    #expect(throws: EncodingError.self) {
        _ = try JSONEncoder().encode(content)
    }
    #endif
}

@Test
func `non-finite numbers fail at ingestion and validation`() {
    #expect(throws: Generable::Error.self) {
        _ = try GeneratedContent(Double.nan)
    }
    #expect(throws: Generable::Error.self) {
        try GenerationSchema.number().validate(.number(.infinity))
    }
}

#if canImport(FoundationEssentials) || canImport(Foundation)
@Test(arguments: wideIntegerContents)
func `JSON preserves wide integers`(_ value: GeneratedContent) {
    let json = value.description
    #expect(GeneratedContent(json)?.description == json)
}
#endif
