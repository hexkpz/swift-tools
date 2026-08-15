//
//  Created by Anton Spivak
//

import SwiftSyntax

// MARK: - GenerableMacro.Field

extension GenerableMacro {
    struct Field {
        // MARK: Lifecycle

        init(
            name: String,
            type: TypeSyntax,
            attributes: AttributeListSyntax = [],
        ) {
            let guide = attributes.guide
            let type = type.trimmedDescription

            self.name = name
            self.type = type

            self.schema = """
            try .init(
                name: \(raw: name.swiftLiteral),
                description: \(raw: guide.description),
                type: \(raw: type).self,
                guides: [\(raw: guide.guides.commaSeparated)]
            )
            """
        }

        // MARK: Internal

        let name: String
        let type: String
        let schema: ExpansionSource

        func decode(from decoder: String = "decoder") -> String {
            "try \(decoder).decode(\(type).self, forProperty: \(name.swiftLiteral))"
        }

        func encode(_ value: String, to encoder: String = "encoder") -> String {
            "try \(encoder).encode(\(value), forProperty: \(name.swiftLiteral))"
        }
    }
}

private extension AttributeListSyntax {
    var guide: (description: String, guides: [String]) {
        for element in self {
            guard case let .attribute(attribute) = element,
                  attribute.isMacro(named: "Guide"),
                  let arguments = attribute.arguments?.as(LabeledExprListSyntax.self)
            else { continue }

            var description = "nil"
            var guides: [String] = []

            for argument in arguments {
                if argument.label?.text == "description" {
                    description = argument.expression.trimmedDescription
                } else {
                    guides.append(argument.expression.trimmedDescription)
                }
            }

            return (description, guides)
        }

        return ("nil", [])
    }
}
