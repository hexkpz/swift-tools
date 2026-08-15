//
//  Created by Anton Spivak
//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - Diagnostic

enum Diagnostic: DiagnosticMessage, Equatable {
    case invalidGenerableDeclaration

    case emptyEnumeration
    case lazyStoredProperty
    case unsupportedStoredPropertyPattern
    case missingExplicitPropertyType(String)
    case immutablePropertyWithDefault

    case invalidGuideDeclaration
    case invalidGenerableIgnoredDeclaration

    case ignoredPropertyWithoutDefault
    case ignoredPropertyWithGuide

    // MARK: Internal

    var diagnosticID: MessageID {
        MessageID(domain: "GenerableMacros", id: id)
    }

    var message: String {
        switch self {
        case .invalidGenerableDeclaration:
            "@Generable can only be applied to a struct or enum."
        case .emptyEnumeration:
            "@Generable requires an enum to declare at least one case."
        case .lazyStoredProperty:
            "@Generable does not support lazy stored properties."
        case .unsupportedStoredPropertyPattern:
            "@Generable requires stored properties to use a single name."
        case let .missingExplicitPropertyType(name):
            "@Generable requires an explicit type for stored property \(name.swiftLiteral)."
        case .immutablePropertyWithDefault:
            "@Generable cannot initialize an immutable property that already has a default value."
        case .invalidGuideDeclaration:
            "@Guide can only be applied to an instance stored property in an @Generable structure."
        case .invalidGenerableIgnoredDeclaration:
            "@GenerableIgnored can only be applied to an instance stored property in an @Generable structure."
        case .ignoredPropertyWithoutDefault:
            "@GenerableIgnored requires a default value."
        case .ignoredPropertyWithGuide:
            "@GenerableIgnored cannot be combined with @Guide."
        }
    }

    var severity: DiagnosticSeverity { .error }

    // MARK: Private

    private var id: String {
        switch self {
        case .invalidGenerableDeclaration: "invalid-generable-declaration"
        case .emptyEnumeration: "empty-enumeration"
        case .lazyStoredProperty: "lazy-stored-property"
        case .unsupportedStoredPropertyPattern: "unsupported-stored-property-pattern"
        case .missingExplicitPropertyType: "missing-explicit-property-type"
        case .immutablePropertyWithDefault: "immutable-property-with-default"
        case .invalidGuideDeclaration: "invalid-guide-declaration"
        case .invalidGenerableIgnoredDeclaration: "invalid-generable-ignored-declaration"
        case .ignoredPropertyWithoutDefault: "ignored-property-without-default"
        case .ignoredPropertyWithGuide: "ignored-property-with-guide"
        }
    }
}

extension MacroExpansionContext {
    func diagnose(_ diagnostic: Diagnostic, at node: some SyntaxProtocol) {
        diagnose(SwiftDiagnostics::Diagnostic(node: Syntax(node), message: diagnostic))
    }
}
