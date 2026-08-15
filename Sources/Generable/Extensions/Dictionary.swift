//
//  Created by Anton Spivak
//

extension Dictionary: Generable where Key == String, Value: Generable {
    public static var generationSchema: GenerationSchema {
        get throws(Error) { try .dictionary(Value.generationSchema) }
    }

    public init(from decoder: inout GenerationDecoder) throws {
        self = try decoder.decode()
    }

    public func encode(to encoder: inout GenerationEncoder) throws {
        try encoder.encode(self)
    }
}
