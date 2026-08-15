//
//  Created by Anton Spivak
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

import Testing
import Generable

#if canImport(FoundationEssentials) || canImport(Foundation)

private enum URLGuideExample: CaseIterable, Sendable, CustomTestStringConvertible {
    case webRejectsFile
    case webRequiresHost
    case fileRejectsWeb
    case customRejectsHTTPS

    // MARK: Internal

    var testDescription: String {
        switch self {
        case .webRejectsFile: "web URL rejects file URL"
        case .webRequiresHost: "web URL requires a host"
        case .fileRejectsWeb: "file URL rejects web URL"
        case .customRejectsHTTPS: "custom scheme rejects HTTPS"
        }
    }

    var guide: GenerationGuide<URL> {
        switch self {
        case .webRejectsFile, .webRequiresHost: .webURL
        case .fileRejectsWeb: .fileURL
        case .customRejectsHTTPS: .scheme(anyOf: ["ws", "wss"])
        }
    }

    var valid: String {
        switch self {
        case .webRejectsFile, .webRequiresHost: "https://example.com/path"
        case .fileRejectsWeb: URL(fileURLWithPath: "/tmp/generated.txt").absoluteString
        case .customRejectsHTTPS: "wss://example.com/socket"
        }
    }

    var invalid: String {
        switch self {
        case .webRejectsFile: "file:///tmp/generated.txt"
        case .webRequiresHost: "https:path"
        case .fileRejectsWeb: "https://example.com/path"
        case .customRejectsHTTPS: "https://example.com/socket"
        }
    }
}

@Test(arguments: ["", "https://example.com/a b"])
func `URL decoding rejects empty and non-canonical strings`(_ invalid: String) throws {
    let schema = try URL.generationSchema

    #expect(throws: Generable::Error.self) {
        _ = try GeneratedContent.string(invalid).decode(URL.self)
    }

    #expect(throws: Generable::Error.self) {
        try schema.validate(.string(invalid))
    }
}

@Test(arguments: URLGuideExample.allCases)
private func `URL guides enforce their local semantics`(_ example: URLGuideExample) throws {
    let schema = try GenerationSchema.Property(
        name: "url",
        type: URL.self,
        guides: [example.guide],
    ).schema

    try schema.validate(.string(example.valid))
    #expect(throws: Generable::Error.self) {
        try schema.validate(.string(example.invalid))
    }
}

#endif
