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

#if canImport(FoundationEssentials) || canImport(Foundation)

// MARK: - JSONExample

private struct JSONExample: Sendable, CustomTestStringConvertible {
    let testDescription: String
    let input: String
    let canonical: String
}

private let JSONExamples: [JSONExample] = [
    .init(
        testDescription: "null",
        input: "null",
        canonical: "null",
    ),
    .init(
        testDescription: "boolean",
        input: "true",
        canonical: "true",
    ),
    .init(
        testDescription: "integer",
        input: "-42",
        canonical: "-42",
    ),
    .init(
        testDescription: "number",
        input: "1.5",
        canonical: "1.5",
    ),
    .init(
        testDescription: "string",
        input: #""value""#,
        canonical: #""value""#,
    ),
    .init(
        testDescription: "array",
        input: #"[null,true,1,1.5,"value"]"#,
        canonical: #"[null,true,1,1.5,"value"]"#,
    ),
    .init(
        testDescription: "nested object",
        input: #"{"z":1,"a":{"d":4,"c":3}}"#,
        canonical: #"{"a":{"c":3,"d":4},"z":1}"#,
    ),
]

@Test(arguments: JSONExamples)
private func `JSON values round trip through canonical data`(_ example: JSONExample) throws {
    let content = try #require(GeneratedContent(example.input))
    let data = try content.data()

    #expect(String(decoding: data, as: UTF8.self) == example.canonical)
    #expect(try GeneratedContent(data).description == example.canonical)
}

@Test(arguments: ["", "{", "[", "NaN"])
func `malformed JSON is rejected`(_ JSON: String) {
    #expect(GeneratedContent(JSON) == nil)
}

@Test
func `nonrepresentable content descriptions are not parseable JSON`() {
    let description = GeneratedContent.number(.nan).description

    #expect(description.hasPrefix("<invalid content:"))
    #expect(GeneratedContent(description) == nil)
}

#endif
