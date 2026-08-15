//
//  Created by Anton Spivak
//

// MARK: - ExpansionSource

struct ExpansionSource: ExpressibleByStringInterpolation {
    // MARK: Lifecycle

    init(raw text: String) {
        self.text = text
    }

    init(stringLiteral value: String) {
        self.init(raw: value)
    }

    init(stringInterpolation: StringInterpolation) {
        self.init(raw: stringInterpolation.text)
    }

    // MARK: Internal

    let text: String
}

// MARK: ExpansionSource.StringInterpolation

extension ExpansionSource {
    struct StringInterpolation: StringInterpolationProtocol {
        // MARK: Lifecycle

        init(literalCapacity: Int, interpolationCount: Int) {
            text.reserveCapacity(literalCapacity + interpolationCount * 16)
        }

        // MARK: Internal

        private(set) var text = ""
    }
}

extension ExpansionSource.StringInterpolation {
    mutating func appendLiteral(_ literal: String) {
        text.append(contentsOf: literal)
    }

    mutating func appendInterpolation(raw value: String) {
        text.append(contentsOf: value)
    }

    mutating func appendInterpolation(_ value: ExpansionSource) {
        appendNested(value.text)
    }
}

private extension ExpansionSource.StringInterpolation {
    mutating func appendNested(_ value: String) {
        // Nested fragments describe relative layout and inherit their interpolation site's indent.
        let lineStart = text.lastIndex(of: "\n").map(text.index(after:)) ?? text.startIndex
        let inheritedIndentation = text[lineStart...].prefix { $0 == " " || $0 == "\t" }
        var remainder = value[...]

        while let newline = remainder.firstIndex(of: "\n") {
            text.append(contentsOf: remainder[...newline])
            remainder = remainder[remainder.index(after: newline)...]

            if !remainder.isEmpty, remainder.first != "\n" {
                text.append(contentsOf: inheritedIndentation)
            }
        }

        text.append(contentsOf: remainder)
    }
}

extension Sequence where Element == ExpansionSource {
    var lines: ExpansionSource {
        .init(raw: lazy.map(\.text).joined(separator: "\n"))
    }

    var commaSeparatedLines: ExpansionSource {
        .init(raw: lazy.map(\.text).joined(separator: ",\n"))
    }
}
