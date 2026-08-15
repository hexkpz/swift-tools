//
//  Created by Anton Spivak
//

import SwiftSyntax

// MARK: - GenerableMacro.Structure

extension GenerableMacro {
    struct Structure {
        // MARK: Lifecycle

        init(_ declaration: StructDeclSyntax) {
            let (properties, issues) = Self.scanStoredProperties(
                in: declaration.memberBlock.members,
            )

            self.name = declaration.name.text.unescapedIdentifier
            self.properties = properties
            self.issues = issues
        }

        // MARK: Internal

        let name: String
        let properties: [StoredProperty]
        let issues: [Issue]

        func members(description: String, access: String) -> ExpansionSource {
            GenerableMacro.conformanceMembers(
                access: access,
                schema: """
                Generable::GenerationSchema.definition(
                    of: Self.self,
                    name: Swift::String(reflecting: Self.self)
                ) { () throws(Generable::Error) -> Generable::GenerationSchema in
                    try .structure(
                        name: \(raw: name.swiftLiteral),
                        description: \(raw: description),
                        properties: [
                            \(properties.lazy.map(\.field.schema).commaSeparatedLines)
                        ]
                    )
                }
                """,
                decoding: properties
                    .lazy
                    .map { "self.\($0.identifier) = \($0.field.decode())" }.lines,
                encoding: properties
                    .lazy
                    .map { $0.field.encode("self.\($0.identifier)") }.lines,
            )
        }
    }
}

private extension GenerableMacro.Structure {
    static func scanStoredProperties(
        in members: MemberBlockItemListSyntax,
    ) -> (properties: [StoredProperty], issues: [Issue]) {
        var properties: [StoredProperty] = []
        var issues: [Issue] = []
        properties.reserveCapacity(members.count)

        for member in members {
            guard let declaration = member.decl.as(VariableDeclSyntax.self),
                  !declaration.modifiers.isTypeMember
            else { continue }

            appendStoredProperties(
                from: declaration,
                to: &properties,
                issues: &issues,
            )
        }

        return (properties, issues)
    }

    static func appendStoredProperties(
        from declaration: VariableDeclSyntax,
        to properties: inout [StoredProperty],
        issues: inout [Issue],
    ) {
        if declaration.attributes.containsMacro(named: "GenerableIgnored") { return }

        if let modifier = declaration.modifiers.first(where: { $0.name.text == "lazy" }) {
            issues.append(.init(Syntax(modifier.name), .lazyStoredProperty))
            return
        }

        let isImmutable = declaration.bindingSpecifier.tokenKind == .keyword(.let)
        for binding in declaration.bindings where binding.isStoredProperty {
            appendStoredProperty(
                from: binding,
                attributes: declaration.attributes,
                isImmutable: isImmutable,
                to: &properties,
                issues: &issues,
            )
        }
    }

    static func appendStoredProperty(
        from binding: PatternBindingSyntax,
        attributes: AttributeListSyntax,
        isImmutable: Bool,
        to properties: inout [StoredProperty],
        issues: inout [Issue],
    ) {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
            issues.append(.init(
                Syntax(binding.pattern),
                .unsupportedStoredPropertyPattern,
            ))
            return
        }

        guard let type = binding.typeAnnotation?.type else {
            issues.append(.init(Syntax(binding.pattern), .missingExplicitPropertyType(
                pattern.identifier.text.unescapedIdentifier,
            )))
            return
        }

        if isImmutable, let initializer = binding.initializer {
            issues.append(.init(
                Syntax(initializer),
                .immutablePropertyWithDefault,
            ))
            return
        }

        properties.append(.init(
            identifier: pattern.identifier,
            type: type,
            attributes: attributes,
        ))
    }
}

// MARK: - GenerableMacro.Structure.StoredProperty

extension GenerableMacro.Structure {
    struct StoredProperty {
        // MARK: Lifecycle

        init(identifier: TokenSyntax, type: TypeSyntax, attributes: AttributeListSyntax) {
            self.identifier = identifier.trimmedDescription
            self.field = GenerableMacro.Field(
                name: identifier.text.unescapedIdentifier,
                type: type,
                attributes: attributes,
            )
        }

        // MARK: Internal

        let identifier: String
        let field: GenerableMacro.Field
    }
}

// MARK: - GenerableMacro.Structure.Issue

extension GenerableMacro.Structure {
    struct Issue {
        // MARK: Lifecycle

        init(_ node: Syntax, _ diagnostic: Diagnostic) {
            self.node = node
            self.diagnostic = diagnostic
        }

        // MARK: Internal

        let node: Syntax
        let diagnostic: Diagnostic
    }
}

extension PatternBindingSyntax {
    var isStoredProperty: Bool {
        guard let accessorBlock else { return true }
        guard case let .accessors(accessors) = accessorBlock.accessors else { return false }
        return accessors.allSatisfy {
            $0.accessorSpecifier.text == "willSet" || $0.accessorSpecifier.text == "didSet"
        }
    }
}
