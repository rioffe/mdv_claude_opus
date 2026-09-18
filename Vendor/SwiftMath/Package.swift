// swift-tools-version: 5.7
// Vendored copy of mgriebling/SwiftMath 1.7.3 — see README.md for the patches carried (I-011).
import PackageDescription

let package = Package(
    name: "SwiftMath",
    defaultLocalization: "en",
    platforms: [.iOS("11.0"), .macOS("12.0")],
    products: [
        .library(name: "SwiftMath", targets: ["SwiftMath"]),
    ],
    targets: [
        .target(
            name: "SwiftMath",
            dependencies: [],
            resources: [
                .copy("mathFonts.bundle")
            ]),
    ]
)
