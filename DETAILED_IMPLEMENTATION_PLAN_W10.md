# Detailed implementation plan — W10: v0.14 pure contracts

> - **Wave:** W10 of W10–W15 (`IMPLEMENTATION_PLAN.md` Part II §II.4, item "W10 — v0.14 pure contracts").
> - **Spec basis:** `SPEC.md` v0.14.4, sha256 `2c193583d1f807d7e73310263e67deed22eb7f8808b49102f11e2b727ad59fdc`; `TYPOGRAPHY.md` sha256 `e3a6b1a4…52ad`. Neither is edited by this wave.
> - **Gate:** every v0.14 rule that can be stated as a function exists as one, with unit tests that cite its ids; the 173 existing tests stay green.
> - **Budget:** 400–550 production code lines across 6 new and 3 edited files (§II.5 row "W10 pure contracts").
> - **Depends on:** W1 (`ParsedDocument.split`, `stripInlineMarkdown`, `MDVMermaidPipeline.sanitize`, `MDVTheme`), W8 (`blockLines`). **Unlocks:** W11 (`frontmatterRows`, `DiffHighlighter.classify`, `HTMLImageSpec`, `FindBlockStyle`), W12 (`HistoryStep`, `ScrollKeys`), W13 (`MermaidDispatch`), W14 (`PrintScale`).

## 1. Objective and spec obligations

| Spec id | Obligation | How this wave discharges it |
|---|---|---|
| C-20 (.1, .2), E-32 | recognise a header (byte-0 fence, exact closers, YAML guard, zero-row rule); reduce it to rows | `frontmatterSpan`, `frontmatterRows` |
| C-02 rule 9, I-018 (half) | header is block 0; body split after it; `blockLines` in whole-document lines | `ParsedDocument.split` edit; the view half of I-018 is W11/W12 |
| R-04 (BOM clause) | strip one leading U+FEFF before C-02 | `ParsedDocument.stripBOM`, called by the decode helper |
| C-05.1 (classify) | diff line kinds with hunk counters | `DiffHighlighter.classify`, `hunkCounts` |
| C-06.4, C-06.1 rule 0 | dispatch native/web by first directive line; strip that preamble before native parse | `MermaidDispatch.firstDirectiveLine/isNative/stripPreamble`; `sanitize` calls rule 0 first |
| C-22.1, C-22.2 (size), E-35 | `<img>` → `mdv6-img://`; display size | `RawHTMLImages.rewrite`, `HTMLImageSpec`, `displaySize` |
| C-12 step (0) | remove `<img>` tags first | `stripInlineMarkdown` edit |
| C-09.1 | find-highlight style per heading level | `FindBlockStyle.style(level:theme:zoom:)` |
| K-18 | line and page step, top/bottom targets | `ScrollKeys.target(key:shift:y:usable:documentHeight:)` |
| R-48 | clamp step, no wrap | `HistoryStep.target(current:offset:count:)` |
| C-21.1, C-21.3 (formulas), K-17 (half) | $s_p$, $w_d$, $w_\ell$ | `PrintScale` |
| T-52, T-54, T-56, T-57, T-58, T-59, T-60 (unit halves) | the pure clauses | the tests in §5; the rest land in W11–W15 |

## 2. Entry preconditions

- `mdv6/Core/ParsedDocument.swift` (`split`, `normalizeLineEndings`, `parseTOC` — W1/W8), `Sections.swift` (`stripInlineMarkdown` — W1), `MDVMermaidPipeline.swift` (`sanitize` — W1), `ThemeManager.swift` (`MDVTheme`, fields including heading ems — W1), `BookmarkTitle.swift` (W5).
- Fixtures `test-docs/frontmatter*.md`, `diff.md`, `raw-html-images.md`, `gantt.md`, `mermaid-web-fallback.md` (committed at `7b6c373`, `937a351`).
- Baseline: `swift test` 173/0 (measured 2026-09-27).

## 3. Deliverables, file by file

