//
//  Created by Anton Spivak
//

// MARK: - Graph.NumericBounds

extension Graph {
    struct NumericBounds: Sendable {
        // MARK: Lifecycle

        init(_ constraints: [GenerationSchema.Constraint]) throws(Error) {
            for constraint in constraints {
                guard let bound = Bound(constraint.keyword) else {
                    throw .unsupported(constraint, for: "a numeric schema")
                }

                let value = constraint.value.normalizedNumber
                guard value.isFiniteNumber
                else { throw .boundsMustBeFiniteNumbers() }

                switch bound {
                case .minimum:
                    self.minimum = try Self.preferred(value, over: minimum, for: bound)
                case .maximum:
                    self.maximum = try Self.preferred(value, over: maximum, for: bound)
                }
            }

            if let minimum, let maximum, try Self.compare(minimum, maximum) > 0 {
                throw Error.constraintViolation("Minimum value cannot exceed maximum value.")
            }
        }

        // MARK: Internal

        var generatedProperties: [(GenerationSchema.Constraint.Keyword, GeneratedContent)] {
            [
                minimum.map { (.minimum, $0) },
                maximum.map { (.maximum, $0) },
            ].compactMap(\.self)
        }

        // MARK: Private

        private var minimum: GeneratedContent?
        private var maximum: GeneratedContent?

        private static func preferred(
            _ candidate: GeneratedContent,
            over current: GeneratedContent?,
            for bound: Bound,
        ) throws(Error) -> GeneratedContent {
            guard let current else { return candidate }

            let comparison = try compare(candidate, current)
            if bound.prefers(comparison) ||
                comparison == 0 && candidate.hasPreferredRepresentation(over: current)
            {
                return candidate
            }

            return current
        }

        private static func compare(
            _ lhs: GeneratedContent,
            _ rhs: GeneratedContent,
        ) throws(Error) -> Int {
            guard let comparison = lhs.compareNumber(to: rhs)
            else { throw .boundsMustBeFiniteNumbers() }
            return comparison
        }
    }
}

// MARK: - Graph.NumericBounds.Bound

private extension Graph.NumericBounds {
    private enum Bound {
        case minimum
        case maximum

        // MARK: Lifecycle

        init?(_ keyword: GenerationSchema.Constraint.Keyword) {
            switch keyword {
            case .minimum: self = .minimum
            case .maximum: self = .maximum
            default: return nil
            }
        }

        // MARK: Internal

        func prefers(_ comparison: Int) -> Bool {
            switch self {
            case .minimum: comparison > 0
            case .maximum: comparison < 0
            }
        }
    }
}

extension Graph.NumericBounds {
    @inline(__always)
    func error(for value: Double) -> Error? {
        guard value.isFinite else { return .invalidValue(expected: "a finite number") }
        if let minimum {
            guard let comparison = Self.compare(value, minimum), comparison >= 0 else {
                return .constraintViolation(
                    "Value must be at least \(minimum.numericDescription).",
                )
            }
        }
        if let maximum {
            guard let comparison = Self.compare(value, maximum), comparison <= 0 else {
                return .constraintViolation(
                    "Value must be at most \(maximum.numericDescription).",
                )
            }
        }
        return nil
    }

    @inline(__always)
    func error(for value: any GeneratedBinaryInteger) -> Error? {
        if let minimum {
            guard let comparison = Self.compare(value, minimum), comparison >= 0 else {
                return .constraintViolation(
                    "Value must be at least \(minimum.numericDescription).",
                )
            }
        }
        if let maximum {
            guard let comparison = Self.compare(value, maximum), comparison <= 0 else {
                return .constraintViolation(
                    "Value must be at most \(maximum.numericDescription).",
                )
            }
        }
        return nil
    }
}

private extension Graph.NumericBounds {
    @inline(__always)
    static func compare(
        _ lhs: Double,
        _ rhs: GeneratedContent,
    ) -> Int? {
        switch rhs {
        case let .integer(rhs): compareBinaryInteger(rhs, to: lhs).map(-)
        case let .number(rhs) where lhs.isFinite && rhs.isFinite:
            if lhs == rhs { 0 }
            else { lhs < rhs ? -1 : 1 }
        default: nil
        }
    }

    @inline(__always)
    static func compare(
        _ lhs: any GeneratedBinaryInteger,
        _ rhs: GeneratedContent,
    ) -> Int? {
        switch rhs {
        case let .integer(rhs): compareBinaryIntegers(lhs, rhs)
        case let .number(rhs): compareBinaryInteger(lhs, to: rhs)
        default: nil
        }
    }
}

private extension Error {
    static func boundsMustBeFiniteNumbers() -> Self {
        .constraintViolation("Numeric bounds must be finite numbers.")
    }
}

private extension GeneratedContent {
    var normalizedNumber: Self {
        if case let .number(value) = self, value == 0 { return .number(0) }
        return self
    }

    var isFiniteNumber: Bool {
        switch self {
        case .integer: true
        case let .number(value): value.isFinite
        default: false
        }
    }

    var numericDescription: String {
        switch self {
        case let .integer(value): String(describing: value)
        case let .number(value): String(describing: value)
        default: preconditionFailure("numericDescription requires numeric generated content.")
        }
    }

    func hasPreferredRepresentation(over other: Self) -> Bool {
        if case .integer = self, case .number = other { return true }
        return false
    }

    func compareNumber(to other: Self) -> Int? {
        switch (self, other) {
        case let (.integer(lhs), .integer(rhs)):
            compareBinaryIntegers(lhs, rhs)
        case let (.integer(lhs), .number(rhs)):
            compareBinaryInteger(lhs, to: rhs)
        case let (.number(lhs), .integer(rhs)):
            compareBinaryInteger(rhs, to: lhs).map(-)
        case let (.number(lhs), .number(rhs)) where lhs.isFinite && rhs.isFinite:
            if lhs == rhs { 0 }
            else { lhs < rhs ? -1 : 1 }
        default:
            nil
        }
    }
}
