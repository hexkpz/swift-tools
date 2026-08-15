//
//  Created by Anton Spivak
//

extension Never: Generable {
    public static var generationSchema: GenerationSchema {
        get throws(Error) { try .never }
    }

    public init(from decoder: inout GenerationDecoder) throws {
        try decoder.decode(Never.self)
    }

    public func encode(to encoder: inout GenerationEncoder) throws {
        switch self {}
    }
}
