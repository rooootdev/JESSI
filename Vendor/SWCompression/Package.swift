// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SWCompression",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v11),
        .tvOS(.v11),
        .watchOS(.v4),
        // TODO: Enable after upgrading to Swift 5.9.
        // .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SWCompression",
            targets: ["SWCompression"]),
    ],
    dependencies: [
        .package(name: "BitByteData", path: "../BitByteData"),
    ],
    targets: [
        .target(
            name: "SWCompression",
            dependencies: ["BitByteData"],
            path: "Sources",
            exclude: ["swcomp"],
            sources: ["Common", "7-Zip", "BZip2", "Deflate", "GZip", "LZ4", "LZMA", "LZMA2", "TAR", "XZ", "ZIP", "Zlib"],
            resources: [.copy("PrivacyInfo.xcprivacy")]),
    ],
    swiftLanguageVersions: [.v5]
)