### 3.1 `mdv6/Core/Frontmatter.swift` — NEW, ~150–200 lines
```swift
public struct FrontmatterRow: Equatable, Sendable { public let key: String?; public let value: String }
public struct FrontmatterSpan: Equatable { public let block: String; public let closingLine: Int /*1-based*/; public let bodyStart: String.Index }
public func frontmatterSpan(in normalized: String) -> FrontmatterSpan?
public func frontmatterRows(_ block: String) -> [FrontmatterRow]
```
Rules:
1. Line 1 exactly `---` or `+++`, else nil (C-20.1).
2. Closers: `---`/`...` for YAML, `+++` for TOML; exact match (C-20.1).
3. YAML guard per line: empty, leading space/tab, `#`, sequence item, or a mapping colon (C-20.1).
4. Zero rows from `frontmatterRows` → nil (C-20.1, F-150).
5. Rows per C-20.2: TOML sections, `=`, bracket depth ignoring quotes and `#`; YAML mapping with continuation group, dedent, `>` fold, `|` keep, empty-scalar nest; one quote pair stripped (C-20.2).

### 3.2 `ParsedDocument.swift` — EDIT (+~30)
- Add `public let frontmatter: [FrontmatterRow]?` and `public static func stripBOM(_:)`.
- `init(raw:)`: normalise → span? → `[span.block] + split(body)`. The body's `blockLines` are offset by the closing line. `blockLines[0] = 1..<(c+1)` (C-02 rule 9).
- `parseTOC` is unchanged: the header never starts with `#`.

### 3.3 `mdv6/Core/DiffHighlighter.swift` — NEW (classify only), ~50
```swift
public enum DiffLineKind: Equatable, Sendable { case meta, hunkHeader, added, removed, context, note }
public enum DiffHighlighter { public static let fenceWords: Set<String>; public static func hunkCounts(_ line: Substring) -> (old: Int, new: Int)?; public static func classify(_ lines: [Substring]) -> [DiffLineKind] }
```
Rules 1–3 are C-05.1's three steps, in that order.

### 3.4 `mdv6/Core/MermaidDispatch.swift` — NEW, ~50
```swift
public enum MermaidDispatch { public static func firstDirectiveLine(_ source: String) -> String; public static func isNative(_ source: String) -> Bool; public static func stripPreamble(_ source: String) -> String }
```
- `stripPreamble` removes blank lines, `%%` comments and `%%{…}%%` directive lines before the first directive line, keeping a front-matter block for rule 1 (C-06.1 rule 0).
- `MDVMermaidPipeline.sanitize` calls it first.

### 3.5 `mdv6/Core/RawHTMLImages.swift` — NEW, ~120
```swift
public struct HTMLImageSpec: Hashable, Sendable { public static let scheme = "mdv6-img"; public let src, alt: String; public let width, height: CGFloat?; public var url: String; public init?(url: URL); public func displaySize(natural: CGSize) -> CGSize; public func resolvedURL(baseURL: URL?) -> URL }
public enum RawHTMLImages { public static func rewrite(_ block: String) -> String; public static func stripTags(_ s: String) -> String }
```
- Code spans are tracked exactly as C-07.1 does.
- A quoted `>` does not end the tag (F-171).
- `px` is stripped; a value that is not a positive number is treated as absent.
- base64url is shared with `MathSpec`.

### 3.6 `Sections.swift` — EDIT (+~5)
Step (0), `RawHTMLImages.stripTags`, runs before the trailing-`#` step (C-12).

### 3.7 `mdv6/Core/FindBlockStyle.swift` — NEW, ~50
```swift
public struct FindBlockStyle: Equatable { public let size: CGFloat; public let colorRole: ColorRole; public let weight: FontWeightRole; public let lineSpacing: CGFloat; public let bottomPadding: CGFloat; public let rule: Bool; public let codeSize: CGFloat }
public static func style(forBlock block: String, theme: MDVTheme, zoom: CGFloat) -> FindBlockStyle
```
It implements C-09.1's table verbatim. Roles, not colours, keep the function pure.

### 3.8 `mdv6/Core/ScrollKeys.swift` — NEW (math only), ~40
```swift
public enum ScrollKey { case down, up, pageDown, pageUp, space, home, end }
public enum ScrollKeys { public static let lineStep: CGFloat = 40; public static let pageFraction: CGFloat = 0.875; public static let endRetries = 10; public static func key(keyCode: UInt16, shift: Bool) -> ScrollKey?; public static func target(_ k: ScrollKey, y: CGFloat, usable: CGFloat, documentHeight: CGFloat) -> CGFloat }
```

