//
//  Created by Anton Spivak
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

// MARK: - Failure

/// An error that can be returned to the model.
public struct Failure: Swift::Error, Sendable, Hashable {
    // MARK: Lifecycle

    /// Creates an error with a message for the model.
    ///
    /// - Parameter message: The message for the model.
    public init(_ message: String) {
        self.message = message
    }

    // MARK: Public

    /// The message for the model.
    public let message: String
}

#if canImport(FoundationEssentials) || canImport(Foundation)

extension Failure: LocalizedError {
    public var errorDescription: String? { message }
}

#endif

// MARK: ExpressibleByStringLiteral

extension Failure: ExpressibleByStringLiteral {
    @inlinable @inline(__always)
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

// MARK: CustomStringConvertible

extension Failure: CustomStringConvertible {
    public var description: String { message }
}

// MARK: CustomDebugStringConvertible

extension Failure: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Tools::Failure(\(String(reflecting: message)))"
    }
}
