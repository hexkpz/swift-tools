//
//  Created by Anton Spivak
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

#if canImport(FoundationEssentials) || canImport(Foundation)

extension URL: Generable {
    public static var generationSchema: GenerationSchema {
        get throws(Error) {
            try GenerationSchema.string().validating(GeneratedURLValidator())
        }
    }

    public init(from decoder: inout GenerationDecoder) throws {
        let string = try String(from: &decoder)
        guard let value = GeneratedURL.value(from: string) else {
            throw Error.invalidValue(expected: GeneratedURL.expected)
        }
        self = value
    }

    public func encode(to encoder: inout GenerationEncoder) throws {
        try absoluteString.encode(to: &encoder)
    }
}

public extension GenerationGuide where Value == URL {
    /// Sets the allowed generated URLs.
    static func anyOf(_ values: [URL]) -> Self {
        .init(.anyOf(values.map(\.absoluteString)))
    }

    /// Sets the required URL scheme.
    static func scheme(_ scheme: String) -> Self {
        .scheme(anyOf: [scheme])
    }

    /// Sets the allowed URL schemes.
    static func scheme(anyOf schemes: [String]) -> Self {
        .url(expected: GeneratedURL.expected(schemes: schemes), schemes: schemes)
    }

    /// Requires an HTTP or HTTPS URL.
    static var webURL: Self {
        .url(expected: "an HTTP or HTTPS URL with a host", schemes: ["http", "https"], host: true)
    }

    /// Requires a file URL.
    static var fileURL: Self {
        .scheme("file")
    }

    private static func url(expected: String, schemes: [String], host: Bool = false) -> Self {
        .validation(URLSchemesValidator(
            expected: expected,
            schemes: schemes,
            host: host,
        ))
    }
}

private struct GeneratedURLValidator: GenerationSchema.Validator {
    typealias Value = URL

    let expected = GeneratedURL.expected

    func matches(_ content: GeneratedContent) -> Bool {
        guard case let .string(value) = content else { return false }
        return GeneratedURL.value(from: value) != nil
    }
}

private struct URLSchemesValidator: GenerationSchema.Validator {
    // MARK: Lifecycle

    init(expected: String, schemes: [String], host: Bool) {
        self.expected = expected

        self.schemes = Set(schemes.lazy.map { $0.lowercased() })
        self.host = host
    }

    // MARK: Internal

    typealias Value = URL

    let expected: String

    let schemes: Set<String>
    let host: Bool

    func matches(_ content: GeneratedContent) -> Bool {
        guard case let .string(string) = content,
              let url = GeneratedURL.value(from: string),
              let scheme = url.scheme?.lowercased(),
              schemes.contains(scheme)
        else { return false }
        return !host || url.host != nil
    }
}

private enum GeneratedURL {
    static let expected = "a URL string"

    static func expected(schemes: [String]) -> String {
        let names = schemes.joined(separator: ", ")
        return "a URL with one of the following schemes: \(names)"
    }

    static func value(from string: String) -> URL? {
        guard let value = URL(string: string),
              value.absoluteString == string else { return nil }
        return value
    }
}

#endif
