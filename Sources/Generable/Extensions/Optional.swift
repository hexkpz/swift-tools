//
//  Created by Anton Spivak
//

extension Optional: Generable where Wrapped: Generable {
    public static var generationSchema: GenerationSchema {
        get throws(Error) { try .optional(Wrapped.generationSchema) }
    }

    public init(from decoder: inout GenerationDecoder) throws {
        self = try decoder.decode()
    }

    public func encode(to encoder: inout GenerationEncoder) throws {
        try encoder.encode(self)
    }
}
