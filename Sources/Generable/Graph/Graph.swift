//
//  Created by Anton Spivak
//

// MARK: - Graph

struct Graph: Sendable {
    // MARK: Lifecycle

    init(
        fragment: Fragment,
        registry: Registry,
    ) {
        self.registry = registry
        self.root = fragment
        self.references = [:]
        self.content = fragment.content
    }

    init(
        root: Fragment,
        registry: Registry,
    ) throws(Error) {
        let result = try Assembly.assemble(root: root, registry: registry)

        self.registry = result.registry
        self.root = root
        self.references = result.references
        self.content = result.content
    }

    private init(
        fragment: Fragment,
        registry: Registry,
        references: [Reference.ID: Node],
        content: GeneratedContent,
    ) {
        self.registry = registry
        self.root = fragment
        self.references = references
        self.content = content
    }

    // MARK: Internal

    struct Fragment: Sendable {
        // MARK: Lifecycle

        init(node: consuming Node, content: consuming GeneratedContent) {
            self.node = node
            self.content = content
        }

        // MARK: Internal

        let node: Node
        let content: GeneratedContent
    }

    struct Entry: Sendable {
        // MARK: Lifecycle

        init(reference: consuming Reference, fragment: consuming Fragment) {
            self.reference = reference
            self.fragment = fragment
        }

        // MARK: Internal

        let reference: Reference
        let fragment: Fragment
    }

    let registry: Registry
    let root: Fragment
    let references: [Reference.ID: Node]
    let content: GeneratedContent

    func applying(_ validations: [AnyGenerationSchemaValidator]) -> Self {
        .init(
            fragment: .init(node: root.node.applying(validations), content: root.content),
            registry: registry,
            references: references,
            content: content,
        )
    }

    func validate(_ content: GeneratedContent) throws(Error) {
        try root.node.validate(content, references: references)
    }
}
