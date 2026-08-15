//
//  Created by Anton Spivak
//

// MARK: - Definition.Annotations

extension Definition {
    struct Annotations: Sendable {
        // MARK: Lifecycle

        init(
            title: String? = nil,
            description: String? = nil,
        ) {
            self.title = title
            self.description = description
        }

        // MARK: Internal

        var title: String?
        var description: String?

        var isEmpty: Bool {
            title == nil && description == nil
        }

        var generatedPropertyCount: Int {
            (title == nil ? 0 : 1) +
                (description == nil ? 0 : 1)
        }
    }
}

extension Definition.Annotations {
    mutating func apply(_ annotations: Self) {
        if let title = annotations.title { self.title = title }
        if let description = annotations.description { self.description = description }
    }

    func appendGeneratedProperties(to properties: inout [GeneratedContent.Property]) {
        if let title { properties.append(.init("title", .string(title))) }
        if let description { properties.append(.init("description", .string(description))) }
    }
}
