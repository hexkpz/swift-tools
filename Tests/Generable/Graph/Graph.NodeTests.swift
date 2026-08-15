//
//  Created by Anton Spivak
//

import Testing
import Generable

// MARK: - PrefixValidator

private struct PrefixValidator: GenerationSchema.Validator {
    typealias Value = String

    let prefix: String

    var expected: String { "a string beginning with \(prefix)" }

    func matches(_ content: GeneratedContent) -> Bool {
        guard case let .string(value) = content else { return false }
        return value.hasPrefix(prefix)
    }
}

// MARK: - InvalidCompositionCase

private struct InvalidCompositionCase: Sendable, CustomTestStringConvertible {
    let testDescription: String
    let content: GeneratedContent
}

private let invalidCompositionCases: [InvalidCompositionCase] = [
    .init(
        testDescription: "nested constraint",
        content: .init(properties: [("value", .string("rejected"))]),
    ),
    .init(
        testDescription: "unexpected property",
        content: .init(properties: [("unexpected", .string("allowed"))]),
    ),
    .init(
        testDescription: "duplicate property",
        content: .object([
            .init("value", .string("allowed")),
            .init("value", .string("allowed")),
        ]),
    ),
]

@Test
func `anyOf and oneOf enforce different match counts`() throws {
    let integer = try GenerationSchema.integer()
    let number = try GenerationSchema.number()

    let any = try GenerationSchema.anyOf([integer, number])
    let one = try GenerationSchema.oneOf([integer, number])

    try any.validate(.integer(1))
    try one.validate(.number(1.5))

    #expect(throws: Generable::Error.self) {
        try one.validate(.integer(1))
    }
    #expect(throws: Generable::Error.self) {
        try any.validate(.boolean(true))
    }
}

@Test
func `oneOf selects branches using their local validators`() throws {
    let startsWithX = try GenerationSchema.string().validating(PrefixValidator(prefix: "x"))
    let startsWithY = try GenerationSchema.string().validating(PrefixValidator(prefix: "y"))

    let schema = try GenerationSchema.oneOf([startsWithX, startsWithY])

    try schema.validate(.string("xylophone"))
    try schema.validate(.string("yodel"))

    #expect(throws: Generable::Error.self) {
        try schema.validate(.string("violin"))
    }
}

@Test
func `compositions accept every matching nested shape`() throws {
    let allowedString = try GenerationSchema.string(constraints: [.anyOf(["allowed"])])
    let object = try GenerationSchema.structure(properties: [
        .init(name: "value", schema: allowedString),
    ])

    let array = try GenerationSchema.array(.integer())
    let schema = try GenerationSchema.anyOf([object, array])

    try schema.validate(.init(properties: [("value", .string("allowed"))]))
    try schema.validate(.array([.integer(1)]))
}

@Test(arguments: invalidCompositionCases)
private func `compositions reject invalid nested shapes`(
    _ example: InvalidCompositionCase,
) throws {
    let allowedString = try GenerationSchema.string(constraints: [.anyOf(["allowed"])])
    let object = try GenerationSchema.structure(properties: [
        .init(name: "value", schema: allowedString),
    ])

    let array = try GenerationSchema.array(.integer())
    let schema = try GenerationSchema.anyOf([object, array])

    #expect(throws: Generable::Error.self) {
        try schema.validate(example.content)
    }
}

@Test
func `nested optionals retain their wrapped validation`() throws {
    let integer = try GenerationSchema.integer(constraints: [.minimum(1)])
    let schema = try GenerationSchema.optional(.optional(integer))

    try schema.validate(.null)
    try schema.validate(.integer(1))

    #expect(throws: Generable::Error.self) {
        try schema.validate(.integer(0))
    }
}
