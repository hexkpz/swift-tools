//
//  Created by Anton Spivak
//

import Testing
import Generable

@Test
func `integer bounds remain exact beyond floating-point precision`() throws {
    let minimum = 9_007_199_254_740_993

    let signed = try GenerationSchema.Property(
        name: "value",
        type: Int.self,
        guides: [.minimum(minimum), .minimum(minimum - 1)],
    ).schema

    let unsigned = try GenerationSchema.Property(
        name: "value",
        type: UInt64.self,
        guides: [.maximum(.max)],
    ).schema

    #expect(integerValue(signed.generatedContent.property("minimum"), as: Int.self) == minimum)
    #expect(integerValue(unsigned.generatedContent.property(
        "maximum",
    ), as: UInt64.self) == .max)

    try signed.validate(.integer(minimum))
    #expect(throws: Generable::Error.self) {
        try signed.validate(.integer(minimum - 1))
    }
}

@Test
func `number bounds compare integer and fractional values exactly`() throws {
    let schema = try GenerationSchema.number(constraints: [.minimum(1.5), .maximum(2)])

    let exactWideMaximum = try GenerationSchema.number(constraints: [.maximum(UInt64.max)])
    let negativeFractions = try GenerationSchema.number(constraints: [
        .minimum(-1.5),
        .maximum(-0.5),
    ])

    try schema.validate(.number(1.5))
    try schema.validate(.integer(2))

    #expect(throws: Generable::Error.self) { try schema.validate(.integer(1)) }

    try exactWideMaximum.validate(.integer(UInt64.max))
    #expect(throws: Generable::Error.self) {
        try exactWideMaximum.validate(.number(Double(UInt64.max)))
    }

    try negativeFractions.validate(.integer(-1))
    #expect(throws: Generable::Error.self) {
        try negativeFractions.validate(.integer(-2))
    }
    #expect(throws: Generable::Error.self) {
        try negativeFractions.validate(.integer(0))
    }
}

@Test
func `equivalent repeated bounds normalize canonically`() throws {
    let first = try GenerationSchema.number(constraints: [.minimum(Int(0)), .minimum(-0.0)])
    let second = try GenerationSchema.number(constraints: [.minimum(-0.0), .minimum(Int(0))])

    #expect(first == second)
    #expect(integerValue(first.generatedContent.property("minimum"), as: Int.self) == 0)
}

@Test
func `floating schemas reject unrepresentable values and constraints`() throws {
    let schema = try Float.generationSchema
    try schema.validate(.number(Double(Float.greatestFiniteMagnitude)))

    #expect(throws: Generable::Error.self) {
        try schema.validate(.number(Double.greatestFiniteMagnitude))
    }

    #expect(throws: Generable::Error.self) {
        _ = try GenerationSchema.number(constraints: [.anyOf(["value"])])
    }
}
