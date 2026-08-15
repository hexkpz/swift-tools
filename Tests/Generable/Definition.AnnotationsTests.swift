//
//  Created by Anton Spivak
//

import Testing
import Generable

// MARK: - AnnotatedAddress

@Generable
private struct AnnotatedAddress {
    var street: String
}

// MARK: - AnnotatedDelivery

@Generable
private struct AnnotatedDelivery {
    @Guide(description: "The origin address.")
    var origin: AnnotatedAddress
    var destination: AnnotatedAddress
}

@Test
func `annotations wrap compositions and references without replacing them`() throws {
    let optional = try GenerationSchema.Property(
        name: "value",
        description: "An optional integer.",
        type: Int?.self,
    ).schema.document

    let referenced = try AnnotatedDelivery.generationSchema.document
        .property("properties")?
        .property("origin")

    #expect(stringValue(optional.property("description")) == "An optional integer.")
    #expect(optional.property("anyOf") != nil)
    #expect(stringValue(referenced?.property("description")) == "The origin address.")
    #expect(referenced?.property("anyOf") != nil)
}

@Test
func `annotations preserve impossible schemas`() throws {
    let schema = try GenerationSchema.Property(
        name: "value",
        description: "An impossible value.",
        type: Never.self,
    ).schema

    #expect(stringValue(schema.document.property("description")) == "An impossible value.")
    #expect(schema.document.property("not") != nil)
    #expect(throws: Generable::Error.self) { try schema.validate(.null) }
}
