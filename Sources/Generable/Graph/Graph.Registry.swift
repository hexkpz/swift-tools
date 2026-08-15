//
//  Created by Anton Spivak
//

// MARK: - Graph.Registry

extension Graph {
    struct Registry: Sendable {
        // MARK: Lifecycle

        init() {}

        // swiftformat:disable:next spaceAroundBrackets
        init(entries: consuming [Reference.ID: Entry]) throws(Error) {
            self.init()
            self.entries.reserveCapacity(entries.count)
            idsByPointer.reserveCapacity(entries.count)

            for entry in entries.values {
                try insert(entry)
            }
        }

        // MARK: Internal

        func entry(for id: Reference.ID) -> Entry? {
            entries[id]
        }

        func entry(forPointer pointer: String) -> Entry? {
            idsByPointer[pointer].flatMap { entries[$0] }
        }

        // MARK: Private

        private var entries: [Reference.ID: Entry] = [:]
        private var idsByPointer: [String: Reference.ID] = [:]
    }
}

extension Graph.Registry {
    mutating func insert(_ entry: consuming Graph.Entry) throws(Error) {
        let id = entry.reference.id
        let pointer = entry.reference.pointer

        if let existing = entries[id] {
            guard existing.reference.pointer == pointer else {
                throw .duplicateDefinition(entry.reference.name)
            }
            return
        }

        guard idsByPointer[pointer] == nil else {
            throw .duplicateDefinition(entry.reference.name)
        }

        idsByPointer[pointer] = id
        entries[id] = entry
    }

    mutating func merge(_ other: Self) throws(Error) {
        entries.reserveCapacity(entries.count + other.entries.count)
        idsByPointer.reserveCapacity(idsByPointer.count + other.idsByPointer.count)
        for entry in other.entries.values {
            try insert(entry)
        }
    }
}
