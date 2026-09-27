# Detailed implementation plan — W14: printing

> - **Wave:** W14 of W10–W15 (`IMPLEMENTATION_PLAN.md` §II.4 "W14 — printing").
> - **Spec basis:** `SPEC.md` v0.14.4, sha256 `2c193583…9fdc`. Not edited.
> - **Gate:** `PrintController.renderPDF` produces the C-21 output, and T-53's eight scripted assertions pass on their named fixtures through the harness's `--print-pdf` JSON.
> - **Budget:** 450–700 production code lines (harness +30).
> - **Depends on:** W10 (`PrintScale`), W11 (`markdownResolvedInlineImages`, `FrontmatterTableView(paddingScale:)`, `CodeBlockChrome`), W12 (`AppCommand.print`, `targetSession`), W13 (`MermaidWebRenderer.pdf`). **Unlocks:** W15.

## 1. Objective and spec obligations

| Spec id | Obligation | Discharge |
|---|---|---|
| C-17, T-53 (apparatus) | `--print-pdf` with per-block JSON (`index`, `kind`, `page`, `rect`, `images`, `formulas`); `.mmd` input | `PrintController.renderPDF`; harness `main.swift` |
| C-21.1, K-17, I-017 | 54 pt margins, header and footer, $s_p$, fixed `high-contrast`, smart typography from the print theme, zoom ignored | `PrintController.makePrintInfo`, `Request` |
| C-21.2 | one vector PDF per block; gap = $s_p$ × screen gap under the print theme; code wrapped; no remote fetch | `renderBlockPDF`, `PrintBlockView` |
| C-21.3 | native PDF / web PDF (never ordered front) / raster fallbacks / `text` retag | `preRender` |
| C-21.4, R-45 | vector standalone and accepted inline formulas; rejected spans print their fallback | `formulaPage`, slot overlay |
| C-21.5 | `adjustPageHeightNew`, `heightAdjustLimit` 0.9 | `PrintContainerView` |
| C-21.6, E-33, R-45 | frontmatter table or nothing; sheet; main-queue presentation; second ⌘P beeps; ⌘P in `EMPTY` or with no blocks beeps | `printDocument`, the menu |

## 2. Entry preconditions

- W10–W13 frozen symbols.
- The fixtures `rhythm.md`, `math.md`, `syntax.md`, `frontmatter.md` and `test-docs/mermaid/*.mmd`.

## 3. Deliverables

### 3.1 `mdv6/Core/PrintController.swift` — NEW, ~450–650

It may be split into `PrintController.swift`, `PrintOverlay.swift` and `PrintContainerView.swift` if it passes 400 lines.

```swift
public struct PrintRequest { public let document: ParsedDocument; public let baseURL: URL?; public let smartTypography: Bool; public let showFrontmatter: Bool; public let mermaidStyle: MermaidStyle; public let jobTitle: String }
public struct PrintBlockRecord: Codable { public let index: Int; public let kind: String; public let page: Int; public let rect: [CGFloat]; public let images: [ImageRecord]; public let formulas: [[CGFloat]] }
@MainActor public enum PrintController {
  public static func renderPDF(_ r: PrintRequest, paper: CGSize) async -> (pdf: Data, blocks: [PrintBlockRecord])
  public static func printDocument(_ r: PrintRequest, window: NSWindow?)   // panel
}
final class PrintContainerView: NSView   // flipped; draw(_:); adjustPageHeightNew; heightAdjustLimit 0.9; printJobTitle
```

- `renderPDF` paginates through `NSPrintOperation.pdfOperation` with the same print info, so pagination is AppKit's in both paths.
- The block records are computed from the container frames and AppKit's page breaks, read back through `knowsPageRange` / `rectForPage`.

### 3.2 `tools/render-harness/Sources/render-harness/main.swift` (+~30)

`--print-pdf FILE [--paper letter|a4]`: `.md` or wrapped `.mmd`, JSON per block on stdout, exits 0 / 1 / 2 (C-17).

