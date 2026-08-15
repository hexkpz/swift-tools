//
//  Created by Anton Spivak
//

// MARK: - Graph.Reference

extension Graph {
    struct Reference: Sendable {
        // MARK: Lifecycle

        init(id: ID, name: String) {
            self.id = id
            self.name = name

            self.pointer = "#/$defs/\(name.jsonPointerComponent)"
        }

        // MARK: Internal

        let id: ID
        let name: String

        let pointer: String
    }
}

// MARK: - Graph.Reference.ID

extension Graph.Reference {
    struct ID: Sendable, Hashable {
        let type: ObjectIdentifier
    }
}

private extension String {
    var jsonPointerComponent: String {
        guard let firstEscapedIndex = firstIndex(where: { $0 == "~" || $0 == "/" })
        else { return self }

        var result = String(self[..<firstEscapedIndex])
        result.reserveCapacity(utf8.count + 1)

        for character in self[firstEscapedIndex...] {
            switch character {
            case "~": result.append(contentsOf: "~0")
            case "/": result.append(contentsOf: "~1")
            default: result.append(character)
            }
        }

        return result
    }
}
