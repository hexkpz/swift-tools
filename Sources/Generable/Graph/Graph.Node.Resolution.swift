//
//  Created by Anton Spivak
//

extension Graph.Node {
    func resolving(
        references: [Graph.Reference.ID: Graph.Node],
    ) throws(Error) -> (
        node: Graph.Node,
        validations: [AnyGenerationSchemaValidator],
    ) {
        var node = self
        var validations: [AnyGenerationSchemaValidator] = []

        while true {
            switch node {
            case let .reference(reference):
                guard let resolved = references[reference.id] else {
                    throw Error.undefinedReference(reference.pointer)
                }
                node = resolved
            case let .refinement(wrapped, current):
                validations.append(contentsOf: current.reversed())
                node = wrapped
            default:
                validations.reverse()
                return (node, validations)
            }
        }
    }
}
