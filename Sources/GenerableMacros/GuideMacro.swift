//
//  Created by Anton Spivak
//

import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - GuideMacro

public struct GuideMacro: PeerMacro {
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
            context.diagnose(.invalidGuideDeclaration, at: attribute)
            return []
        }

        return []
    }
}
