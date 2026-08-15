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

// MARK: - CorpusValue

@Generable
private struct CorpusValue: Equatable {
    var boolean: Bool
    var integer: Int64
    var number: Double
    var string: String
    var array: [Int64]
    var dictionary: [String: String]
    var optional: Int64?
    var children: [CorpusValue]
}

// MARK: - DeepNode

@Generable
private struct DeepNode: Equatable {
    var value: Int
    var children: [DeepNode]
}

// MARK: - LargeCollections

@Generable
private struct LargeCollections: Equatable {
    var values: [Int]
    var lookup: [String: Int]
}

// MARK: - SeededGenerator

private struct SeededGenerator {
    // MARK: Lifecycle

    init(seed: UInt64) {
        self.state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    // MARK: Internal

    mutating func value(depth: Int = 2) -> CorpusValue {
        let array = (0 ..< Int(next() % 8)).map { _ in Int64(bitPattern: next()) }

        var dictionary: [String: String] = [:]
        for index in 0 ..< Int(next() % 6) {
            dictionary["key/~\(index)-\(next() % 17)"] = string()
        }

        let children: [CorpusValue] = if depth > 0 {
            (0 ..< Int(next() % 3)).map { _ in value(depth: depth - 1) }
        } else {
            []
        }

        return CorpusValue(
            boolean: next().isMultiple(of: 2),
            integer: Int64(bitPattern: next()),
            number: Double(Int64(next() % 2001) - 1000) / 8,
            string: string(),
            array: array,
            dictionary: dictionary,
            optional: next().isMultiple(of: 3) ? nil : Int64(bitPattern: next()),
            children: children,
        )
    }

    // MARK: Private

    private var state: UInt64

    private mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    private mutating func string() -> String {
        "value-\(next() % 10000)\n\"/~😀"
    }
}

private let invariantSeeds = Array(UInt64(0) ..< 64)

#if canImport(FoundationEssentials) || canImport(Foundation)
@Test(arguments: invariantSeeds)
private func `generated values preserve the codec and JSON invariants`(_ seed: UInt64) throws {
    var generator = SeededGenerator(seed: seed)
    let value = generator.value()
    let schema = try CorpusValue.generationSchema
    let content = try generatedContentEncoder.encode(value)

    try schema.validate(content)

    let decodedJSON = try GeneratedContent(content.data())
    #expect(decodedJSON.description == content.description)
    #expect(try generatedContentDecoder.decode(CorpusValue.self, from: decodedJSON) == value)
}
#endif

@Test
func `deep recursive values round trip without losing structure`() throws {
    let depth = 32
    let value = (0 ..< depth).reversed().reduce(DeepNode(value: depth, children: [])) {
        DeepNode(value: $1, children: [$0])
    }

    let content = try generatedContentEncoder.encode(value)
    let decoded = try generatedContentDecoder.decode(DeepNode.self, from: content)

    var cursor = decoded
    for expected in 0 ..< depth {
        #expect(cursor.value == expected)
        cursor = try #require(cursor.children.first)
    }

    #expect(cursor.value == depth)
    #expect(cursor.children.isEmpty)
}

@Test
func `large collections round trip`() throws {
    let value = LargeCollections(
        values: Array(0 ..< 10000),
        lookup: Dictionary(uniqueKeysWithValues: (0 ..< 1000).map {
            ("key-\($0)", $0)
        }),
    )

    let content = try generatedContentEncoder.encode(value)
    #expect(try generatedContentDecoder.decode(LargeCollections.self, from: content) == value)
}
