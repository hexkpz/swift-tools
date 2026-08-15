//
//  Created by Anton Spivak
//

// MARK: - Graph.CountBounds

extension Graph {
    struct CountBounds: Sendable {
        // MARK: Lifecycle

        init(_ constraints: [GenerationSchema.Constraint]) throws(Error) {
            for constraint in constraints {
                guard case let .integer(contentValue) = constraint.value,
                      let value = Int(exactly: contentValue)
                else { throw .unsupported(constraint, for: "an array schema") }

                switch constraint.keyword {
                case .minimumItems:
                    guard value >= 0
                    else { throw Error.constraintViolation("Minimum count cannot be negative.") }

                    self.minimum = Swift.max(minimum ?? value, value)
                case .maximumItems:
                    guard value >= 0
                    else { throw Error.constraintViolation("Maximum count cannot be negative.") }

                    self.maximum = Swift.min(maximum ?? value, value)
                default:
                    throw .unsupported(constraint, for: "an array schema")
                }
            }

            if let minimum, let maximum, minimum > maximum {
                throw Error.constraintViolation("Minimum count cannot exceed maximum count.")
            }
        }

        // MARK: Internal

        var generatedProperties: [(GenerationSchema.Constraint.Keyword, GeneratedContent)] {
            [
                minimum.map { (.minimumItems, .integer($0)) },
                maximum.map { (.maximumItems, .integer($0)) },
            ].compactMap(\.self)
        }

        // MARK: Private

        private var minimum: Int?
        private var maximum: Int?
    }
}

extension Graph.CountBounds {
    @inline(__always)
    func error(for value: Int) -> Error? {
        if let minimum, value < minimum {
            return .constraintViolation("Collection must contain at least \(minimum) items.")
        }
        if let maximum, value > maximum {
            return .constraintViolation("Collection must contain at most \(maximum) items.")
        }
        return nil
    }
}
