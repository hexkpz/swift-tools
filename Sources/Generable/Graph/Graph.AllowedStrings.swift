//
//  Created by Anton Spivak
//

// MARK: - Graph.AllowedStrings

extension Graph {
    struct AllowedStrings: Sendable {
        // MARK: Lifecycle

        init(_ constraints: [GenerationSchema.Constraint]) throws(Error) {
            var values: Set<String>?
            for constraint in constraints {
                guard constraint.keyword == .enumeration,
                      case let .array(contents) = constraint.value
                else { throw .unsupported(constraint, for: "a string schema") }

                var choices = Set<String>(minimumCapacity: contents.count)
                for content in contents {
                    guard case let .string(value) = content
                    else { throw .unsupported(constraint, for: "a string schema") }
                    choices.insert(value)
                }

                if values == nil {
                    values = choices
                } else {
                    values?.formIntersection(choices)
                }
            }

            if let values, values.isEmpty {
                throw Error.constraintViolation("String guides must allow at least one value.")
            }

            self.init(values)
        }

        // swiftformat:disable:next spaceAroundBrackets
        init(enumeration values: consuming [String]) throws(Error) {
            guard !values.isEmpty
            else { throw .constraintViolation("An enumeration must contain at least one value.") }

            var values = consume values
            values.sort()

            for index in values.indices.dropFirst() {
                let previous = values.index(before: index)
                guard values[previous] != values[index]
                else { throw .constraintViolation("Enumeration values must be unique.") }
            }

            self.sortedValues = values
        }

        private init(_ values: Set<String>?) {
            self.sortedValues = values?.sorted()
        }

        // MARK: Internal

        var generatedProperties: [(GenerationSchema.Constraint.Keyword, GeneratedContent)] {
            sortedValues.map { [(.enumeration, .array($0.map(GeneratedContent.string)))] } ?? []
        }

        // MARK: Private

        private let sortedValues: [String]?
    }
}

extension Graph.AllowedStrings {
    @inline(__always)
    func error(for value: String) -> Error? {
        guard let sortedValues else { return nil }

        let lowerBound = sortedValues.lowerBound(for: value, by: \.self)
        guard lowerBound >= sortedValues.endIndex || sortedValues[lowerBound] != value
        else { return nil }

        return .constraintViolation("Value must be one of \(sortedValues).")
    }
}
