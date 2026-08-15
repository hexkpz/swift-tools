//
//  Created by Anton Spivak
//

func CodingFailureReason(from error: any Swift.Error) -> String {
    switch error {
    case let DecodingError.dataCorrupted(context):
        context.description
    case let DecodingError.keyNotFound(key, context):
        "missing key \(key.stringValue) at \(context.path)"
    case let DecodingError.typeMismatch(_, context):
        "type mismatch at \(context.path): \(context.debugDescription)"
    case let DecodingError.valueNotFound(_, context):
        "missing value at \(context.path): \(context.debugDescription)"
    case let EncodingError.invalidValue(_, context):
        "invalid value at \(context.path): \(context.debugDescription)"
    default:
        String(describing: error)
    }
}

private let nonFiniteJSONNumberMessage = "JSON numbers must be finite."

extension DecodingError {
    static func nonFiniteJSONNumber(
        in container: any SingleValueDecodingContainer,
    ) -> Self {
        .dataCorruptedError(in: container, debugDescription: nonFiniteJSONNumberMessage)
    }
}

extension EncodingError {
    static func nonFiniteJSONNumber(
        _ value: Double,
        _ codingPath: [any CodingKey],
    ) -> Self {
        .invalidValue(value, .init(
            codingPath: codingPath,
            debugDescription: nonFiniteJSONNumberMessage,
        ))
    }
}

extension EncodingError {
    static func duplicatePropertyNames(
        _ properties: GeneratedContent.Object,
        _ codingPath: [any CodingKey],
    ) -> Self {
        .invalidValue(properties, .init(
            codingPath: codingPath,
            debugDescription: "Object property names must be unique.",
        ))
    }
}

extension SingleValueDecodingContainer {
    func decodeGeneratedBinaryInteger() -> (any GeneratedBinaryInteger)? {
        if #available(macOS 15, iOS 18, macCatalyst 18, tvOS 18, watchOS 11, visionOS 2, *) {
            decodeInteger(Int128.self) ?? decodeInteger(UInt128.self)
        } else {
            decodeInteger(Int64.self) ?? decodeInteger(UInt64.self)
        }
    }

    private func decodeInteger<Value: GeneratedBinaryInteger & Decodable>(
        _ type: Value.Type,
    ) -> Value? {
        try? decode(type)
    }
}

private extension DecodingError.Context {
    var path: String { codingPath.path }
    var description: String { "\(debugDescription) at \(path)" }
}

private extension EncodingError.Context {
    var path: String { codingPath.path }
}

private extension [any CodingKey] {
    var path: String {
        reduce(into: "$") { path, key in
            if let index = key.intValue { path += "[\(index)]" }
            else { path += ".\(key.stringValue)" }
        }
    }
}
