# Detailed implementation plan — W3: Trust boundary and renderers

> - **Wave:** W3 of W0–W7 (`IMPLEMENTATION_PLAN.md` §4 item 4 — "Trust boundary and renderers").
> - **Spec basis:** `SPEC.md` v0.11, sha256 `eb28cfebe7456a5cfc05dca8df743dc1d2457514c68115a2b85334717437f897`; `TYPOGRAPHY.md`, sha256 `e3a6b1a4882106f26dc9a9dfe5f34ed6a5f41e4e62a60f16edf08cd0d28e52ad`. Neither is edited by this wave.
> - **Gate:** `swift test --filter mdv6RenderTests.RenderPipelineTests` exit 0; every parser entry is preceded by a `ContentLimits` check proven by a counting hook; the local HTTP-server test of C-16 green.
> - **Budget:** 1,500–1,900 production lines across 7–8 files (`IMPLEMENTATION_PLAN.md` §5 row "Renderers and trust boundary").
> - **Depends on:** W1 (`ContentLimits`, `MathSymbols.preprocess`, `MathSpec`, `MDVMermaidPipeline.sanitize`, `CodeLanguage`, `MDVTheme`, `CodePalette`, `RenderMetrics`, `ColumnWidth`), W0 (`CGrammars`, queries, `Vendor/SwiftMath`). **Unlocks:** W4 (`ArticleBlockView` composes these), W5 (image gating preference).

## 1. Objective and spec obligations

