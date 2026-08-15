//
//  Created by Anton Spivak
//

public extension Generable where Self: BinaryFloatingPoint {
    static var generationSchema: GenerationSchema {
        get throws(Error) { try .number() }
    }

    init(from decoder: inout GenerationDecoder) throws {
        self = try decoder.decode()
    }

    func encode(to encoder: inout GenerationEncoder) throws {
        try encoder.encode(self)
    }
}

public extension GenerationGuide where Value: BinaryFloatingPoint {
    /// Sets the minimum generated number.
    static func minimum(_ value: Value) -> Self {
        .init(.minimum(value))
    }

    /// Sets the maximum generated number.
    static func maximum(_ value: Value) -> Self {
        .init(.maximum(value))
    }

    /// Sets the generated number range.
    static func range(_ range: ClosedRange<Value>) -> Self {
        .init(.minimum(range.lowerBound), .maximum(range.upperBound))
    }
}

// MARK: - Float + Generable

extension Float: Generable {
    public static var generationSchema: GenerationSchema {
        get throws(Error) {
            try .number(constraints: [
                .minimum(-greatestFiniteMagnitude),
                .maximum(greatestFiniteMagnitude),
            ])
        }
    }
}

// MARK: - Double + Generable

extension Double: Generable {
    public static var generationSchema: GenerationSchema {
        get throws(Error) {
            try .number(constraints: [
                .minimum(-greatestFiniteMagnitude),
                .maximum(greatestFiniteMagnitude),
            ])
        }
    }
}
