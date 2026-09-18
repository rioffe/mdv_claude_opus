# Detailed implementation plan — W1: Pure contracts and the spec's metrics

> - **Wave:** W1 of W0–W7 (`IMPLEMENTATION_PLAN.md` §4 item 2 — "Pure contracts and the spec's metrics").
> - **Spec basis:** `SPEC.md` v0.11, sha256 `eb28cfebe7456a5cfc05dca8df743dc1d2457514c68115a2b85334717437f897`; `TYPOGRAPHY.md`, sha256 `e3a6b1a4882106f26dc9a9dfe5f34ed6a5f41e4e62a60f16edf08cd0d28e52ad`. Neither is edited by this wave.
> - **Gate:** `swift test --filter mdv6Tests.ContractTests` exit 0 with every unit-group T-nn of §9.0 green and each formula's degenerate case asserted.
> - **Budget:** 1,900–2,400 production lines across 15–17 files (`IMPLEMENTATION_PLAN.md` §5 row "Pure contracts").
> - **Depends on:** W0 (`Package.swift`, `mdv6Core` target, fonts in `Bundle.module`). **Unlocks:** W2 (`HistoryEntry`, `FTSQuery`, anchors), W3 (`ContentLimits`, `MathSymbols.preprocess`, `MDVMermaidPipeline.sanitize`, `CodeLanguage`, `MDVTheme`), W4 (`RenderMetrics`, `ColumnWidth`, `MathMarkdown`), W5 (`ParsedDocument`, slugs, sections, zoom).

## 1. Objective and spec obligations

| spec id | obligation | how discharged |
|---|---|---|
| C-02, R-04 (split half), E-23, I-004 | block split rules 1–7, CRLF, TOC headings | `ParsedDocument.parseBlocks/parseTOC`; T-39 split clauses, T-30 (index identity) |
| C-11, I-010 | GitHub slug rule | `headingSlug`; T-22 slug clauses |
| C-12 | section range, inline strip incl. `_…_` rule | `sectionRange`, `stripInlineMarkdown`; T-30, T-08 (strip) |
| C-08, K-09, E-08 (resolve half) | fingerprint normalisation, resolve order | `bookmarkFingerprint`, `resolveBookmarkAnchor`; T-26 unit clauses |
| C-10, I-012, R-17 (function half) | smart typography exclusions | `smartenMarkdown`; T-10 unit cases |
| C-03 (query half), E-24 | token cleaning and `"tok"*` join | `FTSQuery.make`; T-24 query clauses |
| C-07.1, E-07, K-08 (mode half) | delimiter rules, own-paragraph rule, URL form | `MathMarkdown.rewrite`; T-07 delimiter cases, T-46 (rewrite half) |
| C-07.3 | plain-text form | `MathMarkdown.plainText`; T-08 |
| C-07.2 (rewrites half) | command rewrites in order | `MathSymbols.preprocess`; T-07 |
| C-06.1, E-14, E-15, C-06.2 (state half) | sanitiser rules 1–6, state description merge | `MDVMermaidPipeline.sanitize/mergeStateDescriptions/normalizeColors`; T-15, T-16, T-20 unit output |
| K-14, E-28 (message half), R-41 (check half) | ceilings as constants and checks | `ContentLimits`; T-41 unit clauses (boundary values) |
| R-30 (formula), K-04 | zoom step formula, HUD percent | `ZoomStep.apply`, `ZoomStep.hudPercent`; T-11 formula clause (1.25 → 1.4) |
| §7.2, K-13, K-07 (width half) | column width and raster width | `ColumnWidth.column`, `ColumnWidth.rasterWidth`; T-18 formula clause (768/732, floor at 1) |
| §7.1, C-17 ($q$), K-16 (band), I-014 (metric) | ink metric, pixel fraction, ink-row gap | `RenderMetrics.ink/pixelMismatch/inkRows/gap/band`; synthetic-bitmap tests |
| C-15, I-013 (codec half) | history JSON codec, tolerant decode | `HistoryEntry`, `HistoryCodec`; T-25 decode clause |
| C-09, K-10, R-29 (table half), R-13 (ems) | theme fields, nine themes, `System` resolution rule | `MDVTheme`, `ThemeCatalog`; theme-table tests |
| C-05 (resolution half), R-08 (prompt set) | language aliases, prompt-aware set, copy-without-prompts text | `CodeLanguage.resolve`, `CodeLanguage.isPromptAware`, `CodeLanguage.stripPrompts`; T-06 unit clauses |
| R-35, I-003 (function half) | the only log sink, content never passed | `Diagnostics.log(_:)`; test that the API takes no document string |
| R-27 (title rule), K-06 (60 clusters, 40 look-back) | bookmark title rule as a pure function | `BookmarkTitle.title(blocks:index:)`; T-26 title clauses |

