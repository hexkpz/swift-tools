//
//  Created by Anton Spivak
//

import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - GenerableIgnoredMacro

public struct GenerableIgnoredMacro: PeerMacro {
    public static func expansion(
        of attribute: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        guard let variable = declaration.as(VariableDeclSyntax.self),
              context.isInGenerableStructure,
              !variable.modifiers.isTypeMember,
              variable.bindings.allSatisfy(\.isStoredProperty)
        else {
            context.diagnose(.invalidGenerableIgnoredDeclaration, at: attribute)
            return []
        }

        guard variable.bindings.first?.initializer != nil else {
            context.diagnose(.ignoredPropertyWithoutDefault, at: attribute)
            return []
        }

        guard !variable.attributes.containsMacro(named: "Guide") else {
            context.diagnose(.ignoredPropertyWithGuide, at: attribute)
            return []
        }

        return []
    }
}
