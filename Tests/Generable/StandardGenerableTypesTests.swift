//
//  Created by Anton Spivak
//

import Testing
import Generable

// MARK: - StandardValues

@Generable
private struct StandardValues: Equatable, CustomTestStringConvertible {
    var boolean: Bool
    var integer: Int64
    var number: Double
    var string: String
    var array: ContiguousArray<Int>
    var set: Set<String>
    var dictionary: [String: Bool]
    var optional: Int?

    var testDescription: String { optional == nil ? "nil optional" : "populated optional" }
}

private let standardValues: [StandardValues] = [
    .init(
        boolean: true,
        integer: .min,
        number: 1.5,
        string: "value",
        array: [1, 2, 3],
        set: ["first", "second"],
        dictionary: ["first": true, "second": false],
        optional: nil,
    ),
    .init(
        boolean: false,
        integer: .max,
        number: -0.5,
        string: "",
        array: [],
        set: [],
        dictionary: [:],
        optional: 42,
    ),
]

@Test(arguments: standardValues)
private func `standard generable values round trip through their schema`(
    _ value: StandardValues,
) throws {
    let content = try generatedContentEncoder.encode(value)

    try StandardValues.generationSchema.validate(content)
    #expect(try generatedContentDecoder.decode(StandardValues.self, from: content) == value)
    #expect((content.property("optional") == nil) == (value.optional == nil))
}