## 2. Entry preconditions

W0 gate green (`swift build && bash tools/gate-w0.sh`). `Tests/mdv6Tests/ContractTests.swift` stub exists (W0). Fonts under `Bundle.module` (used by `FontRegistration` in this wave).

## 3. Deliverables, file by file (all under `mdv6/Core/`, all NEW)

### 3.1 `ParsedDocument.swift` — ~150 lines
```swift
public struct TOCHeading: Equatable { public let level: Int; public let text: String; public let slugText: String; public let blockIndex: Int }
public struct ParsedDocument: Equatable {  // equality on raw
    public let raw: String; public let blocks: [String]; public let tocHeadings: [TOCHeading]
    public init(raw: String)
    public static func parseBlocks(_ s: String) -> [String]
    public static func parseTOC(blocks: [String]) -> [TOCHeading]
    public static func normalizeLineEndings(_ s: String) -> String
    public static func isFence(_ block: String) -> Bool; public static func isMathFence(_ block: String) -> Bool; public static func isGFMTable(_ block: String) -> Bool
}
```
Rules 1–7 of C-02 verbatim; fence closes on any run of the same three-character marker (E-23); math fence closes on the next line *containing* `$$`; indented code not recognised; trimmed, empties dropped; CRLF/CR → LF before splitting; TOC = blocks whose trimmed text starts `# `/`## `/`### ` and are not fences, first line only; `text` via `stripInlineMarkdown` + `MathMarkdown.plainText`, `slugText` via strip only.

### 3.2 `HeadingSlug.swift` — ~40 lines
`public func headingSlug(_ s: String) -> String` — C-11 rule exactly (lower-case; letters/digits kept; `-`/`_` kept when something precedes; other non-whitespace dropped; every whitespace run → one `-` when something precedes; trailing `-`/`_` stripped). Examples in tests: `a - b` → `a---b`, `C++ & Rust` → `c--rust`, `_Draft_ notes` (after strip) → `draft-notes`.

### 3.3 `Sections.swift` — ~90 lines
`public func sectionRange(blocks:tocHeadings:headingAt:) -> Range<Int>`; `public func sectionMarkdown(...) -> String` (join `\n\n`); `public func stripInlineMarkdown(_ s: String) -> String` (trailing `#`s, `**`, `__`, backticks, unescaped `*`, `_…_` pair when opening `_` not preceded by letter/digit, `[text](url)` → `text`).

### 3.4 `Anchors.swift` — ~60 lines
`public func bookmarkFingerprint(_ block: String) -> String` (split on Unicode whitespace scalars, join U+0020, `lowercased()` without normalisation, first 80 grapheme clusters); `public func resolveBookmarkAnchor(blocks:storedIndex:fingerprint:) -> Int` (fingerprint match first, clamped index, 0 when empty); `public struct AnchorValidity { static func scrollRestorable(storedMtime:fileMtime:index:count:) -> Bool }` (1 s tolerance, bounds).

### 3.5 `SmartTypography.swift` — ~160 lines
`public func smartenMarkdown(_ block: String) -> String` — unchanged for fences, GFM tables, thematic breaks; outside code spans (n-backtick run closes only on exactly n), `](…)` URL parts and `<…>`: directional quotes from the preceding character, `---` → `—`, `--` between letters/digits → `–`, ` -- ` → ` — `, other `--` unchanged, `...` → `…`.

