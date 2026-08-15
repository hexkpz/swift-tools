//
//  Created by Anton Spivak
//

func resolveSingleProperty(
    named name: String,
    in node: Graph.Node,
    references: [Graph.Reference.ID: Graph.Node],
) throws(Error) -> (
    property: Graph.Structure.Property,
    validations: [AnyGenerationSchemaValidator],
) {
    guard case let .oneOf(nodes) = node else {
        throw Error.invalidValue(expected: "an object composition")
    }

    var match: (property: Graph.Structure.Property, validations: [AnyGenerationSchemaValidator])?
    // Associated-value enum cases are represented as one-property structures inside `oneOf`.
    // The property name acts as the case discriminator for both decoding and encoding.
    for node in nodes {
        let resolution = try node.resolving(references: references)
        guard case let .structure(structure) = resolution.node,
              structure.properties.count == 1,
              let property = structure.properties.first,
              property.name == name
        else { continue }

        guard match == nil else {
            throw Error.invalidValue(expected: "exactly one matching property")
        }

        match = (property, resolution.validations)
    }

    guard let match else {
        throw Error.invalidValue(expected: "a declared property")
    }

    return match
}
