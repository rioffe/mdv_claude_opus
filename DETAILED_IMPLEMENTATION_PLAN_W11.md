# Detailed implementation plan — W11: vendored MarkdownUI and the block renderers

> - **Wave:** W11 of W10–W15 (`IMPLEMENTATION_PLAN.md` §II.4 "W11 — vendored MarkdownUI and the block renderers").
> - **Spec basis:** `SPEC.md` v0.14.4, sha256 `2c193583…9fdc`. Not edited.
> - **Gate:** diff blocks, `<img>` tags, inline images, the properties table and find typography render through the article view as the contracts state; MarkdownUI is vendored with exactly its inventoried change.
> - **Budget:** 400–600 production code lines (≈40 of them in the MarkdownUI patch); vendored upstream excluded.
> - **Depends on:** W10 (§9 of its brief). **Unlocks:** W12 (the hidden-header view contract), W14 (`markdownResolvedInlineImages`, `FrontmatterTableView(paddingScale:)`, `CodeBlockChrome(forPrint:)`).

## 1. Objective and spec obligations

| Spec id | Obligation | Discharge |
|---|---|---|
| I-016, D-49, T-62 | vendor MarkdownUI 2.4.1 with one hook | `Vendor/MarkdownUI` + `README.md` inventory; root `Package.swift` target |
| R-50, C-05.1 (render), R-08 amendment | diff tint with per-theme colours | `CodePalette` diff fields; `DiffHighlighter.render`; `CodeRenderer` route + cache key |
| R-51, C-22.2, R-16 amendment | `mdv6-img` block/inline; inline local loads; gated inline remote with a text image; baseline placement for non-math inline images | `ImageProviders` |
| C-20.3, R-44 (view half), I-018 (view half) | properties table, or nothing when hidden (no height, padding or spacing) | `FrontmatterTableView`; `ArticleBlockView` block-0 branch |
| R-24, C-09.1 | find typography; header takes the verbatim path | `ArticleBlockView` find branch using `FindBlockStyle` |
| §3.2 order | `<img>` → math → smart typography | `ArticleBlockView` prose path |
| T-52, T-58, T-59, T-60, T-62 (halves) | render assertions | §5 |

## 2. Entry preconditions

- W10's frozen symbols.
- The resolved checkout `.build/checkouts/swift-markdown-ui` at 2.4.1 (revision to be verified as `5f613358148239d0292c0cef674a3c2314737f9e` with `git -C … rev-parse HEAD` before copying).
- `ArticleBlockView`, `ArticleHost`, `DocumentImageView`, `CodeRenderer`, `DocumentRenderer`, all from W3/W4.

## 3. Deliverables

### 3.1 `Vendor/MarkdownUI/` — NEW (vendored)

