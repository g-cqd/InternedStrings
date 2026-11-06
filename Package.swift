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
        .package(url: "https://github.com/Aemi-Studio/aemi.git", revision: "409c647a91736065ac53c1877abe2cf4840f7617")
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
