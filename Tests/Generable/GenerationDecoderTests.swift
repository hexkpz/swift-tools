//
//  Created by Anton Spivak
//

import Testing
import Generable

// MARK: - UnconsumedEnumeration

private struct UnconsumedEnumeration: Generable {
    // MARK: Lifecycle

    init(from _: inout GenerationDecoder) throws {}

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) {
            try .oneOf([
                .structure(properties: [
                    .init(name: "none", schema: .null),
                ]),
            ])
        }
    }

    func encode(to _: inout GenerationEncoder) throws {}
}

// MARK: - RequiredPropertyDecoding

private struct RequiredPropertyDecoding: Generable {
    // MARK: Lifecycle

    init(from decoder: inout GenerationDecoder) throws {
        self.value = try decoder.decode(Int.self, forProperty: "value")
    }

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) {
            try .structure(properties: [
                .init(name: "value", type: Int.self),
            ])
        }
    }

    let value: Int

    func encode(to encoder: inout GenerationEncoder) throws {
        try encoder.encode(value, forProperty: "value")
    }
}

// MARK: - DuplicatePropertyDecoding

private struct DuplicatePropertyDecoding: Generable {
    // MARK: Lifecycle

    init(from decoder: inout GenerationDecoder) throws {
        self.value = try decoder.decode(Int.self, forProperty: "value")
        _ = try decoder.decode(Int.self, forProperty: "value")
    }

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) {
            try .structure(properties: [
                .init(name: "value", type: Int.self),
            ])
        }
    }

    let value: Int

    func encode(to encoder: inout GenerationEncoder) throws {
        try encoder.encode(value, forProperty: "value")
    }
}

@Test
func `decoder rejects unconsumed enumeration payloads`() {
    #expect {
        _ = try GeneratedContent(properties: [("none", .null)])
            .decode(UnconsumedEnumeration.self)
    } throws: { GenerableErrorKind.invalidValue.matches($0) }
}

@Test
func `decoder reports a missing required property`() {
    #expect {
        _ = try GeneratedContent(properties: []).decode(RequiredPropertyDecoding.self)
    } throws: { GenerableErrorKind.missingProperty.matches($0) }
}

@Test
func `decoder rejects reading a property more than once`() {
    #expect {
        _ = try GeneratedContent(properties: [("value", .integer(1))])
            .decode(DuplicatePropertyDecoding.self)
    } throws: { GenerableErrorKind.constraintViolation.matches($0) }
}