| spec id | obligation | how discharged |
|---|---|---|
| R-08, C-05, K-05, R-38, T-06, T-37 | tree-sitter highlighting for eleven languages, plain fallback, cache, fence size 0.85 × base × zoom | `CodeRenderer.render`; capture-class tests on `swift`/`sql`/nine others |
| R-12, R-14, C-07.2, E-10, I-008, K-08, K-15 (bake) | typeset via SwiftMath after registration + rewrites; bitmap-backed; fallback source + message; 2048 cache | `MathImageCache.rendered(for:)`, `MathSymbols.registerAll()`; T-07 render clauses |
| R-10, R-11, R-15, C-06 (.2, .3), E-01, E-02, E-13, I-005, I-009, K-07, K-08 | prepare/repair/layout, rasterize upright at width×scale, displaySize shared, math nodes, sequence repairs, caches 96/192/192 MB | `MDVMermaidPipeline.prepare/rasterize/displaySize`, `MermaidRepairs`, `MermaidMathNodes`; T-14, T-15, T-16, T-19, T-20, T-17 (pipeline half) |
| R-16, R-41, C-16, K-14, E-11, E-28, I-001..I-003, T-41 | ephemeral header-free GET, ≤5 http(s) redirects, 15/30 s timeouts, 32 MiB stream cut, image/* + ImageIO within K-14; local/data decoding within K-14; no disk | `ImageLoading.swift` (`RemoteImageLoader`, `ImageDecoding`); recording-server test |
| R-36, I-002 | no termination on admitted content; limits before parsers | the counting hook `PipelineProbe` asserts limit-check-before-parse |
| C-14 (renderer half) | fallbacks are values, never throws to the caller | `CodeRenderer` never throws; `MathResult`/`MermaidResult` enums carry `.fallback(source, message)` |

## 2. Entry preconditions

W2 gate green. `CGrammars` links all eleven `tree_sitter_*` symbols (W0 evidence). `mdv6/Queries/*-highlights.scm` present. `Vendor/SwiftMath` patched (`MTFont.fontBundle` resolution order, public `MTMathAtom.init`, `MTBoxed`). `Tests/mdv6RenderTests/RenderPipelineTests.swift` stub.

## 3. Deliverables (all `mdv6/Core/`)

### 3.1 `CodeRenderer.swift` — NEW, ~220 lines
`public final class CodeRenderer { public static let shared; public func render(code: String, languageHint: String?, theme: MDVTheme, zoom: CGFloat) -> AttributedString }` — resolve via `CodeLanguage.resolve`; `Language(language: tree_sitter_x())`, `Query(language:data:)` from `Bundle.module` `Queries/<lang>-highlights.scm` (compile failure → `plainForSession.insert(lang)`); fresh `Parser` per call; `QueryCursor` over the root; colour per capture through `CodePalette.color(forCapture:)` by dotted-name components (`keyword.function` → `keyword`), `comment` italic; monospace at `0.85 * theme.baseFontSize * zoom`; cache key `(lang, theme.id, zoom, code.hashValue)`, 256 entries flushed whole; plain path = same font, `theme.text`.

### 3.2 `MathImageCache.swift` — NEW, ~200 lines
```swift
public enum MathResult { case image(NSImage, ascent: CGFloat, descent: CGFloat); case fallback(source: String, message: String?) }
public final class MathImageCache { public static let shared; public func rendered(for spec: MathSpec, scale: CGFloat) -> MathResult
    public func typeset(_ spec: MathSpec, scale: CGFloat) -> MathResult   // ContentLimits.latexBytes first → .fallback(source, "input exceeds limit")
    public func bake(_ image: MTImage, scale: CGFloat) -> NSImage }         // NSBitmapImageRep-backed NSImage (I-008)
```
Registers `MathSymbols.registeredSymbols` once through `MTMathAtomFactory` (the public-init patch), applies `MathSymbols.preprocess`, `MathImage(latex:fontSize:textColor:labelMode:)` `.text`/`.display` by `spec.display`; error → `.fallback(source: "$…$", message: error.localizedDescription)`; 2048-entry cache keyed by the URL string; `SwiftMath` font lookups print their own lines (R-35 permits).

### 3.3 `MDVMermaidPipeline.swift` — EDIT (adds the rendering half), ~380 lines added
```swift
public struct DiagramTheme… (BeautifulMermaid's) ; public enum MermaidStyle: String, CaseIterable { document, light, dark, tokyoNight, catppuccin }
public struct MDVMermaidPrepared { let positioned: PositionedGraph; let naturalSize: CGSize; let theme: DiagramTheme; let mathNodes: [MathNodePlan]; let sequenceRepairs: SequenceRepairPlan? }
public enum MermaidPrepareError: Error { case exceedsLimit, unsupported(String), parse(String) }
public static func prepare(source: String, theme: DiagramTheme) throws -> MDVMermaidPrepared   // ContentLimits.mermaidBytes → sanitize → MermaidRenderer.parse → repairs → GraphLayout → post-layout repairs
public static func displaySize(for p: MDVMermaidPrepared, width: CGFloat) -> CGSize              // whole points, ≤ natural
public static func rasterize(_ p: MDVMermaidPrepared, width: CGFloat, scale: CGFloat) -> NSImage? // CGContext flipped, DiagramRenderer.render, math composited, upright
public static func documentTheme(from t: MDVTheme) -> DiagramTheme                               // C-06.3 mixes
public static func theme(for style: MermaidStyle, document: MDVTheme) -> DiagramTheme
public final class MermaidCaches { layouts (96), rasters (192, ≤ 192 MB) keyed (source hash, style, width, zoom, scale) }
```
C-06.2 repairs in `MermaidRepairs.swift` (~250 lines): subgraph last-owner normalisation on the parsed flowchart/state payload before layout (E-01); state `classDef`/`class`/`style` application; sequence `<br>` handling (notes → newline, actors → space, messages blanked and redrawn stacked upward 13 pt pitch / 11 pt / muted), actor-gap widening (+24, self +36) with piecewise-linear x remap, multi-line row growth $(n-1)\times 13 + 4$, note enclosure +8, autonumber discs $r=8$. `MermaidMathNodes.swift` (~120 lines): whole-label `$$…$$` node → blank placeholder sized to the math image (16 pt, `MathImageCache`), composited centred at a pixel-snapped origin; mixed/edge labels → `MathMarkdown.plainText`. Unsupported types (`timeline gantt pie mindmap gitGraph journey quadrantChart`) and any parse error → `MermaidPrepareError` (the view shows E-02's fallback text).

### 3.4 `ImageLoading.swift` — NEW, ~260 lines
```swift
public enum ImageLoadResult { case image(NSImage); case blocked; case notFound(name: String); case failed(reason: String) }
public enum ImageDecoding { public static func decode(data: Data) -> ImageLoadResult   // ContentLimits.encodedImageBytes; CGImageSource properties → axis ≤ 16384, pixels ≤ 64 M, bytes ≤ 256 MiB before creating the image
                             public static func local(url: URL, base: URL) -> ImageLoadResult; public static func dataURI(_ url: URL) -> ImageLoadResult }
public final class RemoteImageLoader { public init(); public func load(_ url: URL) async -> ImageLoadResult; public func cancelAll()
    // URLSession(configuration: .ephemeral) with urlCache nil, httpCookieStorage nil, httpShouldSetCookies false, urlCredentialStorage nil,
    // timeoutIntervalForRequest 15, timeoutIntervalForResource 30; delegate: redirect count ≤ 5 and http/https only, else cancel;
    // GET with no Cookie/Authorization/Referer; body streamed via URLSessionDataDelegate, cancelled past 32 MiB; 2xx + image/* required; ImageDecoding.decode
}
```
No response body is written anywhere; partial data discarded on cancel.

### 3.5 `PipelineProbe.swift` — NEW, ~30 lines
`public enum PipelineProbe { public static var onParserEntry: ((String) -> Void)? }` — called immediately before `MermaidRenderer.parse`, `MathImage.asImage`, `CGImageSourceCreateImageAtIndex`, and `Parser.parse`; tests count calls to prove "not invoked" for oversized inputs (T-41). Production leaves it nil.

## 4. Work items, in order

- **W3-01** `testAllGrammarsLoad` (eleven `Language`s and eleven queries compile) → `CodeRenderer` language table.
- **W3-02** `testHighlightCaptureClasses_*` (T-37: `swift` block with `struct`, `@Published`, `guard let`, interpolation, `// MARK:`; `sql` with `CREATE TABLE`, `SELECT … JOIN … WHERE 'lit'`, `-- comment`; keywords/strings/comments/numbers/types/functions each get a colour ≠ `theme.text`; `postgresql` == `sql` output; nine other languages produce ≥ 2 distinct colours; `brainfuck` is uniform plain) → highlighting.
- **W3-03** `testCodeFontFollowsZoom`, `testCodeCacheFlushesAt256` → font size, cache.
- **W3-04** `testMathTypesets_*` (inline `.text` vs display `.display` heights differ; `\boxed`, `\gtrsim`, `\operatorname{sin}`, `\dfrac`, `align*`; result is `NSBitmapImageRep`-backed) and `testMathFallback_*` (`\unknowncmd` → `.fallback` with message; over 64 KiB → "input exceeds limit" with zero `PipelineProbe` parser entries) → `MathImageCache`.
- **W3-05** `testMermaidPrepare_*` (T-14 E-01 diagram lays out with `PD` in the last subgraph and no crash; T-15 sanitised diagram renders; T-16 xychart two series; T-20 state descriptions + classDef colours in `nodeStyles`; `timeline`/`gantt`/`pie`/`mindmap` → `.unsupported`; over 1 MiB → `.exceedsLimit` with zero parser entries) → `prepare` + `MermaidRepairs`.
- **W3-06** `testDisplaySizeAndRaster_*` (raster pixel size == `displaySize × scale` exactly; never wider than natural; width 1 → 1 pt raster; upright orientation by checking a known dark pixel at the top) → `displaySize/rasterize`, I-005.
- **W3-07** `testSequenceRepairs_*` (T-19 geometry: label never crosses an unspanned lifeline; three-line row is 30 pt taller; final note enclosed; autonumber discs 1…n present as circles at arrow tails — asserted on the repaired `PositionedGraph`, not pixels) → sequence repairs.
- **W3-08** `testMermaidMathNode_*` (T-17 pipeline half: whole-`$$` label plan created at 16 pt; mixed label → Unicode; §7.1 `ink` of the node crop ≥ 0.9 × document crop at same size and 2×) → `MermaidMathNodes`.
- **W3-09** `testImageDecoding_*` (T-41: PNG at 16384 px axis admitted, 16385 rejected without `CGImageSourceCreateImageAtIndex`; compressed 32 MiB admitted, +1 rejected; pixel and byte ceilings) → `ImageDecoding`.
- **W3-10** `testRemoteLoader_*` (local `NWListener`/`URLSession`-independent socket server in the test: off → no request; on → one `GET` with no Cookie/Authorization/Referer headers; five redirects followed, sixth rejected; `ftp:` redirect rejected; non-image type rejected; body over 32 MiB cancelled before completion; `cancelAll` aborts an in-flight load; no file written under the temp support dir) → `RemoteImageLoader`.

## 5. Test plan

| target file | spec ids | asserted | runs |
|---|---|---|---|
| `Tests/mdv6RenderTests/RenderPipelineTests.swift` (may split into `CodeRendererTests`, `MathTests`, `MermaidTests`, `ImageLoadingTests`) | R-08, R-10, R-11, R-12, R-14, R-15, R-16, R-36, R-38, R-41, C-05, C-06, C-07, C-14, C-16, I-001, I-002, I-003, I-005, I-008, I-009, K-05, K-07, K-08, K-14, E-01, E-02, E-10, E-11, E-13, E-14, E-15, E-28, T-06, T-07, T-14, T-15, T-16, T-17, T-19, T-20, T-37, T-41 | §4 outcomes | `swift test --filter mdv6RenderTests` |

## 6. Gate

1. `swift test --filter mdv6RenderTests --xunit-output junit.xml` — exit 0, 0 skipped, no crash report under `~/Library/Logs/DiagnosticReports/mdv6*` newer than the run start.
2. `swift test --xunit-output junit.xml` (whole suite) — exit 0.
3. `speccheck … --judge mock` — 0 dangling, 0 stale; §1 ids `PASSING`.
4. `grep -n "PipelineProbe.onParserEntry?(" mdv6/Core/*.swift` — four call sites, each on the line before its parser call.

## 7. Traceability

§1 ids: not yet realised → realised (pipeline half); T-13/T-17/T-19 harness invocations → W4; R-16 menu toggle → W6; R-09 chrome → W4.

## 8. Risks and traps

- **ELK `assert` on shared subgraph nodes (E-01)** aborts the process, not the test — the ownership repair runs on the parsed payload before `GraphLayout`; W3-05 is the guard.
- **SwiftMath registration is process-global**; register once (`dispatch_once` style) or duplicate-symbol assertions fire.
- **`NSImage` drawing handlers** violate I-008: `bake` must produce an `NSBitmapImageRep`.
- **BeautifulMermaid draws in a top-left coordinate system**; `rasterize` flips the CGContext (its `ImageRenderer.swift` documents this) — W3-06's orientation assertion catches an upside-down raster.
- **Rule (§6 "parser before ceiling"):** the four `PipelineProbe` sites are the check; the gate greps for them.

## 9. Exit criteria and handoff contract

Frozen: `CodeRenderer.render(code:languageHint:theme:zoom:)`, `MathImageCache.rendered(for:scale:)`, `MDVMermaidPipeline.prepare/displaySize/rasterize/documentTheme/theme(for:document:)`, `MermaidStyle`, `MermaidCaches`, `ImageDecoding.*`, `RemoteImageLoader.load/cancelAll`, `ImageLoadResult`, `PipelineProbe`. Next wave re-runs `swift test` (expected exit 0).
