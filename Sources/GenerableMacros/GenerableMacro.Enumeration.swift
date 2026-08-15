//
//  Created by Anton Spivak
//

import SwiftSyntax

extension GenerableMacro {
    struct Enumeration {
        // MARK: Lifecycle

        init(_ declaration: EnumDeclSyntax) {
            self.name = declaration.name.text.unescapedIdentifier
            self.cases = declaration.memberBlock.members.flatMap { member in
                member.decl.as(EnumCaseDeclSyntax.self)?.elements.map(Case.init) ?? []
            }
        }

        // MARK: Internal

        let name: String
        let cases: [Case]

        func members(
            description: String,
            access: String,
        ) -> ExpansionSource {
            // Payload-free enums map directly to strings. Associated-value enums need a
            // single-property object so the property name can identify the selected case.
            let isSimple = cases.allSatisfy(\.values.isEmpty)
            let schema: ExpansionSource =
                if isSimple { simpleSchema(description: description) }
                else { associatedSchema(description: description) }

            return GenerableMacro.conformanceMembers(
                access: access,
                schema: """
                Generable::GenerationSchema.definition(
                    of: Self.self,
                    name: Swift::String(reflecting: Self.self)
                ) { () throws(Generable::Error) -> Generable::GenerationSchema in
                    try \(schema)
                }
                """,
                decoding: isSimple ? simpleDecoding : associatedDecoding,
                encoding: isSimple ? simpleEncoding : associatedEncoding,
            )
        }

        // MARK: Private

        private var simpleDecoding: ExpansionSource {
            let switchCases = cases.lazy.map {
                "case \($0.name.swiftLiteral): self = .\($0.identifier)"
            }.lines

            return """
            let value = try Swift::String(from: &decoder)
            switch value {
            \(switchCases)
            default:
                throw Generable::Error.invalidValue(expected: \(raw: name.swiftLiteral))
            }
            """
        }

        private var simpleEncoding: ExpansionSource {
            let switchCases = cases.lazy.map {
                "case .\($0.identifier): try Swift::String(\($0.name.swiftLiteral)).encode(to: &encoder)"
            }.lines

            return """
            switch self {
            \(switchCases)
            }
            """
        }

        private var associatedDecoding: ExpansionSource {
            """
            switch try decoder.singlePropertyName() {
            \(cases.lazy.map(\.decode).lines)
            default:
                throw Generable::Error.invalidValue(expected: \(raw: name.swiftLiteral))
            }
            """
        }

        private var associatedEncoding: ExpansionSource {
            """
            switch self {
            \(cases.lazy.map(\.encode).lines)
            }
            """
        }

        private func associatedSchema(description: String) -> ExpansionSource {
            """
            .oneOf(
                [
                    \(cases.lazy.map(\.schema).commaSeparatedLines)
                ],
                name: \(raw: name.swiftLiteral),
                description: \(raw: description)
            )
            """
        }

        private func simpleSchema(description: String) -> ExpansionSource {
            let values = cases.lazy.map(\.name.swiftLiteral).commaSeparated
            return """
            .enumeration(
                name: \(raw: name.swiftLiteral),
                description: \(raw: description),
                values: [\(raw: values)]
            )
            """
        }
    }
}
