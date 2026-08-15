//
//  Created by Anton Spivak
//

import Testing
import Generable

// MARK: - InvalidStructureCase

private enum InvalidStructureCase: CaseIterable, Sendable, CustomTestStringConvertible {
    case unexpectedProperty
    case duplicateProperty

    // MARK: Internal

    var testDescription: String {
        switch self {
        case .unexpectedProperty: "unexpected property"
        case .duplicateProperty: "duplicate property"
        }
    }

    var content: GeneratedContent {
        switch self {
        case .unexpectedProperty:
            .init(properties: [
                ("value", .integer(1)),
                ("unexpected", .null),
            ])
        case .duplicateProperty:
            .object([
                .init("value", .integer(1)),
                .init("value", .integer(2)),
            ])
        }
    }
}

@Test(arguments: InvalidStructureCase.allCases)
private func `closed structures reject duplicate and unexpected properties`(
    _ testCase: InvalidStructureCase,
) throws {
    let schema = try GenerationSchema.structure(properties: [
        .init(name: "value", schema: .integer()),
    ])

    #expect(throws: Generable::Error.self) {
        try schema.validate(testCase.content)
    }
}

@Test
func `invalid schemas fail during construction`() throws {
    #expect(throws: Generable::Error.self) {
        _ = try GenerationSchema.oneOf([])
    }

    #expect(throws: Generable::Error.self) {
        _ = try GenerationSchema.enumeration(values: [])
    }

    #expect(throws: Generable::Error.self) {
        _ = try GenerationSchema.enumeration(values: ["duplicate", "duplicate"])
    }

    let integer = try GenerationSchema.integer()
    #expect(throws: Generable::Error.self) {
        _ = try GenerationSchema.structure(properties: [
            .init(name: "value", schema: integer),
            .init(name: "value", schema: integer),
        ])
    }
}

@Test
func `structure schemas are canonical across property construction order`() throws {
    let integer = try GenerationSchema.integer()
    let string = try GenerationSchema.string()

    let first = try GenerationSchema.structure(properties: [
        .init(name: "integer", schema: integer),
        .init(name: "string", schema: string),
    ])
    let second = try GenerationSchema.structure(properties: [
        .init(name: "string", schema: string),
        .init(name: "integer", schema: integer),
    ])

    #expect(first == second)
    #expect(first.hashValue == second.hashValue)

    #if canImport(FoundationEssentials) || canImport(Foundation)
    #expect(first.description == second.description)
    #endif
}

@Test
func `local validators do not affect schema identity`() throws {
    let schema = try GenerationSchema.string()
    let validated = try schema.validating(NonemptyIdentifierValidator())

    #expect(schema == validated)
    #expect(schema.hashValue == validated.hashValue)
}
