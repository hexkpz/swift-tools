//
//  Created by Anton Spivak
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

#if canImport(FoundationEssentials) || canImport(Foundation)

public extension GeneratedContent {
    /// Creates generated content from JSON.
    ///
    /// Returns `nil` if the string isn't valid JSON.
    init?(_ description: String) {
        do { self = try .init(Data(description.utf8)) }
        catch { return nil }
    }
}

extension GeneratedContent: CustomStringConvertible {
    /// The canonical JSON representation, or a diagnostic if the value isn't representable as JSON.
    public var description: String {
        do {
            return try String(decoding: data(), as: UTF8.self)
        } catch {
            return "<invalid content: \(String(describing: error))>"
        }
    }
}

public extension GeneratedContent {
    /// Creates generated content from JSON data.
    ///
    /// - Parameter data: The JSON data to decode.
    /// - Throws: An error if the data doesn't contain a supported JSON value.
    init(_ data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
    }
}

public extension GeneratedContent {
    /// Returns the canonical JSON data.
    ///
    /// Object keys are sorted. Nonfinite numbers and duplicate keys can't be encoded.
    ///
    /// - Throws: An error if the value can't be encoded as JSON.
    func data() throws(Error) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        do {
            return try encoder.encode(self)
        } catch let error as Error {
            throw error
        } catch {
            throw .unrepresentableValue("a JSON value (\(CodingFailureReason(from: error)))")
        }
    }
}

#endif
