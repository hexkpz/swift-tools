//
//  Created by Anton Spivak
//

import Testing
import Generable

// MARK: - RejectingValidator

private struct RejectingValidator<Value: Generable>: GenerationSchema.Validator {
    let expected = "a rejected value"

    func matches(_: GeneratedContent) -> Bool {
        false
    }
}

// MARK: - InnerValidatedString

private struct InnerValidatedString: Generable {
    // MARK: Lifecycle

    init(_ value: String) {
        self.value = value
    }

    init(from decoder: inout GenerationDecoder) throws {
        self.value = try String(from: &decoder)
    }

    // MARK: Internal

    static var generationSchema: GenerationSchema {
        get throws(Generable::Error) {
            try .definition(
                of: Self.self,
                name: String(reflecting: Self.self),
            ) { () throws(Generable::Error) in
                try GenerationSchema.string().validating(
                    RejectingValidator<Self>(),
                )
            }
        }
    }

    let value: String

    func encode(to encoder: inout GenerationEncoder) throws {
        try value.encode(to: &encoder)
    }
}

// MARK: - OuterValidatedValue

@Generable
private struct OuterValidatedValue {
    var value: InnerValidatedString
}

@Test
func `nested validation is consistent across schema decoding and encoding`() {
    let content = GeneratedContent(properties: [("value", .string("value"))])
    let value = OuterValidatedValue(value: .init("value"))

    #expect {
        try OuterValidatedValue.generationSchema.validate(content)
    } throws: { GenerableErrorKind.invalidValue.matches($0) }

    #expect {
        _ = try generatedContentDecoder.decode(OuterValidatedValue.self, from: content)
    } throws: { GenerableErrorKind.invalidValue.matches($0) }

    #expect {
        _ = try generatedContentEncoder.encode(value)
    } throws: { GenerableErrorKind.invalidValue.matches($0) }
}

@Test
func `supplied schemas validate root decoding and encoding`() throws {
    let schema = try String.generationSchema.validating(RejectingValidator<String>())

    #expect {
        _ = try generatedContentDecoder.decode(String.self, from: .string("value"), using: schema)
    } throws: { GenerableErrorKind.invalidValue.matches($0) }

    #expect {
        _ = try generatedContentEncoder.encode("value", using: schema)
    } throws: { GenerableErrorKind.invalidValue.matches($0) }
}
