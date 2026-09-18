// swift-tools-version: 5.9
// render-harness — C-17 / R-39: links the application's pipeline (mdv6Core) rather than copying it.
import PackageDescription

let package = Package(
    name: "render-harness",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(name: "mdv6", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "render-harness",
            dependencies: [.product(name: "mdv6Core", package: "mdv6")],
            path: "Sources/render-harness"
        ),
    ]
)
