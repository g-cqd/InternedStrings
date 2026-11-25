// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "InternedStrings",
    platforms: [
        .iOS(.v18), .macOS(.v15), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2), .macCatalyst(.v18),
    ],
    products: [
        .library(name: "InternedStrings", targets: ["InternedStringsCompatibility"])
    ],
    dependencies: [
        .package(url: "https://github.com/Aemi-Studio/aemi.git", revision: "340c49040faa49313d5632003d8224d9d0084fb0")
    ],
    targets: [
        .target(
            name: "InternedStringsCompatibility",
            dependencies: [.product(name: "InternedStrings", package: "aemi")]
        ),
        .testTarget(name: "InternedStringsTests", dependencies: ["InternedStringsCompatibility"]),
    ],
    swiftLanguageModes: [.v6]
)
