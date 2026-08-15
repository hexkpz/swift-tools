//
//  Created by Anton Spivak
//

@testable import GenerableMacros
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import Testing

private let macros: [String: Macro.Type] = [
    "Generable": GenerableMacro.self,
    "GenerableIgnored": GenerableIgnoredMacro.self,
    "Guide": GuideMacro.self,
]

// MARK: - GenerableDiagnosticCase

private enum GenerableDiagnosticCase: CaseIterable, Sendable, CustomTestStringConvertible {
    case lazyProperty
    case emptyEnumeration
    case inferredType
    case destructuring
    case immutableDefault
    case unsupportedDeclaration

    // MARK: Internal

    var testDescription: String {
        switch self {
        case .lazyProperty: "lazy stored property"
        case .emptyEnumeration: "empty enumeration"
        case .inferredType: "inferred property type"
        case .destructuring: "destructured property"
        case .immutableDefault: "immutable property with default"
        case .unsupportedDeclaration: "unsupported declaration"
        }
    }

    var expected: Diagnostic {
        switch self {
        case .lazyProperty: .lazyStoredProperty
        case .emptyEnumeration: .emptyEnumeration
        case .inferredType: .missingExplicitPropertyType("number")
        case .destructuring: .unsupportedStoredPropertyPattern
        case .immutableDefault: .immutablePropertyWithDefault
        case .unsupportedDeclaration: .invalidGenerableDeclaration
        }
    }

    var anchor: SyntaxKind {
        switch self {
        case .lazyProperty, .emptyEnumeration: .token
        case .inferredType: .identifierPattern
        case .destructuring: .tuplePattern
        case .immutableDefault: .initializerClause
        case .unsupportedDeclaration: .attribute
        }
    }

    var source: String {
        switch self {
        case .lazyProperty:
            """
            @Generable
            struct Value {
                lazy var number: Int = 0
            }
            """
        case .emptyEnumeration:
            """
            @Generable
            enum Empty {}
            """
        case .inferredType:
            """
            @Generable
            struct Value {
                var number = 0
            }
            """
        case .destructuring:
            """
            @Generable
            struct Value {
                var (first, second): (Int, Int)
            }
            """
        case .immutableDefault:
            """
            @Generable
            struct Value {
                let number: Int = 0
            }
            """
        case .unsupportedDeclaration:
            """
            @Generable
            class Value {}
            """
        }
    }
}

// MARK: - InvalidGuideContext

private enum InvalidGuideContext: CaseIterable, Sendable, CustomTestStringConvertible {
    case instancePropertyOutsideGenerable
    case staticProperty
    case globalProperty
    case localProperty

    // MARK: Internal

    var testDescription: String {
        switch self {
        case .instancePropertyOutsideGenerable: "instance property outside @Generable"
        case .staticProperty: "static property"
        case .globalProperty: "global property"
        case .localProperty: "local property"
        }
    }

    var source: String {
        switch self {
        case .instancePropertyOutsideGenerable:
            """
            struct Value {
                @Guide(description: "Ignored")
                var number: Int = 0
            }
            """
        case .staticProperty:
            """
            struct Value {
                @Guide(description: "Ignored")
                static var number: Int = 0
            }
            """
        case .globalProperty:
            """
            @Guide(description: "Ignored")
            var number: Int = 0
            """
        case .localProperty:
            """
            func function() {
                @Guide(description: "Ignored")
                var number: Int = 0
            }
            """
        }
    }
}

// MARK: - InvalidGenerableIgnoredContext

private enum InvalidGenerableIgnoredContext: CaseIterable, Sendable, CustomTestStringConvertible {
    case instancePropertyOutsideGenerable
    case staticProperty
    case computedProperty
    case missingDefault
    case guide

    // MARK: Internal

    var testDescription: String {
        switch self {
        case .instancePropertyOutsideGenerable: "instance property outside @Generable"
        case .staticProperty: "static property"
        case .computedProperty: "computed property"
        case .missingDefault: "missing default"
        case .guide: "guide"
        }
    }

    var expected: Diagnostic {
        switch self {
        case .instancePropertyOutsideGenerable, .staticProperty, .computedProperty:
            .invalidGenerableIgnoredDeclaration
        case .missingDefault:
            .ignoredPropertyWithoutDefault
        case .guide:
            .ignoredPropertyWithGuide
        }
    }

    var source: String {
        switch self {
        case .instancePropertyOutsideGenerable:
            """
            struct Value {
                @GenerableIgnored
                var number = 0
            }
            """
        case .staticProperty:
            """
            @Generable
            struct Value {
                @GenerableIgnored
                static var number = 0
            }
            """
        case .computedProperty:
            """
            @Generable
            struct Value {
                @GenerableIgnored
                var number: Int { 0 }
            }
            """
        case .missingDefault:
            """
            @Generable
            struct Value {
                @GenerableIgnored
                var number: Int
            }
            """
        case .guide:
            """
            @Generable
            struct Value {
                @GenerableIgnored
                @Guide(.minimum(0))
                var number = 0
            }
            """
        }
    }
}

@Test(arguments: GenerableDiagnosticCase.allCases)
private func `invalid declarations produce the expected diagnostic`(
    _ testCase: GenerableDiagnosticCase,
) throws {
    try expectSingleError(
        testCase.expected,
        anchoredTo: testCase.anchor,
        expanding: testCase.source,
    )
}

@Test(arguments: InvalidGuideContext.allCases)
private func `guides reject unsupported declaration contexts`(
    _ context: InvalidGuideContext,
) throws {
    try expectSingleError(
        .invalidGuideDeclaration,
        anchoredTo: .attribute,
        expanding: context.source,
    )
}

@Test(arguments: InvalidGenerableIgnoredContext.allCases)
private func `ignored properties reject unsupported declarations`(
    _ context: InvalidGenerableIgnoredContext,
) throws {
    try expectSingleError(
        context.expected,
        anchoredTo: .attribute,
        expanding: context.source,
    )
}

@Test
private func `peer macros reject ignored properties with multiple bindings`() {
    let sourceFile = Parser.parse(source: """
    @Generable
    struct Value {
        @GenerableIgnored
        var first = 1, second = 2
    }
    """)

    let context = BasicMacroExpansionContext()
    _ = sourceFile.expand(
        macros: macros,
        contextGenerator: { syntax in
            BasicMacroExpansionContext(
                sharingWith: context,
                lexicalContext: syntax.allMacroLexicalContexts(),
            )
        },
    )

    #expect(context.diagnostics.count == 1)
}

private func expectSingleError(
    _ expected: Diagnostic,
    anchoredTo anchor: SyntaxKind,
    expanding source: String,
) throws {
    let sourceFile = Parser.parse(source: source)
    let context = BasicMacroExpansionContext()

    _ = sourceFile.expand(
        macros: macros,
        contextGenerator: { syntax in
            BasicMacroExpansionContext(
                sharingWith: context,
                lexicalContext: syntax.allMacroLexicalContexts(),
            )
        },
    )

    try #require(context.diagnostics.count == 1)

    let diagnostic = try #require(context.diagnostics.first)
    #expect(diagnostic.diagMessage as? Diagnostic == expected)
    #expect(diagnostic.node.kind == anchor)
}
