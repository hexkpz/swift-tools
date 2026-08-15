//
//  Created by Anton Spivak
//

import Testing
import Generable

// MARK: - DuplicatePropertyEncoding

private struct DuplicatePropertyEncoding: Generable {
    // MARK: Lifecycle

    init(value: Int) {
        self.value = value
    }

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
        try encoder.encode(value, forProperty: "value")
    }
}

// MARK: - MissingPropertyEncoding

private struct MissingPropertyEncoding: Generable {
    // MARK: Lifecycle

    init() {}

    init(from decoder: inout GenerationDecoder) throws {
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

    func encode(to _: inout GenerationEncoder) throws {}
}

// MARK: - UnexpectedPropertyEncoding

private struct UnexpectedPropertyEncoding: Generable {
    // MARK: Lifecycle

    init(value: Int) {
        self.value = value
    }

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
        try encoder.encode(value, forProperty: "unexpected")
    }
}

// MARK: - DuplicateValueEncoding

private struct DuplicateValueEncoding: Generable {
    // MARK: Lifecycle

    init(value: Int) {
        self.value = value
    }

    init(from decoder: inout GenerationDecoder) throws {
        self.value = try Int(from: &decoder)
    }

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) { try .integer() }
    }

    let value: Int

    func encode(to encoder: inout GenerationEncoder) throws {
        try value.encode(to: &encoder)
        try value.encode(to: &encoder)
    }
}

@Test
func `encoder rejects duplicate property writes`() {
    #expect {
        _ = try generatedContentEncoder.encode(DuplicatePropertyEncoding(value: 1))
    } throws: { GenerableErrorKind.constraintViolation.matches($0) }
}

@Test
func `encoder reports a missing required property`() {
    #expect {
        _ = try generatedContentEncoder.encode(MissingPropertyEncoding())
    } throws: { GenerableErrorKind.missingProperty.matches($0) }
}

@Test
func `encoder rejects properties outside the declared schema`() {
    #expect {
        _ = try generatedContentEncoder.encode(UnexpectedPropertyEncoding(value: 1))
    } throws: { GenerableErrorKind.unexpectedProperty.matches($0) }
}

@Test
func `encoder rejects writing a root value more than once`() {
    #expect {
        _ = try generatedContentEncoder.encode(DuplicateValueEncoding(value: 1))
    } throws: { GenerableErrorKind.invalidValue.matches($0) }
}
