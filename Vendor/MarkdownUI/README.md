# MarkdownUI (vendored)

Upstream: https://github.com/gonzalezreal/swift-markdown-ui, **v2.4.1** (revision `5f613358148239d0292c0cef674a3c2314737f9e`), MIT — see `LICENSE`.

Only `Sources/MarkdownUI` is vendored. The rest is left out:

- `Documentation.docc`;
- the tests;
- the upstream `Package.swift`.

The `MarkdownUI` target is declared in this repository's root `Package.swift`. Its own dependencies still come from the network:

- `swiftlang/swift-cmark` (`cmark-gfm`, `cmark-gfm-extensions`);
- `gonzalezreal/NetworkImage`.

`UPSTREAM.sha256` records the SHA-256 of every upstream file as it was copied from the resolved 2.4.1 checkout. `Tests/mdv6RenderTests/VendorMarkdownUITests` asserts two things (`SPEC.md` I-016, T-62):

- every file **not** named below is byte-identical to that manifest;
- every file named below differs from it or is new.

## Why vendored

Upstream resolves an inline image (`![](…)` inside a paragraph) only in `InlineText`'s `.task`. SwiftUI's `ImageRenderer` never runs a `.task`, and printing renders every block with `ImageRenderer` (`SPEC.md` C-21.4). Without a way to hand the renderer images that are already resolved, every inline formula and every inline picture would print as nothing. The hook below is that way. It is empty by default, so on-screen rendering is unchanged (`SPEC.md` D-49).

## Local changes vs upstream

- `./Views/Environment/Environment+ResolvedInlineImages.swift` (new) adds:
  - `View.markdownResolvedInlineImages(_:)`;
  - `EnvironmentValues.resolvedInlineImages: [String: Image]`, keyed by image source and empty by default.
- `./Views/Inlines/InlineText.swift` reads `resolvedInlineImages` and merges it with the images its `.task` loaded. For the same key, a loaded image wins over a supplied one.
- `./Parser/MarkdownParser.swift`: the two `@_implementationOnly import` lines become plain imports. Without library evolution the attribute only produces warnings, and this module is linked statically. Warning-only change.
- `./Theme/TextStyle/Styles/FontPropertiesAttribute.swift` adds `import SwiftUI`. The file uses `SwiftUIAttributes` but imported only Foundation. Warning-only change.

Keep this list and `UPSTREAM.sha256` in sync when re-vendoring.
