//
//  Created by Anton Spivak
//

import Testing
import Generable

// MARK: - CollidingValue

private struct CollidingValue: Generable, Hashable {
    // MARK: Lifecycle

    init(_ identity: Int) {
        self.identity = identity
    }

    init(from decoder: inout GenerationDecoder) throws {
        self.identity = try Int(from: &decoder)
    }

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) { try .integer() }
    }

    let identity: Int

    func encode(to encoder: inout GenerationEncoder) throws {
        try 0.encode(to: &encoder)
    }
}

@Test
func `set schemas and decoding reject duplicate generated elements`() throws {
    let content = GeneratedContent.array([.integer(1), .integer(1)])
    let schema = try Set<Int>.generationSchema

    #expect {
        try schema.validate(content)
    } throws: { GenerableErrorKind.invalidValue.matches($0) }

    #expect {
        _ = try content.decode(Set<Int>.self)
    } throws: { GenerableErrorKind.invalidValue.matches($0) }
}

@Test
func `set encoding has a canonical element order`() throws {
    let permutations = [
        [1, 2, 3],
        [3, 1, 2],
        [2, 3, 1],
    ]

    for permutation in permutations {
        let content = try GeneratedContent(Set(permutation))
        guard case let .array(elements) = content else {
            Issue.record("Expected array content.")
            continue
        }

        #expect(elements.compactMap { integerValue($0, as: Int.self) } == [1, 2, 3])
    }
}

@Test
func `set encoding rejects distinct values with identical generated content`() {
    let values: Set<CollidingValue> = [.init(1), .init(2)]

    #expect {
        _ = try GeneratedContent(values)
    } throws: { GenerableErrorKind.invalidValue.matches($0) }
}
