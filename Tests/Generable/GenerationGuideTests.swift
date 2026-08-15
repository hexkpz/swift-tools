//
//  Created by Anton Spivak
//

import Testing
import Generable

// MARK: - GuidedIdentifier

@Generable
private struct GuidedIdentifier {
    @Guide(.validation(NonemptyIdentifierValidator()))
    var value: String
}

// MARK: - GenerationGuideTests

@Test
func `local validators stay local while enforcing generated values`() throws {
    let schema = try GuidedIdentifier.generationSchema

    let valid = GeneratedContent(properties: [("value", .string("value"))])
    let invalid = GeneratedContent(properties: [("value", .string(""))])

    let valueSchema = try #require(schema.document
        .property("properties")?
        .property("value"))

    #expect(stringValue(valueSchema.property("type")) == "string")
    #expect(valueSchema.property("format") == nil)

    _ = try generatedContentDecoder.decode(GuidedIdentifier.self, from: valid)
    #expect(throws: Generable::Error.self) {
        _ = try generatedContentDecoder.decode(GuidedIdentifier.self, from: invalid)
    }
}

@Test
func `repeated allowed-value guides intersect and deduplicate`() throws {
    let schema = try GenerationSchema.Property(
        name: "value",
        type: String.self,
        guides: [
            .anyOf(["first", "shared", "shared"]),
            .anyOf(["shared", "second"]),
        ],
    ).schema

    #expect(stringValues(schema.document.property("enum")) == ["shared"])
}

@Test
func `invalid runtime guide values throw instead of trapping`() {
    #expect(throws: Generable::Error.self) {
        _ = try GenerationSchema.Property(
            name: "value",
            type: Double.self,
            guides: [.minimum(.infinity)],
        )
    }

    #expect(throws: Generable::Error.self) {
        _ = try GenerationSchema.Property(
            name: "value",
            type: [Int].self,
            guides: [.maximum(count: -1)],
        )
    }
}
