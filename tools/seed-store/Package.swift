// swift-tools-version: 5.9
// seed-store — writes the §9.6 isolated-store fixture (bookmarks, history, theme) through the application's own
// Database/HistoryCodec so observed runs start from a known state. Not part of the product.
import PackageDescription
let package = Package(
    name: "seed-store",
    platforms: [.macOS(.v13)],
    dependencies: [.package(name: "mdv6", path: "../..")],
    targets: [.executableTarget(name: "seed-store", dependencies: [.product(name: "mdv6Core", package: "mdv6")], path: "Sources/seed-store")]
)
