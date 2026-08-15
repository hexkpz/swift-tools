//
//  Created by Anton Spivak
//

import Testing
@testable import Generable

// MARK: - RecursiveNode

@Generable
private struct RecursiveNode {
    var value: Int
    var children: [RecursiveNode]
}

// MARK: - ValidatedRecursiveNode

@Generable
private struct ValidatedRecursiveNode {
    @Guide(.validation(NonemptyIdentifierValidator()))
    var value: String
    var children: [ValidatedRecursiveNode]
}

// MARK: - MutualReferenceCycleA

private struct MutualReferenceCycleA: Generable {
    // MARK: Lifecycle

    init(from _: inout GenerationDecoder) throws {}

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) {
            try .definition(of: Self.self, name: String(reflecting: Self.self)) {
                () throws(Generable::Error) -> GenerationSchema in
                try MutualReferenceCycleB.generationSchema
            }
        }
    }

    func encode(to _: inout GenerationEncoder) throws {}
}

// MARK: - MutualReferenceCycleB

private struct MutualReferenceCycleB: Generable {
    // MARK: Lifecycle

    init(from _: inout GenerationDecoder) throws {}

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) {
            try .definition(of: Self.self, name: String(reflecting: Self.self)) {
                () throws(Generable::Error) -> GenerationSchema in
                try MutualReferenceCycleA.generationSchema
            }
        }
    }

    func encode(to _: inout GenerationEncoder) throws {}
}

// MARK: - Address

@Generable
private struct Address {
    var street: String
}

// MARK: - Delivery

@Generable
private struct Delivery {
    var origin: Address
    var destination: Address
}

// MARK: - Envelope

@Generable
private struct Envelope {
    var address: Address
}

@Test
func `recursive schemas use definitions and references`() throws {
    let schema = try RecursiveNode.generationSchema

    guard case let .object(definitions)? = schema.generatedContent.property("$defs"),
          let definition = definitions.first(where: { $0.name.hasSuffix(".RecursiveNode") }),
          let node = schema.generatedContent.property("$defs")?.property(definition.name),
          let children = node.property("properties")?.property("children"),
          let reference = stringValue(children.property("items")?.property("$ref"))
    else {
        Issue.record("Expected a recursive schema definition.")
        return
    }

    #expect(reference == "#/$defs/\(definition.name)")

    try schema.validate(GeneratedContent(RecursiveNode(
        value: 1,
        children: [.init(value: 2, children: [])],
    )))
}

@Test(arguments: [
    ("plain", "#/$defs/plain"),
    ("a~/b", "#/$defs/a~0~1b"),
])
func `reference names are escaped as JSON Pointer components`(
    _ name: String,
    _ expected: String,
) {
    let reference = Graph.Reference(
        id: .init(type: ObjectIdentifier(RecursiveNode.self)),
        name: name,
    )
    #expect(reference.pointer == expected)
}

@Test
func `unproductive reference cycles are rejected`() {
    #expect(throws: Generable::Error.self) {
        _ = try MutualReferenceCycleA.generationSchema
    }
}

@Test
func `recursive schemas apply local validation at every level`() throws {
    let schema = try ValidatedRecursiveNode.generationSchema
    let valid = ValidatedRecursiveNode(
        value: "root",
        children: [.init(value: "child", children: [])],
    )

    try schema.validate(GeneratedContent(valid))
    #expect(throws: Generable::Error.self) {
        try schema.validate(GeneratedContent(ValidatedRecursiveNode(
            value: "root",
            children: [.init(value: "", children: [])],
        )))
    }
}

@Test
func `reused named schemas share one canonical definition`() throws {
    let schema = try Delivery.generationSchema

    guard case let .object(definitions)? = schema.generatedContent.property("$defs"),
          let properties = schema.generatedContent.property("properties"),
          let origin = stringValue(properties.property("origin")?.property("$ref")),
          let destination = stringValue(properties.property("destination")?.property("$ref"))
    else {
        Issue.record("Expected shared named schema references.")
        return
    }

    #expect(definitions.count == 1)
    #expect(origin == destination)
    #expect(origin == "#/$defs/\(definitions[0].name)")
}

@Test
func `inline schemas are promoted only when reused`() throws {
    let inline = try Envelope.generationSchema

    #expect(inline.generatedContent.property("$defs") == nil)
    #expect(inline.generatedContent
        .property("properties")?
        .property("address")?
        .property("$ref") == nil)

    let reused = try GenerationSchema.structure(properties: [
        .init(name: "first", schema: inline),
        .init(name: "second", schema: inline),
    ])

    #expect(reused.generatedContent.property("$defs") != nil)
    #expect(reused.generatedContent
        .property("properties")?
        .property("first")?
        .property("properties")?
        .property("address")?
        .property("$ref") != nil)
}

@Test
func `nesting a recursive schema retains its definitions`() throws {
    let recursive = try RecursiveNode.generationSchema
    let schema = try GenerationSchema.structure(properties: [
        .init(name: "node", schema: recursive),
    ])

    #expect(schema.generatedContent.property("$defs") != nil)
    try schema.validate(.init(properties: [("node", GeneratedContent(RecursiveNode(
        value: 1,
        children: [.init(value: 2, children: [])],
    )))]))
}
