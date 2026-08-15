//
//  Created by Anton Spivak
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct GenerableMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        GenerableMacro.self,
        GenerableIgnoredMacro.self,
        GuideMacro.self,
    ]
}
