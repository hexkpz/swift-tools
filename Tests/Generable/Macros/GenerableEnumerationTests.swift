//
//  Created by Anton Spivak
//

import Testing
import Generable

// MARK: - Choice

@Generable
private enum Choice: Equatable {
    case none
    case number(Int)
    case pair(name: String, value: Int)
}

// MARK: - Direction

@Generable
private enum Direction: Equatable {
    case north
    case south
}

// MARK: - InvalidChoicePayload

private enum InvalidChoicePayload: CaseIterable, Sendable, CustomTestStringConvertible {
    case emptyDiscriminator
    case multipleDiscriminators
    case missingAssociatedProperty
    case nonnullUnitCase
    case unexpectedAssociatedProperty
    case wrongAssociatedType

    // MARK: Internal

    var testDescription: String {
        switch self {
        case .emptyDiscriminator: "missing discriminator"
        case .multipleDiscriminators: "multiple discriminators"
        case .missingAssociatedProperty: "missing associated property"
        case .nonnullUnitCase: "nonnull unit-case payload"
        case .unexpectedAssociatedProperty: "unexpected associated property"
        case .wrongAssociatedType: "wrong associated type"
        }
    }

    var content: GeneratedContent {
        switch self {
        case .emptyDiscriminator:
            .init(properties: [])
        case .multipleDiscriminators:
            .init(properties: [
                ("none", .null),
                ("number", .integer(1)),
            ])
        case .missingAssociatedProperty:
            .init(properties: [
                ("pair", .init(properties: [
                    ("name", .string("Invalid")),
                ])),
            ])
        case .nonnullUnitCase:
            .init(properties: [("none", .boolean(true))])
        case .unexpectedAssociatedProperty:
            .init(properties: [
                ("pair", .init(properties: [
                    ("name", .string("Invalid")),
                    ("unexpected", .null),
                    ("value", .integer(1)),
                ])),
            ])
        case .wrongAssociatedType:
            .init(properties: [("number", .string("invalid"))])
        }
    }
}

@Test(arguments: [
    Choice.none,
    .number(42),
    .pair(name: "answer", value: 42),
])
private func `generated enumerations round trip every payload shape`(_ value: Choice) throws {
    let content = try GeneratedContent(value)
    let decoded = try content.decode(Choice.self)

    #expect(decoded == value)
}

@Test(arguments: [Direction.north, .south])
private func `simple generated enumerations round trip`(_ value: Direction) throws {
    #expect(try GeneratedContent(value).decode(Direction.self) == value)
}

@Test
func `generated enumerations reject unknown discriminators`() {
    #expect(throws: Generable::Error.self) {
        _ = try GeneratedContent.string("west").decode(Direction.self)
    }
}

@Test(arguments: InvalidChoicePayload.allCases)
private func `generated enumerations reject malformed payloads`(_ testCase: InvalidChoicePayload) {
    #expect(throws: Generable::Error.self) {
        _ = try testCase.content.decode(Choice.self)
    }
}