### 3.9 `HistoryStep`, `PrintScale` — in `ScrollKeys.swift` and a new `PrintScale.swift`, ~30
```swift
public enum HistoryStep { public static func target(current: Int?, offset: Int, count: Int) -> Int? }
public enum PrintScale { public static let margin: CGFloat = 54; public static func sp(contentWidth: CGFloat, articleMaxWidth: CGFloat?) -> CGFloat; public static func diagramWidth(contentWidth: CGFloat, sp: CGFloat) -> CGFloat; public static func layoutWidth(diagramWidth: CGFloat, sp: CGFloat) -> CGFloat }
```

## 4. Work items, in order (red → green → refactor)

- **W10-01 — frontmatter recognition and rows.**
  - *Red:* `FrontmatterTests.testRecognition` over the four fixtures; the `http://x` colon case; the indented `  ---`; a TOML array closing at column 0; `---\n# Title\n---` → nil; CRLF equals LF. `testRows` asserts the rows of `frontmatter.md` (title, date, summary folded to one paragraph, tags sequence, nested metadata) and quote stripping. Neither compiles yet.
  - *Green:* §3.1.
  - *Evidence:* the filter exits 0.
- **W10-02 — C-02 rule 9 and the BOM.**
  - *Red:* `SplitTests.testFrontmatterBlockZero`: a header with an internal blank line is one block; `blockLines[0]`; the body's `blockLines` are whole-document lines; `frontmatter` is non-nil only with a header; a BOM copy equals the plain copy.
  - *Green:* §3.2, and `DocumentSession`'s decode helper calls `stripBOM`.
- **W10-03 — the diff classifier.**
  - *Red:* `DiffClassifyTests` over `diff.md`'s hunks: `--- stale comment` inside a hunk is `.removed`; `@@ -1 +1 @@` counts (1,1); `@@ x y @@` is meta; a header-less snippet colours `+`/`-`; a context line reduced to empty is context.
  - *Green:* §3.3.
- **W10-04 — dispatch and rule 0.**
  - *Red:* `MermaidDispatchTests` over the T-54 unit list (`graph`, `graph\tLR`, `graphfoo`, `flowchart-elk`, `stateDiagram-v2`, `xychart-beta`, multi-line `%%{…}%%`, empty); `stripPreamble` removes exactly the lines `firstDirectiveLine` skipped.
  - *Green:* §3.4, and `sanitize` edited.
  - *Evidence:* the existing `MermaidSanitizeTests` stay green.
- **W10-05 — `<img>` rewrite, size, and C-12 step (0).**
  - *Red:* `RawHTMLImagesTests` over E-35's cases; the quoted `>`; code spans kept; the URL round trip; `displaySize` for 4 combinations plus natural < cap; `stripInlineMarkdown("Logo <img src=x width=20>") == "Logo"`; `BookmarkTitle` and TOC text for that heading.
  - *Green:* §3.5 and §3.6.
- **W10-06 — find style.**
  - *Red:* `FindStyleTests`: $\ell = 1\dots6$ and body under `high-contrast` and `sevilla` at zoom 1.25; sizes are `round(base·s·e)`; h6 uses `tertiaryText`; h1/h2 bottom padding is 0.3 × size.
  - *Green:* §3.7.
- **W10-07 — the formulas.**
  - *Red:* `V014FormulaTests`:
    - K-18 at y = 0 / mid / bottom, `usable` = 10 → page = 40;
    - R-48 clamps (0 → −1 = nil, last → +1 = nil, current nil → nil);
    - $s_p(504, 860) = 0.586\ldots$, $s_p(504, \text{nil}) = 1$;
    - $w_d$, $w_\ell$ with the degenerate width → 1.
  - *Green:* §3.8 and §3.9.

## 5. Test plan

