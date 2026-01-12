// swift-tools-version: 6.2
import CompilerPluginSupport
import PackageDescription

private let package = Package(
    name: "InternedStrings",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "InternedStrings",
            targets: [
                "InternedStrings"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0")
    ],
    targets: [
        .macro(
            name: "InternedStringsMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "InternedStrings",
            dependencies: [
                "InternedStringsMacros"
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "InternedStringsTests",
            dependencies: [
                "InternedStrings",
                "InternedStringsMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: swiftSettings
        ),
    ]
)

private let swiftSettings: [SwiftSetting] = [
    .strictMemorySafety(),
    .enableExperimentalFeature("StrictConcurrency"),
    .swiftLanguageMode(.version("6.2")),
]