### 3.6 `FTSQuery.swift` — ~40 lines
`public enum FTSQuery { public static func make(_ input: String) -> String? }` — split on whitespace, drop `" ( ) : * ^`, discard empties, `"tok"*`, join with spaces; `nil` when no survivors (E-24). Constants `public static let limit = 80`, `snippetTokens = 14`, the `ORDER BY rank ASC, path COLLATE NOCASE ASC, path ASC` clause string.

### 3.7 `MathMarkdown.swift` — ~260 lines
```swift
public enum MathMarkdown {
    public static func rewrite(_ block: String, fontSize: CGFloat, headingSizeEms: [CGFloat], color: RGBA) -> String
    public static func spans(in block: String) -> [MathSpan]          // delimiter rules
    public static func plainText(_ s: String) -> String                // C-07.3
    public static func url(for: MathSpan, size: CGFloat, color: RGBA) -> String  // mdv6-math://inline|display/<base64url>?s=&c=
    public static func decode(url: URL) -> MathSpec?                    // re-pads base64url
}
public struct MathSpan: Equatable { public let range: Range<String.Index>; public let latex: String; public let display: Bool; public let ownParagraph: Bool }
```
Delimiter rules (Pandoc `tex_math_dollars`), no rewrite inside fences/inline code, `\$` literal, empty `$$` literal; own-paragraph `$$` (line-start opener, line-end closer, one or several lines) emitted as its own paragraph with blank lines and preserved indentation; heading em factor from `#` count (R-13).

### 3.8 `MathSpec.swift` — ~30 lines
`public struct MathSpec: Hashable { latex, fontSize, color: RGBA, display: Bool }`; `public struct RGBA: Hashable { r,g,b,a: UInt8; hex: String }`.

### 3.9 `MathSymbols.swift` — ~120 lines (the pure half; registration is W3)
`public enum MathSymbols { public static func preprocess(_ latex: String) -> String; public static let registeredSymbols: [(name: String, codepoint: String, kind: SymbolKind)] }` — the C-07.2 (b) regex rewrites **in order**; the (a) symbol table as data.

### 3.10 `MDVMermaidPipeline.swift` — W1 owns the pure half (~220 lines); W3 appends `prepare/rasterize/displaySize`
`public static func sanitize(_ source: String) -> String` (rules 1–6 in order), `normalizeColors(_ line: String) -> String`, `mergeStateDescriptions(_ lines: [String]) -> [String]`, `stripFormattingTags`, `expandParallelograms`, `dropFrontMatter`, `renameXYSeries`. Colour name table exactly as C-06.1 rule 3; `transparent`/`none` → `#00000000`.

### 3.11 `ContentLimits.swift` — ~70 lines
`public enum ContentLimits { documentBytes = 64 MiB; mermaidBytes = 1 MiB; latexBytes = 64 KiB; encodedImageBytes = 32 MiB; decodedPixels = 64_000_000; decodedBytes = 256 MiB; imageAxis = 16_384; public enum Kind; public static func admits(_ byteCount: Int, kind: Kind) -> Bool; public static func exceededMessage(kind:) -> String /* "input exceeds limit" */ }`. Binary units; "at the ceiling is admitted".

### 3.12 `ZoomStep.swift` — ~30 lines
`public enum ZoomStep { static let step = 0.10, min = 0.60, max = 2.50; static func apply(stored s: Double, delta d: Double) -> Double /* clamp(roundHalfAway(10s)/10 + d) */; static func clampOnRead(_:) -> Double; static func hudPercent(_ s: Double) -> Int /* floor(100s + 0.5) */ }`.

### 3.13 `ColumnWidth.swift` — ~40 lines
`public enum ColumnWidth { static let blockPadding: CGFloat = 6; static let handleWidth: CGFloat = 8; static func column(area:sidebar:inspector:maxWidth:padding:) -> CGFloat; static func rasterWidth(natural:column:) -> CGFloat /* floor(min(natural, max(col-36, 1))) */ }`.

