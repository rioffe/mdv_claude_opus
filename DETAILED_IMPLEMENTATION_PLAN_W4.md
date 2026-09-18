# Detailed implementation plan — W4: Article and the render harness (the visual-oracle wave)

> - **Wave:** W4 of W0–W7 (`IMPLEMENTATION_PLAN.md` §4 item 5 — "Article and the render harness").
> - **Spec basis:** `SPEC.md` v0.11, sha256 `eb28cfebe7456a5cfc05dca8df743dc1d2457514c68115a2b85334717437f897`; `TYPOGRAPHY.md`, sha256 `e3a6b1a4882106f26dc9a9dfe5f34ed6a5f41e4e62a60f16edf08cd0d28e52ad`. Neither is edited by this wave.
> - **Gate:** the three C-17 invocations exit as specified on the checked-in corpus; `swift test --filter RhythmAndDisplayMathTests` exit 0 (T-45, T-46).
> - **Budget:** 1,200–1,600 production lines across 8–9 files (`IMPLEMENTATION_PLAN.md` §5 row "Article views…"); the harness executable is one file.
> - **Depends on:** W1 (`MathMarkdown`, `smartenMarkdown`, `ColumnWidth`, `RenderMetrics`, `MDVTheme`), W3 (all renderers). **Unlocks:** W5 (`ArticleView` consumes `DocumentSession` state through a small protocol), W6 (article inside the window), W7 (harness evidence).

## 1. Objective and spec obligations

| spec id | obligation | how discharged |
|---|---|---|
| R-07, C-09, R-29 (restyle half) | GFM via MarkdownUI with the theme's typography | `ArticleTheme.markdownTheme(for:zoom:)` (heading sizes/spacings, rules, code style, tables, task lists, footnotes); T-05 (manual, W7) |
| §3.2, R-17, I-012 (order) | math rewrite before smarten before MarkdownUI | `ArticleBlockView.body` pipeline order; test asserts order via `$--$` |
| R-12, R-13, C-07.1, E-16, K-08, C-18.10, T-46 | inline images via `MathInlineImageProvider`, own-paragraph display via `MathDisplayView` centred with Copy LaTeX | `MathViews.swift`; `RhythmAndDisplayMathTests` |
| R-16, E-11 | local/data/remote-gated providers, placeholders naming the file / "Remote image blocked" | `ImageProviders.swift` |
| R-08, R-09, R-21 (label), §5.1 in-block controls | code chrome (label, hover toolbar, context menu, Copy Without Prompts), Mermaid chrome (style menu, source toggle, export PNG, copy, pinch zoom 0.5–4, container ≤ 540) | `CodeBlockChrome.swift`, `MermaidCodeBlockChrome.swift`, `MDVMermaidDiagramView.swift` |
| R-11, I-005, K-07, K-13, §7.2 | raster at `ColumnWidth.rasterWidth` at the screen scale; re-raster on width/zoom/scale change | `MDVMermaidDiagramView` |
| R-42 (rhythm), I-014, K-16 (band), T-45 | `blockInset` = $\max(\text{bottom}_i, \text{top}_{i+1})$ between blocks | `ArticleBlockView.blockInset`; `RhythmMetric` test against `Options.singleView` |
| C-18.7 (stripe, find button, heading rules) | 3 pt accent stripe on hovered non-fence blocks; H1/H2 rules full-column | `ArticleBlockView` overlays; observed in W7 |
| R-24 (rendering half), E-17 | whole-block tint vs inline highlight (markers stripped, bullets `•`, math as source) | `FindHighlight.swift` (`shouldInlineHighlight`, `highlightedAttributedString`) + view use |
| R-22 (view half), E-22 | TOC heading blocks not selectable, hand pointer, click → `onCopySection`; other blocks selectable | `ArticleBlockView` modifiers (`textSelection`, `onHover`, tap) |
| R-39, C-17, T-13, T-17, T-19, D-33 | harness commands, exits, JSON, corpus, manifest, metrics | `DocumentRenderer.swift`, `tools/render-harness`, `test-docs/` |

## 2. Entry preconditions

W3 gate green. A window server (hosting `NSHostingView` offscreen needs AppKit but not a visible window). `Tests/mdv6RenderTests/RhythmAndDisplayMathTests.swift`, `HarnessTests.swift` stubs.

## 3. Deliverables

### 3.1 `mdv6/Core/ArticleTheme.swift` — NEW, ~200 lines
`enum ArticleTheme { static func markdownTheme(for t: MDVTheme, zoom: CGFloat) -> MarkdownUI.Theme }` — text `t.text` at `baseFontSize*zoom`, line spacing `paragraphLineSpacingEm`, headings h1–h6 by `headingSizeEms` in `t.heading` with `headingFontWeight`, `showH1Rule`/`showH2Rule` dividers in `t.divider`, strong `t.strong`/`strongFontWeight`, link `t.link`, inline code monospace on `t.secondaryBackground`, blockquote bar `t.blockquoteBar`, tables bordered `t.border`, task lists, thematic break, `paragraphBottomSpacing` and heading top/bottom spacings as `markdownMargin`s.