- **Copied from upstream:** `Sources/MarkdownUI` only, with no `Documentation.docc`, plus `LICENSE`.
- **The patch** (≈40 lines, written from I-016's description, not from the original):
  - a new `Environment+ResolvedInlineImages.swift` holding `EnvironmentValues.resolvedInlineImages: [String: Image]` and `View.markdownResolvedInlineImages(_:)`;
  - an `InlineText` merge in which a `.task`-loaded image wins over a supplied one for the same key.
- **Warning-only fixes**, if needed: `@_implementationOnly` → plain import, and a missing `import SwiftUI`.
- **`README.md`:** the upstream URL, the revision and the change list (I-016).
- **Root `Package.swift`:** `.target(name: "MarkdownUI", dependencies: [cmark-gfm, cmark-gfm-extensions, NetworkImage], path: "Vendor/MarkdownUI/Sources/MarkdownUI")`. The package dependency on swift-markdown-ui is replaced by swift-cmark (`from: 0.4.0`) and NetworkImage (`from: 6.0.0`).

### 3.2 `ThemeManager.swift` — EDIT (+~40)

`CodePalette` gains `diffAdd`, `diffAddBg`, `diffRemove`, `diffRemoveBg`, holding C-05.1's hex table per theme id, with the oneDark and githubLight defaults.

### 3.3 `DiffHighlighter.swift` — EDIT (+~40)

`render(code:palette:hunkHeader:size:) -> AttributedString` applies C-05.1's styling. The background covers the line's characters.

### 3.4 `CodeRenderer.swift` — EDIT (+~10)

- `render` routes to `DiffHighlighter` when the fence word is in `fenceWords`.
- The cache key gains `isDiff`.

### 3.5 `ImageProviders.swift` — EDIT (+~120)

- **Block path:**
  - the `mdv6-img` scheme is resolved against `baseURL`;
  - `data:` and `file:` images load with `ContentLimits`;
  - `http(s)` goes through `DocumentImageView`'s remote gate;
  - an image is drawn at `displaySize`, aspect-fit, capped by the column;
  - a missing file shows its `alt` or `Missing image: <src>` at 12 pt secondary;
  - the accessibility label is `alt`, falling back to `src`.
- **Inline provider** (new `ArticleInlineImageProvider`):
  - math URLs are delegated to the existing math provider (R-12 placement unchanged);
  - `mdv6-img` and relative or `file:` images load from disk, and the image's point size is set to `displaySize`;
  - `http(s)` goes through `RemoteImageLoader` only when the preference is on; otherwise the result is a rendered text image *Remote image blocked* (failure: *Image failed to load*) at the line's font size, in the secondary colour;
  - a missing local image throws, so it is omitted.

### 3.6 `mdv6/Core/FrontmatterTableView.swift` — NEW, ~80

C-20.3: the key column is the widest natural key; alternate fills; a 1 pt border; paddings 6/13 × `paddingScale`; the body face at `round(base × zoom)`; plain `Text`.

### 3.7 `ArticleView.swift` — EDIT (+~80)

- **Block 0 with `frontmatter`:** show the table when the preference is on. When it is off, draw `EmptyView` with zero inset — `blockInset` and stack spacing skipped (R-44).
- **Find path:**
  - a header block always takes the inline path, verbatim (R-24);
  - otherwise the existing path is styled by `FindBlockStyle`;
  - the h1/h2 divider is drawn when the style asks for it.
- **Prose path:** `RawHTMLImages.rewrite` before `MathMarkdown.rewrite`.
- **`ArticleHost` gains `showFrontmatter: Bool`.** `StaticArticleHost` defaults it to true, and `DocumentSession` reads `Preferences` once W12 adds the key. Until then it returns true.

## 4. Work items

- **W11-01 — vendor MarkdownUI.**
  - *Red:* `VendorMarkdownUITests.testInventory` runs `diff -r` from the pristine checkout path against `Vendor/MarkdownUI/Sources/MarkdownUI`, and asserts that the differing file set equals the README's list (T-62, I-016).
  - *Green:* §3.1.
  - *Evidence:* `swift build` passes, and all 173 tests stay green.
- **W11-02 — resolved inline images.**
  - *Red:* `VendorMarkdownUITests.testResolvedInlineImageRendersUnderImageRenderer`: a `Markdown("a ![](x://1) b")` with `markdownResolvedInlineImages(["x://1": red square])`, rendered by `ImageRenderer`, has red pixels.
  - *Green:* the patch.
- **W11-03 — diff colours.**
  - *Red:* `CodeRendererTests.testDiffTint`: `diff.md`'s first fence under `high-contrast` has a removed line with foreground `#CF222E` and background `#FFEBE9`; the `@@` line is italic; meta is semibold; a `patch` fence matches.
  - *Green:* §3.2, §3.3 and §3.4.
- **W11-04 — `<img>` rendering.**
  - *Red:* `ArticleTests.testRawHTMLImageSizes` renders `raw-html-images.md` through `DocumentRenderer`. It locates the images by the harness's block rects and asserts that `width="320"` draws 320 ± 1 pt, the both-attribute case fits, and the missing block shows alt text. `ImageLoadingTests.testInlineRemoteImgGated` asserts zero requests to the recording server for a block and an inline `<img>` with the preference off.
  - *Green:* §3.5.
- **W11-05 — inline math placement unchanged.**
  - *Red:* `ArticleTests.testInlineMathPlacementUnchanged`: a sentence with `$y$` renders identically (pixel $q \le 0.001$) before and after the provider change (F-173).
  - *Green:* delegate math first.
- **W11-06 — the properties table.**
  - *Red:* `ArticleTests.testFrontmatterTable` renders `frontmatter.md`: the first block is a table whose key column width equals the widest key's; with `showFrontmatter` false the first heading's top equals that of the same document without a header (R-44, I-018).
  - *Green:* §3.6 and §3.7.
- **W11-07 — find typography.**
  - *Red:* `ArticleTests.testFindTypographyStable`: the heading block's height with and without a find match differs by at most 1 pt; the header takes the verbatim path showing `---`.
  - *Green:* §3.7.

## 5. Test plan

| File | Spec ids | Asserted | Runs |
|---|---|---|---|
| `Tests/mdv6RenderTests/VendorMarkdownUITests.swift` | I-016, T-62, C-21 | inventory; hook | `--filter VendorMarkdownUITests` |
| `CodeRendererTests.swift` (+) | R-50, C-05, R-08, T-58 | colours, styles | `--filter CodeRendererTests` |
| `ArticleTests.swift` (+) | R-51, C-22, R-12, R-44, C-20, I-018, R-24, C-09, T-52, T-59, T-60 | sizes, placement, table, hidden, find | `--filter ArticleTests` |
| `ImageLoadingTests.swift` (+) | R-16, C-16, D-51, T-59 | zero requests inline or block | `--filter ImageLoadingTests` |

## 6. Gate

1. `swift build` → exit 0.
2. `swift test --filter "VendorMarkdownUITests|CodeRendererTests|ArticleTests|ImageLoadingTests|HarnessTests|RhythmAndDisplayMathTests"` → exit 0. T-45 and T-46 must stay green under the vendored MarkdownUI.
3. `swift run --package-path tools/render-harness render-harness test-docs/raw-html-images.md --output "$TMPDIR/raw.png"` → exit 0.
4. `swift test --parallel --xunit-output junit.xml` → exit 0.

## 7. Traceability

| Spec id | file.symbol | test | status |
|---|---|---|---|
| I-016 | `Vendor/MarkdownUI`, README | VendorMarkdownUITests | *not yet realised* → realised |
| R-50, C-05.1 | `DiffHighlighter.render`, `CodePalette` | CodeRendererTests | → realised (observed W15) |
| R-51, C-22.2, R-16 | `ImageProviders` | ArticleTests, ImageLoadingTests | → realised (observed W15) |
| C-20.3, R-44 view | `FrontmatterTableView`, `ArticleBlockView` | ArticleTests | → half (session W12) |
| C-09.1, R-24 | `ArticleBlockView` find path | ArticleTests | → realised (observed W15) |

## 8. Traps

- **Reach (failure 4).** The inline provider change touches every inline image, including math (R-12, D-02). W11-05 guards it.
- **Vendoring changes the rendering engine**, so T-45 (rhythm) and T-46 (display math) are re-run in the gate.
- **Clean room.** The patch is written from I-016's text. The original's `Vendor/MarkdownUI` is not opened.
- **The remote gate (D-51).** The inline provider must never call `NSImage(contentsOf:)` on an `http(s)` URL.

## 9. Exit and handoff

- **Frozen:** `View.markdownResolvedInlineImages(_:)`, `FrontmatterTableView(rows:theme:zoom:paddingScale:)`, `ArticleHost.showFrontmatter`, `CodePalette.diff*`, `ArticleInlineImageProvider`.
- **Re-run gate:** item 4 above.