### 3.14 `RenderMetrics.swift` — ~200 lines
`public struct Bitmap { width, height, rgba: [UInt8] }` (+ init from `CGImage`); `public enum RenderMetrics { static func ink(_ crop: Bitmap) -> Double /* §7.1 */; static func pixelMismatch(_ a: Bitmap, _ b: Bitmap) -> Double? /* q; nil on size mismatch or N=0 */; static func inkRows(_ b: Bitmap, page: RGBA, threshold: 8) -> [Int]; static func gaps(between rows: [ClosedRange<Int>], scale: CGFloat) -> [CGFloat]; static func band(v: CGFloat, f: CGFloat) -> ClosedRange<CGFloat> /* v…v+0.6f */; static func inkBounds(_ b: Bitmap, page: RGBA) -> CGRect? }`.

### 3.15 `HistoryManager.swift` — W1 owns `HistoryEntry` + codec only (~50 lines); W2 adds the manager
`public struct HistoryEntry: Codable, Equatable { public let id: UUID; public let path: String; public let addedAt: Date; public var filename: String }`; `public enum HistoryCodec { static func encode([HistoryEntry]) -> Data; static func decode(Data?) -> [HistoryEntry] /* [] on failure; unknown keys ignored */ }`.

### 3.16 `ThemeManager.swift` — W1 owns `MDVTheme`, `CodePalette`, `ThemeCatalog`, `FontRegistration` (~350 lines); W2/W6 add the observable manager
C-09 fields, defaults (`baseFontSize 16`, ems 1.75/1.4/1.15, h4–h6 1.0/0.875/0.85, `headingSizeEms`, `articleMaxWidth 860`, `articleHorizontalPadding 40`, `paragraphLineSpacingEm 0.30`, spacing 24/16 ×3, paragraph 16, `showH1Rule true`, `showH2Rule false`, `headingFontWeight .semibold`, `strongFontWeight .semibold`, `smartTypographyAllowed`, `codePalette`, `accent`); the nine themes with the `TYPOGRAPHY.md` values (Sevilla 17 pt/0.55/620/30/1.7/1.25/1.1, spacing 28/18, 32/12, 22/8, p 14, palette as listed; Charcoal 16.5/0.25/920/1.82/1.39/1.15, 0/14, 26/10, 18/8, p 11; Solarium pair Besley 16/0.20/720/36/1.55/1.28/1.1; Standard Erin pair 15 pt, `.regular` headings, `.bold` strong; Phosphor, Twilight, High Contrast at defaults with their accents); `static let all` in the C-09 order; `ThemeCatalog.resolve(id:isDarkAppearance:) -> MDVTheme` (`system` → `high-contrast`/`twilight`; unknown → `high-contrast`); `FontRegistration.registerBundledFonts()` and `dyslexiaBodyFamily`; `CodePalette` (oneDark, githubLight, dyslexiaLight/Dark) with capture-name lookup.

### 3.17 `CodeLanguage.swift` — ~80 lines
`public enum CodeLanguage: String, CaseIterable { c, go, rust, bash, javascript, yaml, toml, python, ruby, swift, sql; static func resolve(infoString: String?) -> CodeLanguage?; static func isPromptAware(infoString: String?) -> Bool; static func isPrompted(code: String) -> Bool /* ≥ half of non-empty lines start "$ " or "# " */; static func stripPrompts(_ code: String) -> String }`.

### 3.18 `Diagnostics.swift` — ~25 lines
`public enum Diagnostics { public enum Event { case storeFailure(String), fontRegistrationFailure(String), editorLaunchFailure(String) }; public static func log(_ e: Event) }` → `NSLog("[mdv6] …")`. No `String` overload.

### 3.19 `BookmarkTitle.swift` — ~50 lines
`public enum BookmarkTitle { static let lookBack = 40, maxClusters = 60; static func title(blocks: [String], toc: [TOCHeading], index: Int) -> String }` — heading at or within 40 previous blocks (display text) → first line stripped, truncated to 60 clusters → `(line n)` → `(empty)`.

## 4. Work items, in order