### 3.2 `mdv6/Core/ArticleView.swift` — NEW, ~330 lines
```swift
public protocol ArticleHost: AnyObject { /* what the view reads from the session */ var document: ParsedDocument? {get}; var theme: MDVTheme {get}; var zoom: CGFloat {get}; var smartTypography: Bool {get}; var loadRemoteImages: Bool {get}; var findState: FindState? {get}; var flashedRange: Range<Int>? {get}; var baseURL: URL? {get}; var mermaidStyle: MermaidStyle {get}
    func copySection(at: Int); func hoveredBlock(_ i: Int?); func linkClicked(_ url: URL) }
public struct ArticleView: View { init(host: ArticleHost, scrollTarget: Binding<Int?>, visibleBlocks: Binding<Set<Int>>, columnWidth: CGFloat) }
public struct ArticleBlockView: View { init(index:, block:, host:, columnWidth:, previous: String?, next: String?) ; static func blockInset(theme:, previous:, current:) -> (top: CGFloat, bottom: CGFloat) }
```
`LazyVStack` of `ArticleBlockView` with `.id(index)` inside a `ScrollViewReader`; per-block padding 6 pt (`ColumnWidth.blockPadding`); `blockInset` reads the block kinds (heading level by `# ` prefix, fence, paragraph) and applies `max(bottom(prev), top(cur))` as the top inset of the current block; the hovered-block stripe (`ChromeMetrics.stripeWidth` 3 pt, `theme.accent`) in the leading padding for non-fence blocks; find tint (`accent.opacity(0.12)`, stronger `0.25` on the current match's block) beneath, section flash (`accent.opacity(0.18)`) above; heading rules; the floating find button is W6's (window-level). Each block dispatches: Mermaid fence → `MermaidCodeBlockChrome`; other fence → `CodeBlockChrome`; prose → `Markdown(rewritten)` with `.markdownTheme`, `.markdownImageProvider(ArticleImageProvider)`, `.markdownInlineImageProvider(MathInlineImageProvider)`, `.markdownCodeSyntaxHighlighter(CodeRenderer)`, `environment(\.openURL)` → `host.linkClicked`.

### 3.3 `mdv6/Core/MathViews.swift` — NEW, ~120 lines
`MathInlineImageProvider: InlineImageProvider` (decodes `mdv6-math://`, returns the baked image); `MathDisplayView` (centred, `.display` height, context menu *Copy LaTeX*); `ArticleImageProvider: ImageProvider` routing `mdv6-math://display/…` to `MathDisplayView`, `data:`/relative/`http(s)` to `ImageProviders`.

### 3.4 `mdv6/Core/ImageProviders.swift` — NEW, ~140 lines
`RemoteGatedImage` view (blocked placeholder that reveals the View menu item via `host`/notification; failure placeholder; loads through `RemoteImageLoader` when enabled; cancels when disabled), `LocalImage` (relative to `baseURL`; "image not found: <name>"), `DataURIImage`; every image `frame(maxWidth: intrinsic)` (never upscaled, K-14 via `ImageDecoding`).

### 3.5 `mdv6/Core/CodeBlockChrome.swift` — NEW, ~150 lines; `MermaidCodeBlockChrome.swift` — NEW, ~180 lines; `MDVMermaidDiagramView.swift` — NEW, ~160 lines
Code: label (lower-cased first word or `text`), hover toolbar (wrap toggle, copy), context menu (Copy Code, Wrap Long Lines, Copy Without Prompts when `CodeLanguage.isPromptAware && isPrompted`). Mermaid: hover capsule (style menu bound to `mdv6.mermaid.style`, Show Source ↔ Show Diagram, Export PNG via `NSSavePanel` at natural size × 2 — failure `NSSound.beep()`, copy), context menu in the §5.1 order, source view monospaced; fallback view "Mermaid diagram could not be rendered" + source (E-02) or "input exceeds limit" (E-28). Diagram view: `prepare` on a background task cancelled on document change (E-25), width = `ColumnWidth.rasterWidth(natural:column:)`, scale = `NSScreen.main?.backingScaleFactor` injected by the host (harness passes its own), `MagnifyGesture` zoom clamped 0.5…4 committed on end, container height ≤ 540 pt when zoomed, `Image(nsImage:)` at exactly `displaySize` (I-005), cache keys through `MermaidCaches`.

### 3.6 `mdv6/Core/FindHighlight.swift` — NEW, ~110 lines
`public struct FindState { query: String; matches: [FindMatch]; current: Int }`, `public struct FindMatch { blockIndex: Int; occurrence: Int }`; `public func countOccurrences(query:in:) -> Int` (case-insensitive substring, verbatim); `public func shouldInlineHighlight(block:) -> Bool` (false for code fence, `$$` fence, GFM table, `![`); `public func highlightedAttributedString(block:query:theme:) -> AttributedString` (markers stripped, `•`, inline Markdown interpreted, math as `$…$`, every occurrence marked).

### 3.7 `mdv6/Core/DocumentRenderer.swift` — NEW, ~180 lines
```swift
public struct DocumentRenderer { public struct Options { width: CGFloat = 860; scale: CGFloat = 2; theme: MDVTheme = .highContrast; singleView = false; smartTypography = true }
    public static func render(markdown: String, options: Options) throws -> NSImage      // hosts ArticleView (or one `Markdown` view when singleView) in an offscreen NSHostingView at `width`, lays out, `bitmapImageRepForCachingDisplay` at `scale`
    public static func render(mermaid source: String, options: Options) throws -> RenderOutcome  // .rendered(NSImage) | .fallback(reason)
    public static func png(_ image: NSImage) -> Data }
```
Runs on the main thread; the harness `main.swift` calls it from `DispatchQueue.main` with `NSApplication` set up (`.prohibited` activation policy).

### 3.8 `tools/render-harness/Package.swift` + `Sources/render-harness/main.swift` — NEW, ~260 lines (one source file)
Argument parsing for the three C-17 forms; exits 0/1/2 exactly as the table; `--output` parent must exist; `--scan` discovery (non-hidden `.mmd` files and Mermaid fences in `.md`, sorted by UTF-8 bytes of relative path then fence index; collision-free output names `<relpath-with-slashes-as-__>#<n>.png`); `--check` executes manifest cases in order (`kind: markdown|mermaid`, `expect: render|fallback`, `golden` optional, `metric: pixel|ink|sequence-layout|rhythm|display-math`) emitting one JSON object per case on stdout (`id`, `status`, `output`), diagnostics to stderr; unknown manifest keys ignored; stable output for identical inputs.

### 3.9 `test-docs/` — NEW corpus
`syntax.md`, `code.md` (nine languages + `brainfuck` + prompted `bash`/`console`/`fish`/`shell-session`/`powershell` + `swift` + `sql` + `postgresql`), `math.md` (sections named in T-07/T-08: inline, display, environments, lists/quotes/tables/headings incl. `## Heading with $\Sigma$ in it`, `## $\pi$ at h2 size, $\frac{a}{b}$ too`, `## _Draft_ notes`, `## snake_case_name`, `\boxed`, registered symbols, "must NOT become math", "Errors"), `images.md` (+ `assets/local.png`, a missing name, a `data:` image, an `https:` image), `links.md` + `links-sibling.md` (T-22 targets incl. duplicate `### Example`, `#a---b`, `#c--rust`, `#draft-notes`, h4 and setext), `tables.md`, `thematic-break.md`, `rhythm.md` (the exact T-45 document), `mermaid/*.mmd` (flowchart, the E-01 two-subgraph case, T-15 sanitiser case, T-16 xychart, T-20 state, sequence with `<br>`/autonumber/notes, class, ER, and the unsupported `timeline`, `gantt`, `pie`, `mindmap`; each licence-cleared, written for this repository), `mermaid-math.mmd` (T-17), `render-cases.json` (`version: 1`; cases `mermaid-math-ink` (metric `ink`), `sequence-layout` (metric `sequence-layout`), `rhythm-sevilla`/`rhythm-charcoal` (metric `rhythm`), `display-math-single-vs-fence` (metric `display-math`), one `pixel` regression case per corpus diagram with goldens under `test-docs/goldens/`), `fixtures/` (the T-44 isolated-store seed: `mdv6.db` bookmarks + `mdv6_history` plist, written by a script in W7).

## 4. Work items, in order

- **W4-01** `RhythmAndDisplayMathTests.testBlockInsetIsMaxOfBottomAndTop` (pure: Sevilla p→h2 = 32, h2→p = max(12,0) = 12; Charcoal) → `ArticleBlockView.blockInset`.
- **W4-02** `testDocumentRendererProducesBitmap` (a one-paragraph document at 860/2 → image 1720 px wide, page colour at the corners) → `DocumentRenderer.render(markdown:)`, `ArticleTheme`, `ArticleView` minimal.
- **W4-03** `testRhythmBand_Sevilla/_Charcoal` (T-45: the exact document; per-block vs single view; ink-row gaps via `RenderMetrics.inkRows`; each of the four boundaries within `band(v,f)`; p→heading > heading→p; per-block within ±2 pt of single view) → `ArticleView` block insets tuned until green (fix the code, never the band).
- **W4-04** `testDisplayMathSingleLineEqualsFence`, `testDisplayMathCentredWithin2pt`, `testMidLineDoubleDollarStaysInline` (T-46) → `MathViews`, `MathMarkdown.rewrite` own-paragraph emission (W1) exercised end-to-end.
- **W4-05** `testFindHighlight_*` (R-24/E-17: `**` on `**bold**` counts 2 marks 0; three "the" in a block; tint classes) → `FindHighlight`.
- **W4-06** `testCodeChromeCopyWithoutPrompts`, `testMermaidFallbackView` (view-model level) → chrome files.
- **W4-07** `testMermaidDiagramViewWidthFormula` (window 1200, sidebar 220, inspector 240, high-contrast → column 768, raster 732; `col < 37` → 1) → `MDVMermaidDiagramView` width plumbing (T-18 formula clauses).
- **W4-08** `HarnessTests.testScanCorpus` (runs `DocumentRenderer` over `test-docs/mermaid` the way `--scan` does; unsupported → fallback, others rendered; deterministic order) and the harness `main.swift`; then the three C-17 commands from the shell (§6).
- **W4-09** `render-cases.json` + goldens generated by the harness and committed as regression guards (labelled as such in the manifest's `note` key, ignored by the reader).

## 5. Test plan

| target file | spec ids | asserted | runs |
|---|---|---|---|
| `Tests/mdv6RenderTests/RhythmAndDisplayMathTests.swift` | R-42, I-014, K-16, C-18.10, C-07.1, R-12, T-45, T-46 | band membership, ±2 pt vs single view, centre within 2 pt, `.display` height, inline mid-line | `swift test --filter RhythmAndDisplayMathTests` |
| `Tests/mdv6RenderTests/HarnessTests.swift` | R-39, C-17, T-13, T-17, T-19, I-001, E-02, E-25 | scan order, fallback classification, pixel/ink/sequence metrics through `DocumentRenderer`, identical output on repeat | `swift test --filter HarnessTests` |
| `Tests/mdv6RenderTests/ArticleTests.swift` | R-24, E-17, R-08, R-09, R-11, K-13, §7.2, T-18, T-23 (render half), T-06 (chrome half) | §4 outcomes | `swift test --filter ArticleTests` |

## 6. Gate

1. `swift test --xunit-output junit.xml` — exit 0.
2. `swift run --package-path tools/render-harness render-harness --scan test-docs/mermaid --output-dir "$TMPDIR/mdv6-scan"` — exit 0; stdout has one JSON line per case; `timeline`, `gantt`, `pie`, `mindmap` cases `fallback`, all others `pass`; run twice → identical stdout and identical PNG bytes (`cmp`).
3. `swift run --package-path tools/render-harness render-harness --check test-docs/render-cases.json` — exit 0; `--case mermaid-math-ink` exit 0; `--case sequence-layout` exit 0; `--case nope` exit 2.
4. `swift run --package-path tools/render-harness render-harness test-docs/rhythm.md --output "$TMPDIR/nonexistent-dir/x.png"` — exit 2 (parent must exist); with `--theme bogus` — exit 2.
5. `wc -l tools/render-harness/Sources/render-harness/*.swift` — one file (R-39 links, never copies).
6. No new file under `~/Library/Logs/DiagnosticReports/` named `mdv6*` or `render-harness*`.

## 7. Traceability

§1 ids: not yet realised → realised; T-13/T-17/T-19 → realised (harness); T-45/T-46 → realised (scripted); T-05/T-08/T-09/T-18 window clauses → W7 observation.

## 8. Risks and traps

- **Self-generated goldens** (§6 rule 1): `metric: pixel` cases are regression guards; the manifest's `rhythm`, `display-math`, `ink`, `sequence-layout` metrics are the oracles and compare against measured quantities, never against a golden.
- **Offscreen SwiftUI layout needs a run-loop turn**: `DocumentRenderer` must `layoutSubtreeIfNeeded()` and spin the main run loop once before caching; the T-45 band test fails with zero-height images otherwise.
- **`LazyVStack` in the harness** renders only the visible viewport: `DocumentRenderer` uses a non-lazy `VStack` of the same `ArticleBlockView`s (same views, full document) — a documented `Options` flag, not a second renderer.
- **`Bundle.module` fonts** must be registered before `DocumentRenderer` measures Sevilla (`FontRegistration.registerBundledFonts()` in `DocumentRenderer`'s first call).

## 9. Exit criteria and handoff contract

Frozen: `ArticleHost` protocol, `ArticleView.init`, `ArticleBlockView.blockInset`, `FindState`/`FindMatch`/`countOccurrences`/`shouldInlineHighlight`/`highlightedAttributedString`, `DocumentRenderer.Options/render/png`, `MermaidStyle` binding key, `test-docs/` file names, `render-cases.json` shape. Next wave re-runs `swift test` and gate 3 (expected exit 0).
