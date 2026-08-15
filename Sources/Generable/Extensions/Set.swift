//
//  Created by Anton Spivak
//

// MARK: - Set + Generable

extension Set: Generable where Element: Generable {
    public static var generationSchema: GenerationSchema {
        get throws(Error) {
            try GenerationSchema.array(Element.generationSchema)
                .validating(UniqueSetValidator<Element>())
        }
    }

    public init(from decoder: inout GenerationDecoder) throws {
        self = try decoder.decode()
    }

    public func encode(to encoder: inout GenerationEncoder) throws {
        try encoder.encode(self)
    }
}

// MARK: - UniqueSetValidator

private struct UniqueSetValidator<Element: Generable & Hashable>: GenerationSchema.Validator {
    typealias Value = Set<Element>

    let expected = "an array with unique generated elements"

    func matches(_ content: GeneratedContent) -> Bool {
        guard case let .array(elements) = content else { return false }

        var keys: Set<[UInt8]> = []
        keys.reserveCapacity(elements.count)
        // Uniqueness belongs to the generated representation: distinct Swift values may still
        // encode to the same schema value.
        return elements.allSatisfy { keys.insert($0.setElementKey).inserted }
    }
}
