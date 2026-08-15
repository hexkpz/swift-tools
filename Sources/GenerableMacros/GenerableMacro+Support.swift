//
//  Created by Anton Spivak
//

import SwiftSyntax
import SwiftSyntaxMacros

extension GenerableMacro {
    static func conformanceMembers(
        access: String,
        schema: ExpansionSource,
        decoding: ExpansionSource,
        encoding: ExpansionSource,
    ) -> ExpansionSource {
        """
        \(raw: access)static var generationSchema: Generable::GenerationSchema {
            get throws(Generable::Error) {
                try \(schema)
            }
        }

        \(raw: access)init(from decoder: inout Generable::GenerationDecoder) throws {
            \(decoding)
        }

        \(raw: access)func encode(to encoder: inout Generable::GenerationEncoder) throws {
            \(encoding)
        }
        """
    }
}

extension AttributeSyntax {
    func argument(named name: String) -> String? {
        guard let arguments = arguments?.as(LabeledExprListSyntax.self) else { return nil }
        return arguments.first(where: { $0.label?.text == name })?.expression.trimmedDescription
    }

    func isMacro(named name: String) -> Bool {
        let attributeName = attributeName.trimmedDescription
        return attributeName == name
            || attributeName.hasSuffix(".\(name)")
            || attributeName.hasSuffix("::\(name)")
    }
}

extension AttributeListSyntax {
    func containsMacro(named name: String) -> Bool {
        contains { element in
            guard case let .attribute(attribute) = element else { return false }
            return attribute.isMacro(named: name)
        }
    }
}

extension DeclModifierListSyntax {
    var accessPrefix: String {
        if contains(where: { $0.name.tokenKind == .keyword(.public) }) { "public " }
        else if contains(where: { $0.name.tokenKind == .keyword(.package) }) { "package " }
        else { "" }
    }

    var isTypeMember: Bool {
        contains { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }
    }

    func accessPrefix(in context: some MacroExpansionContext) -> String {
        let access = accessPrefix
        guard access.isEmpty else { return access }

        for syntax in context.lexicalContext {
            guard let declaration = syntax.as(ExtensionDeclSyntax.self) else { continue }
            return declaration.modifiers.accessPrefix
        }

        return ""
    }
}

extension MacroExpansionContext {
    var isInGenerableStructure: Bool {
        for context in lexicalContext {
            if context.is(ClosureExprSyntax.self)
                || context.is(SubscriptDeclSyntax.self)
                || context.asProtocol(WithOptionalCodeBlockSyntax.self) != nil
            {
                return false
            }

            if let structure = context.as(StructDeclSyntax.self) {
                return structure.attributes.containsMacro(named: "Generable")
            }

            if context.is(ClassDeclSyntax.self)
                || context.is(ActorDeclSyntax.self)
                || context.is(EnumDeclSyntax.self)
            {
                return false
            }
        }

        return false
    }
}

extension String {
    var swiftLiteral: String { String(reflecting: self) }

    var unescapedIdentifier: String {
        guard first == "`", last == "`" else { return self }
        return String(dropFirst().dropLast())
    }
}

extension Sequence where Element == String {
    var lines: ExpansionSource { .init(raw: joined(separator: "\n")) }

    var commaSeparated: String { joined(separator: ", ") }
    var commaSeparatedLines: ExpansionSource { .init(raw: joined(separator: ",\n")) }
}