- **W1-01** `ContractTests.testParseBlocks_*` (rules 1–7, E-23 three cases, CRLF vs LF equal blocks and TOC, zero-byte → `[]`) → `ParsedDocument`.
- **W1-02** `testHeadingSlug_*` (C-11 examples, `#example` duplicates first-wins is W5; unicode kept) → `headingSlug`.
- **W1-03** `testStripInlineMarkdown_*` (`_Draft_ notes` → `Draft notes`, `snake_case_name` kept, link → text) and `testSectionRange_*` (h4 never ends a section; next same-or-higher level; to end) → `Sections`.
- **W1-04** `testFingerprint_*` (tabs/CRLF/NBSP/repeated spaces → one space; locale-independent lowercase `İ`; combining sequences distinct; 80 clusters incl. emoji) and `testResolveAnchor_*` (fingerprint first, clamp, empty → 0) and `testScrollRestorable_*` (1 s tolerance, bounds) → `Anchors`.
- **W1-05** `testSmarten_*` (quotes curl; `--flag` survives; ` -- ` → em; `---` → em; `...`; code spans, URLs, `<…>`, tables, thematic break unchanged) → `SmartTypography`.
- **W1-06** `testFTSQuery_*` (`auth` → `"auth"*`; punctuation dropped; empty/whitespace → nil; `"a:b"` → `"ab"*`) → `FTSQuery`.
- **W1-07** `testMathSpans_*` (E-07 literals: `$5 and $10`, `$5-$10`, `$100/month`, `\$x\$`, backtick crossing, empty `$$`; inline/display detection; own-paragraph for `$$x$$` and the fence form; mid-line `$$` inline) and `testMathRewrite_*` (URL form, base64url no padding, `?s=16.0&c=RRGGBBAA`, heading em sizing, decode re-pads) and `testPlainText_*` (`\frac{a}{b}` → `a/b`, `\sqrt{x}` → `√x`, `\pi` → `π`, `x^2` → `x²`, `x_{ij}` → `xᵢⱼ`, `x^{ab}` kept, wrappers unwrapped) → `MathMarkdown`, `MathSpec`.
- **W1-08** `testMathPreprocess_*` (each C-07.2 rewrite, order-sensitive `align*` → `aligned`, `\big(` removed, `\pmod{n}`) → `MathSymbols.preprocess`.
- **W1-09** `testMermaidSanitize_*` (front matter dropped; xychart names; `#eee` → `#eeeeee`, `fill:white` → `#ffffff`, `stroke:none` → `#00000000`, unknown name passthrough; state descriptions folded into `state "a<br/>b" as ID` after the header; parallelograms; tags stripped, `<br/>` kept; order) → `MDVMermaidPipeline` pure half.
- **W1-10** `testContentLimits_*` (each ceiling admitted at exactly the ceiling, rejected one unit above; message) → `ContentLimits`.
- **W1-11** `testZoomStep_*` (1.25 + step → 1.4; 1.0 five steps → 1.5; clamps; `hudPercent(1.5)` = 150; negative half rounds away) → `ZoomStep`.
- **W1-12** `testColumnWidth_*` (defaults, wide window → 768 and raster 732; sidebar 220 + insp 240 → both handles counted; `col < 37` → raster exactly 1; no theme cap → ∞) → `ColumnWidth`.
- **W1-13** `testInk_*` (synthetic crop: all white → 0 with `D` empty flagged; known grey values → exact mean), `testPixelMismatch_*` (identical → 0; one pixel of 100 differing by 9 → 0.01; by 8 → 0; size mismatch → nil; N=0 → nil), `testInkRows_*` (two ink bands separated by k rows → gap k/2 at scale 2), `testBand_*` → `RenderMetrics`.
- **W1-14** `testHistoryCodec_*` (round trip; malformed → `[]`; unknown keys ignored; C-15 key names present) → `HistoryEntry`/`HistoryCodec`.
- **W1-15** `testThemes_*` (nine ids in C-09 order; `system` resolution light/dark; unknown → high-contrast; Sevilla/Charcoal spacing values; `smartTypographyAllowed` false for phosphor and the two Erins; every theme `text != heading`; code font is monospace regardless) → `ThemeManager` pure half; `FontRegistration` registers without a `Diagnostics` failure (assert the three families resolve via `NSFontManager`).
- **W1-16** `testCodeLanguage_*` (every alias; `brainfuck` → nil; `fish`/`console` prompt-aware but plain; `shell-session`/`powershell` not; `isPrompted` half rule; `stripPrompts` keeps output lines and count) → `CodeLanguage`.
- **W1-17** `testBookmarkTitle_*` (heading within 40; beyond 40 → first line stripped, 60 clusters; empty → `(line n)`; no blocks → `(empty)`) → `BookmarkTitle`. `testDiagnostics_*` (API compiles only with `Event`).

