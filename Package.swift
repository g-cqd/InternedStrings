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
        .package(url: "https://github.com/Aemi-Studio/aemi.git", revision: "9e38d1bee60d5d65acffef4538c671b49860c6af")
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
