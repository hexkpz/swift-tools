//
//  Created by Anton Spivak
//

// MARK: - GenerationSchema.Constraint

public extension GenerationSchema {
    /// A JSON Schema constraint.
    struct Constraint: Sendable {
        // MARK: Public

        /// Allows only the given strings.
        ///
        /// - Parameter values: The allowed strings.
        public static func anyOf(_ values: [String]) -> Self {
            .init(keyword: .enumeration, value: .array(values.map(GeneratedContent.string)))
        }

        /// Sets an inclusive integer minimum.
        public static func minimum<Value: GeneratedBinaryInteger>(_ value: Value) -> Self {
            .init(keyword: .minimum, value: .integer(value))
        }

        /// Sets an inclusive number minimum.
        public static func minimum<Value: BinaryFloatingPoint>(_ value: Value) -> Self {
            .init(keyword: .minimum, value: .number(Double(value)))
        }

        /// Sets an inclusive integer maximum.
        public static func maximum<Value: GeneratedBinaryInteger>(_ value: Value) -> Self {
            .init(keyword: .maximum, value: .integer(value))
        }

        /// Sets an inclusive number maximum.
        public static func maximum<Value: BinaryFloatingPoint>(_ value: Value) -> Self {
            .init(keyword: .maximum, value: .number(Double(value)))
        }

        /// Sets an inclusive minimum element count.
        public static func minimum(count: Int) -> Self {
            .init(keyword: .minimumItems, value: .integer(count))
        }

        /// Sets an inclusive maximum element count.
        public static func maximum(count: Int) -> Self {
            .init(keyword: .maximumItems, value: .integer(count))
        }

        // MARK: Internal

        enum Keyword: String, Sendable, Hashable {
            case enumeration = "enum"

            case minimum
            case maximum

            case minimumItems = "minItems"
            case maximumItems = "maxItems"
        }

        let keyword: Keyword
        let value: GeneratedContent
    }
}

// MARK: - GenerationSchema.Constraint + CustomStringConvertible

extension GenerationSchema.Constraint: CustomStringConvertible {
    public var description: String {
        switch keyword {
        case .enumeration: "anyOf(\(_description))"
        case .minimum: "minimum(\(_description))"
        case .maximum: "maximum(\(_description))"
        case .minimumItems: "minimum(count: \(_description))"
        case .maximumItems: "maximum(count: \(_description))"
        }
    }

    private var _description: String {
        switch value {
        case let .integer(value):
            String(describing: value)
        case let .number(value):
            String(describing: value)
        case let .array(values):
            String(describing: values.compactMap { value -> String? in
                guard case let .string(value) = value else { return nil }
                return value
            })
        default:
            String(describing: value)
        }
    }
}

// MARK: - GenerationSchema.Constraint + CustomDebugStringConvertible

extension GenerationSchema.Constraint: CustomDebugStringConvertible {
    // swiftformat:disable wrap wrapArguments
    public var debugDescription: String {
        "GenerationSchema.Constraint(keyword: \(String(reflecting: keyword.rawValue)), value: \(String(reflecting: value)))"
    }
    // swiftformat:enable wrap wrapArguments
}