### 3.3 Menu

`mdv6App`'s *Print…* slot calls `printDocument` for `targetSession`, and beeps in the E-33 cases.

## 4. Work items

- **W14-01 — oracle first, run on the unmodified fixtures (failure 5).**
  - *Red:* `PrintTests` with T-53's eight assertions written against `renderPDF`. They are expected to fail to compile. A throwaway spike against `rhythm.md` then confirms that the oracles (token order, formula-rect/image intersection, one page per short block) hold for a hand-built two-page PDF, so the oracle, not the fixture, is under test.
  - *Green:* the `renderPDF` skeleton, plus `PrintContainerView` with plain Markdown blocks.
  - *Evidence:* (1), (3) and (5) pass.
- **W14-02 — rhythm.**
  - *Red:* T-53 (4) on `rhythm.md`: each gap equals $s_p \times$ `ArticleBlockView.blockInset(theme: .highContrast, …)` within 1 pt.
  - *Green:* the gap.
- **W14-03 — formulas.**
  - *Red:* T-53 (2) and (2b) on `math.md`.
  - *Green:* `formulaPage`, then the slot overlay (placeholders, the content-stream scanner, draw), then the fallback layout.
- **W14-04 — diagrams.**
  - *Red:* T-53 (6) on the native `.mmd` fixtures.
  - *Green:* the native PDF path and the raster fallback, then the web PDF path through `MermaidWebRenderer.pdf`, then the `text` retag.
- **W14-05 — frontmatter and independence.**
  - *Red:* T-53 (7) and (8).
  - *Green:* the table or nothing; the request excludes screen state.
- **W14-06 — the panel and the harness.**
  - *Red:* `HarnessTests.testPrintPDF`: exit 0 and one JSON object per block.
  - *Green:* `printDocument`, the menu, the E-33 beeps, and §3.2.

## 5. Test plan

| File | Spec ids | Runs |
|---|---|---|
| `Tests/mdv6RenderTests/PrintTests.swift` | R-45, C-21, I-017, K-17, E-33, T-53 | `--filter PrintTests` |
| `HarnessTests.swift` (+) | C-17, T-53 | `--filter HarnessTests` |

## 6. Gate

1. `swift test --filter "PrintTests|HarnessTests"` → exit 0.
2. `swift run --package-path tools/render-harness render-harness test-docs/math.md --print-pdf "$TMPDIR/m.pdf"` → exit 0, with one JSON line per block of `math.md`.
3. `grep -rn MDV_PRINT_TEST mdv6 App tools` → no output (exit 1).
4. `swift test --parallel --xunit-output junit.xml` → exit 0.

## 7. Traceability

| Spec id | symbol | test | status |
|---|---|---|---|
| R-45, C-21, E-33 | `PrintController`, `PrintContainerView` | PrintTests | *not yet realised* → realised (panel observed W15) |
| I-017, K-17 | `PrintRequest`, `PrintScale` | PrintTests (8) | → realised |
| C-17 `--print-pdf` | harness | HarnessTests | → realised |

## 8. Traps

- **`ImageRenderer` runs no `.task`**, so inline images must be supplied through the W11 hook, or they print as nothing.
- **A `CGPDFPage` does not retain its document.** Keep the documents alive with their pages.
- **The final partial page:** AppKit's limit can exceed the bottom, so clamp last (C-21.5).
- **Present the panel from `DispatchQueue.main.async`**, not from inside the pre-render `Task` (C-21.6).
- **The web path in `swift test`** needs a window server. `PrintTests` skip the web clause with a recorded reason when `NSScreen.screens` is empty. The harness reports web diagrams as source (C-17).
- **Reach.** `blockInset` is cited by I-014, C-18.10, K-16 and T-45, so it is called, not copied.

## 9. Exit and handoff

- **Frozen:** `PrintController.renderPDF`, `.printDocument`.
- **Re-run gate:** item 4 above.
