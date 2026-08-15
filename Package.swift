// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Tools",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .macCatalyst(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "Tools", targets: ["Tools"]),
        .library(name: "Generable", targets: ["Generable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log", from: "1.12.1"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "603.0.0"),
    ],
    targets: [
        .target(
            name: "Tools",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .byName(name: "Generable"),
            ],
        ),
        .testTarget(
            name: "ToolsTests",
            dependencies: [
                .byName(name: "Tools"),
            ],
            path: "Tests/Tools",
        ),

        .target(
            name: "Generable",
            dependencies: [
                .byName(name: "GenerableMacros"),
            ],
        ),
        .testTarget(
            name: "GenerableTests",
            dependencies: [
                .byName(name: "Generable"),
            ],
            path: "Tests/Generable",
        ),

        .macro(
            name: "GenerableMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ],
        ),
        .testTarget(
            name: "GenerableMacrosTests",
            dependencies: [
                .byName(name: "GenerableMacros"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ],
            path: "Tests/GenerableMacros",
        ),
    ],
    swiftLanguageModes: [.v6],
)