| File | Spec ids | Asserted | Runs |
|---|---|---|---|
| `Tests/mdv6Tests/FrontmatterTests.swift` | C-20, E-32, T-52 | recognition, rows, zero-row rule | `swift test --filter FrontmatterTests` |
| `SplitTests.swift` (+) | C-02, R-04, I-018, T-52 | rule 9 split, BOM | `--filter SplitTests` |
| `DiffClassifyTests.swift` | C-05, R-50, T-58 | C-05.1 kinds | `--filter DiffClassifyTests` |
| `MermaidDispatchTests.swift` | C-06, R-46, T-54 | C-06.4, rule 0 | `--filter MermaidDispatchTests` |
| `RawHTMLImagesTests.swift` | C-22, E-35, C-12, T-59 | rewrite, size, strip | `--filter RawHTMLImagesTests` |
| `FindStyleTests.swift` | C-09, R-24, T-60 | C-09.1 table | `--filter FindStyleTests` |
| `V014FormulaTests.swift` | K-18, R-48, K-17, C-21, T-56, T-57 | formulas + degenerate cases | `--filter V014FormulaTests` |

## 6. Gate: commands and expected results

1. `swift build` — expected exit 0, no new warnings.
2. `swift test --filter "FrontmatterTests|SplitTests|DiffClassifyTests|MermaidDispatchTests|RawHTMLImagesTests|FindStyleTests|V014FormulaTests|TypographyTests|MermaidSanitizeTests|MiscContractTests"` — expected exit 0.
3. `swift test --parallel --xunit-output junit.xml` — expected exit 0, ≥ 173 + new tests, 0 failures.

## 7. Traceability

| Spec id | file.symbol | test | status now → after |
|---|---|---|---|
| C-20 | `Frontmatter.frontmatterSpan/Rows` | FrontmatterTests | *not yet realised* → realised (view half W11) |
| C-02 rule 9, R-04 BOM | `ParsedDocument.init`, `stripBOM` | SplitTests | → realised |
| E-32 | `frontmatterSpan` | FrontmatterTests | → realised |
| C-05.1 classify | `DiffHighlighter.classify` | DiffClassifyTests | → half (render W11) |
| C-06.4, C-06.1 rule 0 | `MermaidDispatch` | MermaidDispatchTests | → realised (used W13) |
| C-22.1/.2, E-35 | `RawHTMLImages`, `HTMLImageSpec` | RawHTMLImagesTests | → half (providers W11) |
| C-12 step (0) | `stripInlineMarkdown` | RawHTMLImagesTests | → realised |
| C-09.1 | `FindBlockStyle` | FindStyleTests | → half (view W11) |
| K-18, R-48, C-21.1 | `ScrollKeys`, `HistoryStep`, `PrintScale` | V014FormulaTests | → half (W12, W14) |

## 8. Risks and traps

- **Failure (4), reach** (`IMPLEMENTATION_PLAN.md` §II.6). Rows citing the edited functions:
  - `stripInlineMarkdown` is cited by C-02 rule 7, C-12, R-21, R-27 and C-11 (slug text). W10-05 therefore tests the TOC text, the bookmark title and the slug of an `<img>` heading.
  - `sanitize` is cited by C-06.1 and E-14/E-15; its existing tests must stay green.
  - `ParsedDocument.split` is cited by C-19/E-31 (`blockLines`). `LineCitationTests` must stay green, and one new case cites `#L2` into a header.
- **Failure (5), oracle.** Each test's fixture is read from `test-docs/`, and the expected rows are written by reading the fixture, not from memory of the original.
- **Clean room.** No file is written from the original's source (§II.7 fork). The fixtures are shared, which the spec permits.

## 9. Exit criteria and handoff

- **Frozen for W11–W14:** `frontmatterSpan(in:)`, `frontmatterRows(_:)`, `FrontmatterRow`, `ParsedDocument.frontmatter`, `ParsedDocument.stripBOM(_:)`, `DiffHighlighter.classify(_:)`, `DiffLineKind`, `MermaidDispatch.isNative(_:)`, `.stripPreamble(_:)`, `RawHTMLImages.rewrite(_:)`, `HTMLImageSpec(url:)`, `.displaySize(natural:)`, `.resolvedURL(baseURL:)`, `FindBlockStyle.style(forBlock:theme:zoom:)`, `ScrollKeys.key/target`, `HistoryStep.target`, `PrintScale.sp/diagramWidth/layoutWidth`.
- **Re-run gate for the next wave:** item 3 above.
