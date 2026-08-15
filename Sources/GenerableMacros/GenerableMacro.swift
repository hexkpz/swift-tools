//
//  Created by Anton Spivak
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct GenerableMacro: ExtensionMacro {
    public static func expansion(
        of attribute: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [ExtensionDeclSyntax] {
        let description = attribute.argument(named: "description") ?? "nil"
        let access = declaration.modifiers.accessPrefix(in: context)
        let members: ExpansionSource

        if let declaration = declaration.as(StructDeclSyntax.self) {
            let structure = Structure(declaration)
            for issue in structure.issues {
                context.diagnose(issue.diagnostic, at: issue.node)
            }

            guard structure.issues.isEmpty else { return [] }
            members = structure.members(
                description: description,
                access: access,
            )
        } else if let declaration = declaration.as(EnumDeclSyntax.self) {
            let enumeration = Enumeration(declaration)
            guard !enumeration.cases.isEmpty else {
                context.diagnose(.emptyEnumeration, at: declaration.name)
                return []
            }

            members = enumeration.members(
                description: description,
                access: access,
            )
        } else {
            context.diagnose(.invalidGenerableDeclaration, at: attribute)
            return []
        }

        return try [ExtensionDeclSyntax(
            """
            extension \(type.trimmed): Generable::Generable {
            \(raw: members.text)
            }
            """,
        )]
    }
}
