//
//  Created by Anton Spivak
//

extension GeneratedContent: Codable {
    public init(from decoder: any Swift::Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = container.decodeGeneratedBinaryInteger() {
            // Preserve integer precision instead of eagerly decoding every JSON number as Double.
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            guard value.isFinite
            else { throw DecodingError.nonFiniteJSONNumber(in: container) }
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([Self].self) {
            self = .array(value)
        } else {
            let container = try decoder.container(keyedBy: Key.self)
            self = try .object(.init(container.allKeys.map { key in
                try .init(key.stringValue, container.decode(Self.self, forKey: key))
            }))
        }
    }

    public func encode(to encoder: any Swift::Encoder) throws {
        switch self {
        case .null:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        case let .boolean(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .integer(value):
            try value.encode(to: encoder)
        case let .number(value):
            guard value.isFinite
            else { throw EncodingError.nonFiniteJSONNumber(value, encoder.codingPath) }
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .string(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .array(value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case let .object(properties):
            guard properties.hasUniquePropertyNames else {
                throw EncodingError.duplicatePropertyNames(properties, encoder.codingPath)
            }

            var container = encoder.container(keyedBy: Key.self)
            for property in properties {
                try container.encode(property.value, forKey: Key(property.name))
            }
        }
    }

    private struct Key: CodingKey {
        // MARK: Lifecycle

        init(_ stringValue: String) {
            self.stringValue = stringValue
        }

        init?(stringValue: String) {
            self.init(stringValue)
        }

        init?(intValue _: Int) {
            nil
        }

        // MARK: Internal

        let stringValue: String

        var intValue: Int? { nil }
    }
}
