//
//  Created by Anton Spivak
//

import SwiftSyntax

// MARK: - GenerableMacro.Enumeration.Case

extension GenerableMacro.Enumeration {
    struct Case {
        // MARK: Lifecycle

        init(_ element: EnumCaseElementSyntax) {
            self.name = element.name.text.unescapedIdentifier
            self.identifier = element.name.trimmedDescription
            self.values = element.parameterClause?.parameters.enumerated().map {
                AssociatedValue(index: $0.offset, parameter: $0.element)
            } ?? []
        }

        // MARK: Internal

        let name: String
        let identifier: String
        let values: [AssociatedValue]

        var schema: ExpansionSource {
            let payload: ExpansionSource = if values.isEmpty { "try .null" } else {
                """
                try .structure(properties: [
                    \(values.lazy.map(\.field.schema).commaSeparatedLines)
                ])
                """
            }

            return """
            try .structure(properties: [
                .init(
                    name: \(raw: name.swiftLiteral),
                    schema: \(payload)
                )
            ])
            """
        }

        var decode: ExpansionSource {
            guard !values.isEmpty else {
                // swiftformat:disable wrap wrapArguments
                return """
                case \(raw: name.swiftLiteral):
                    try decoder.decode(forProperty: \(raw: name.swiftLiteral)) { payload in try payload.decodeNil() }
                    self = .\(raw: identifier)
                """
                // swiftformat:enable wrap wrapArguments
            }

            let expressions = values.map { value in value.field.decode(from: "payload") }

            let binding: String
            let body: String

            if let expression = expressions.first, expressions.count == 1 {
                binding = "let value0"
                body = expression
            } else {
                binding = "let (\(values.map { "value\($0.index)" }.commaSeparated))"
                body = "(\(expressions.commaSeparated))"
            }

            // swiftformat:disable wrap wrapArguments
            return """
            case \(raw: name.swiftLiteral):
                \(raw: binding) = try decoder.decode(forProperty: \(raw: name.swiftLiteral)) { payload in \(raw: body) }
                self = .\(raw: identifier)(\(raw: values.lazy.map(\.argument).commaSeparated))
            """
            // swiftformat:enable wrap wrapArguments
        }

        var encode: ExpansionSource {
            guard !values.isEmpty else {
                return """
                case .\(raw: identifier):
                    try encoder.encode(forProperty: \(raw: name
                    .swiftLiteral)) { payload in try payload.encodeNil() }
                """
            }

            let bindings = values.indices.map { "value\($0)" }
            let fields = values.enumerated().lazy.map {
                $0.element.field.encode(bindings[$0.offset], to: "payload")
            }.lines

            // swiftformat:disable wrap wrapArguments
            return """
            case let .\(raw: identifier)(\(raw: bindings.commaSeparated)):
                try encoder.encode(forProperty: \(raw: name.swiftLiteral)) { payload in \(fields) }
            """
            // swiftformat:enable wrap wrapArguments
        }
    }
}

// MARK: - GenerableMacro.Enumeration.Case.AssociatedValue

extension GenerableMacro.Enumeration.Case {
    struct AssociatedValue {
        // MARK: Lifecycle

        init(index: Int, parameter: EnumCaseParameterSyntax) {
            let label = parameter.firstName.flatMap { $0.text == "_" ? nil : $0 }

            self.index = index
            self.label = label?.trimmedDescription

            self.field = GenerableMacro.Field(
                name: label?.text.unescapedIdentifier ?? "_\(index)",
                type: parameter.type,
            )
        }

        // MARK: Internal

        let index: Int
        let label: String?
        let field: GenerableMacro.Field

        var argument: String {
            let value = "value\(index)"
            return label.map { "\($0): \(value)" } ?? value
        }
    }
}
