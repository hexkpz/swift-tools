//
//  Created by Anton Spivak
//

import Testing
import Generable

private func strongestCountBoundsSchema() throws -> GenerationSchema {
    try .array(
        .integer(),
        constraints: [
            .minimum(count: 1),
            .minimum(count: 2),
            .maximum(count: 6),
            .maximum(count: 5),
        ],
    )
}

@Test
func `count bounds keep the strongest range`() throws {
    let schema = try strongestCountBoundsSchema()

    #expect(integerValue(schema.document.property("minItems"), as: Int.self) == 2)
    #expect(integerValue(schema.document.property("maxItems"), as: Int.self) == 5)
}

@Test(arguments: [2, 5])
func `count bounds accept boundary values`(_ count: Int) throws {
    let schema = try strongestCountBoundsSchema()
    try schema.validate(.array(Array(repeating: .integer(1), count: count)))
}

@Test(arguments: [1, 6])
func `count bounds reject values outside the range`(_ count: Int) throws {
    let schema = try strongestCountBoundsSchema()

    #expect(throws: Generable::Error.self) {
        try schema.validate(.array(Array(repeating: .integer(1), count: count)))
    }
}

@Test
func `count bounds reject contradictory ranges`() {
    #expect(throws: Generable::Error.self) {
        _ = try GenerationSchema.array(
            GenerationSchema.integer(),
            constraints: [.minimum(count: 2), .maximum(count: 1)],
        )
    }
}