## 5. Test plan

| target file | spec ids | asserted | runs |
|---|---|---|---|
| `Tests/mdv6Tests/ContractTests.swift` (may be split into `SplitTests`, `MathTests`, `MermaidSanitizeTests`, `MetricsTests`, `ThemeTests`, `MiscContractTests`) | C-02, C-03, C-05, C-06.1, C-07, C-08, C-09, C-10, C-11, C-12, C-15, K-04, K-06, K-09, K-10, K-13, K-14, K-16, E-07, E-14, E-15, E-23, E-24, E-28, I-004, I-010, I-012, I-013, R-04, R-08, R-13, R-17, R-27, R-29, R-30, R-35, R-41, §7.1, §7.2, T-07, T-08, T-10, T-11, T-14, T-15, T-16, T-18, T-20, T-22, T-24, T-26, T-30, T-39 | the outcomes in §4, each test's `///` doc comment citing its ids | `swift test --filter mdv6Tests` |

## 6. Gate

1. `swift test --filter mdv6Tests --xunit-output junit.xml` — exit 0; ≥ 90 test cases; 0 skipped.
2. `speccheck check --spec SPEC.md --src mdv6/Core --tests Tests --results junit.xml --judge mock --out build/speccheck` — exit 1 (many ids still UNCITED) but **0 dangling, 0 stale**, and every W1 id in §1 reported `PASSING`.
3. `swift build` — exit 0 (app still launches, W0 gate 9 unaffected).

## 7. Traceability

Every id in §1: `not yet realised → realised (pure half)`; the "(half)" rows name W3/W4/W5 for the remainder. `RenderMetrics` rows (§7.1, C-17 $q$, K-16 band, I-014 metric) close the metric half only; T-17/T-45 wait for W4.

## 8. Risks and traps

- **Regex-based Markdown parsing drift:** `MathMarkdown.spans` must be a single left-to-right scanner honouring backticks; do not use `NSRegularExpression` for the span rule (E-07 cases interleave). Rule: the scanner is one function with the five delimiter conditions as named predicates.
- **`lowercased()` vs locale:** use `String.lowercased()` (locale-independent) never `lowercased(with: .current)` (C-08).
- **Grapheme counting:** `prefix(80)` on `String` counts extended grapheme clusters (correct); never `utf8.prefix`.
- **Theme values are `TYPOGRAPHY.md`'s, not MarkdownUI's:** each theme's spacing/em/size row is asserted literally in `testThemes_*`.
- **Rule (§6 "budget as target"):** no protocol abstractions over these enums; free functions and `static func`s only.

## 9. Exit criteria and handoff contract

Frozen names: every signature in §3. Later waves call them as published (`ParsedDocument(raw:)`, `headingSlug`, `sectionRange`, `stripInlineMarkdown`, `bookmarkFingerprint`, `resolveBookmarkAnchor`, `AnchorValidity.scrollRestorable`, `smartenMarkdown`, `FTSQuery.make`, `MathMarkdown.rewrite/plainText/spans/decode`, `MathSymbols.preprocess/registeredSymbols`, `MDVMermaidPipeline.sanitize`, `ContentLimits.admits/exceededMessage`, `ZoomStep.apply/hudPercent/clampOnRead`, `ColumnWidth.column/rasterWidth`, `RenderMetrics.*`, `HistoryCodec.encode/decode`, `MDVTheme`, `ThemeCatalog.resolve`, `FontRegistration.registerBundledFonts`, `CodeLanguage.*`, `Diagnostics.log`, `BookmarkTitle.title`). Next wave re-runs `swift test --filter mdv6Tests` (expected exit 0) before starting.
