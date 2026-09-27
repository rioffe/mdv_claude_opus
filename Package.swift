// swift-tools-version: 5.9
// mdv6 — Markdown viewer for macOS (SPEC.md v0.11). K-01: swift-tools-version 5.9, no Xcode project.
import PackageDescription

let package = Package(
    name: "mdv6",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "mdv6Core", targets: ["mdv6Core"]),
        .executable(name: "mdv6", targets: ["mdv6"]),
    ],
    dependencies: [
        // MarkdownUI is vendored (Vendor/MarkdownUI, I-016, D-49); its own dependencies still come from the network.
        .package(url: "https://github.com/swiftlang/swift-cmark", from: "0.4.0"),
        .package(url: "https://github.com/gonzalezreal/NetworkImage", from: "6.0.0"),
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter", from: "0.8.0"),
        .package(url: "https://github.com/lukilabs/beautiful-mermaid-swift", from: "1.0.4"),
        .package(path: "Vendor/SwiftMath"),
    ],
    targets: [
        // The eighteen vendored tree-sitter grammars (K-05, R-38, R-43); see mdv6/Grammars/README.md.
        .target(
            name: "CGrammars",
            path: "mdv6/Grammars",
            exclude: [
                "README.md",
                "c/LICENSE", "go/LICENSE", "rust/LICENSE", "bash/LICENSE", "javascript/LICENSE", "yaml/LICENSE",
                "toml/LICENSE", "python/LICENSE", "ruby/LICENSE", "swift/LICENSE", "sql/LICENSE",
                "cpp/LICENSE", "json/LICENSE", "lua/LICENSE", "opencl/LICENSE", "perl/LICENSE",
                "markdown/LICENSE", "markdown-inline/LICENSE",
                "yaml/src/schema.core.c",   // #included by yaml/src/scanner.c
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("YAML_SCHEMA", to: "core"),
                .unsafeFlags(["-Wno-shorten-64-to-32"]),   // upstream tree-sitter scanners (pinned, unpatched) narrow size_t
            ]
        ),
        // The application: every contract, pipeline, service, session rule and view (§9.0).
        .target(
            name: "mdv6Core",
            dependencies: [
                "MarkdownUI",
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
                .product(name: "BeautifulMermaid", package: "beautiful-mermaid-swift"),
                .product(name: "SwiftMath", package: "SwiftMath"),
                "CGrammars",
            ],
            path: "mdv6",
            exclude: ["Grammars", "Info.plist", "mdv6.entitlements", "AppIcon.icns", "Fonts/README.md", "mermaid.LICENSE.txt"],   // the licence is bundled by build.sh (C-13)
            sources: ["Core"],
            resources: [
                .copy("Fonts"),
                .copy("Queries"),
                .copy("Help.md"),
            ],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        // Vendored gonzalezreal/swift-markdown-ui v2.4.1 with the changes Vendor/MarkdownUI/README.md lists (I-016).
        .target(
            name: "MarkdownUI",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
                .product(name: "NetworkImage", package: "NetworkImage"),
            ],
            path: "Vendor/MarkdownUI/Sources/MarkdownUI"
        ),
        // Thin executable (§9.0): App/main.swift only.
        .executableTarget(
            name: "mdv6",
            dependencies: ["mdv6Core"],
            path: "App"
        ),
        .testTarget(
            name: "mdv6Tests",
            dependencies: ["mdv6Core"],
            path: "Tests/mdv6Tests"
        ),
        .testTarget(
            name: "mdv6RenderTests",
            dependencies: ["mdv6Core", "MarkdownUI"],
            path: "Tests/mdv6RenderTests"
        ),
    ]
)
