//
//  Created by Anton Spivak
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

// MARK: - Error

/// An error from a tool library.
public enum Error: Swift::Error, Sendable, Hashable {
    /// A tool has an empty name.
    case invalidName

    /// Two tools have the same name.
    case duplicateName(String)

    /// A tool declaration couldn't be created.
    case invalidDeclaration(name: String, reason: String)

    /// A tool output couldn't be encoded as ``GeneratedContent``.
    case invalidOutput(name: String, reason: String)
}

#if canImport(FoundationEssentials) || canImport(Foundation)

extension Error: LocalizedError {
    public var errorDescription: String? { description }
}

#endif

// MARK: CustomStringConvertible

extension Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidName:
            "A tool name can't be empty."
        case let .duplicateName(name):
            "A tool named \(String(describing: name)) is already in the library."
        case let .invalidDeclaration(name, reason):
            "Can't construct the declaration for tool \(String(describing: name)): \(reason)"
        case let .invalidOutput(name, reason):
            "Tool \(String(describing: name)) produced an invalid output: \(reason)"
        }
    }
}

// MARK: CustomDebugStringConvertible

extension Error: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .invalidName:
            "Tools::Error.invalidName"
        case let .duplicateName(name):
            "Tools::Error.duplicateName(\(String(reflecting: name)))"
        case let .invalidDeclaration(name, reason):
            "Tools::Error.invalidDeclaration(name: \(String(reflecting: name)), reason: \(String(reflecting: reason)))"
        case let .invalidOutput(name, reason):
            "Tools::Error.invalidOutput(name: \(String(reflecting: name)), reason: \(String(reflecting: reason)))"
        }
    }
}
