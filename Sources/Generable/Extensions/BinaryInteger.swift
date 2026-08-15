//
//  Created by Anton Spivak
//

public extension Generable where Self: GeneratedBinaryInteger {
    static var generationSchema: GenerationSchema {
        get throws(Error) { try .integer() }
    }

    init(from decoder: inout GenerationDecoder) throws {
        self = try decoder.decode()
    }

    func encode(to encoder: inout GenerationEncoder) throws {
        try encoder.encode(self)
    }
}

public extension Generable where Self: FixedWidthInteger & GeneratedBinaryInteger {
    static var generationSchema: GenerationSchema {
        get throws(Error) {
            try .integer(constraints: [.minimum(Self.min), .maximum(Self.max)])
        }
    }
}

public extension GenerationGuide where Value: GeneratedBinaryInteger {
    /// Sets the minimum generated integer.
    static func minimum(_ value: Value) -> Self {
        .init(.minimum(value))
    }

    /// Sets the maximum generated integer.
    static func maximum(_ value: Value) -> Self {
        .init(.maximum(value))
    }

    /// Sets the generated integer range.
    static func range(_ range: ClosedRange<Value>) -> Self {
        .init(.minimum(range.lowerBound), .maximum(range.upperBound))
    }
}

// MARK: - Int + GeneratedBinaryInteger, Generable

extension Int: GeneratedBinaryInteger, Generable {}

// MARK: - Int8 + GeneratedBinaryInteger, Generable

extension Int8: GeneratedBinaryInteger, Generable {}

// MARK: - Int16 + GeneratedBinaryInteger, Generable

extension Int16: GeneratedBinaryInteger, Generable {}

// MARK: - Int32 + GeneratedBinaryInteger, Generable

extension Int32: GeneratedBinaryInteger, Generable {}

// MARK: - Int64 + GeneratedBinaryInteger, Generable

extension Int64: GeneratedBinaryInteger, Generable {}

// MARK: - Int128 + GeneratedBinaryInteger, Generable

@available(macOS 15.0, iOS 18.0, macCatalyst 18.0, *)
extension Int128: GeneratedBinaryInteger, Generable {}

// MARK: - UInt + GeneratedBinaryInteger, Generable

extension UInt: GeneratedBinaryInteger, Generable {}

// MARK: - UInt8 + GeneratedBinaryInteger, Generable

extension UInt8: GeneratedBinaryInteger, Generable {}

// MARK: - UInt16 + GeneratedBinaryInteger, Generable

extension UInt16: GeneratedBinaryInteger, Generable {}

// MARK: - UInt32 + GeneratedBinaryInteger, Generable

extension UInt32: GeneratedBinaryInteger, Generable {}

// MARK: - UInt64 + GeneratedBinaryInteger, Generable

extension UInt64: GeneratedBinaryInteger, Generable {}

// MARK: - UInt128 + GeneratedBinaryInteger, Generable

@available(macOS 15.0, iOS 18.0, macCatalyst 18.0, *)
extension UInt128: GeneratedBinaryInteger, Generable {}

@inline(__always)
func compareBinaryIntegers<Lhs: BinaryInteger, Rhs: BinaryInteger>(_ lhs: Lhs, _ rhs: Rhs) -> Int {
    if lhs == rhs { return 0 }
    return lhs < rhs ? -1 : 1
}

@inline(__always)
func compareBinaryInteger<Value: BinaryInteger>(_ integer: Value, to number: Double) -> Int? {
    guard number.isFinite else { return nil }

    // Convert only the integral part so integers outside Double's exact range can still be
    // compared without first rounding the integer itself.
    let integral = number.rounded(.towardZero)
    guard let converted = Value(exactly: integral) else { return number.sign == .minus ? 1 : -1 }

    let comparison = compareBinaryIntegers(integer, converted)
    if comparison != 0 || number == integral { return comparison }

    // The integral parts match, so the discarded fractional part decides the ordering.
    return number.sign == .minus ? 1 : -1
}
