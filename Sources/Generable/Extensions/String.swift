//
//  Created by Anton Spivak
//

// MARK: - String + Generable

extension String: Generable {
    public static var generationSchema: GenerationSchema {
        get throws(Error) { try .string() }
    }

    public init(from decoder: inout GenerationDecoder) throws {
        self = try decoder.decode()
    }

    public func encode(to encoder: inout GenerationEncoder) throws {
        try encoder.encode(self)
    }
}

public extension GenerationGuide where Value == String {
    /// Sets the allowed generated strings.
    static func anyOf(_ values: [String]) -> Self {
        .init(.anyOf(values))
    }
}
