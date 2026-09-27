# Detailed implementation plan — W13: the Mermaid web path

> - **Wave:** W13 of W10–W15 (`IMPLEMENTATION_PLAN.md` §II.4 "W13 — the Mermaid web path").
> - **Spec basis:** `SPEC.md` v0.14.4, sha256 `2c193583…9fdc`. Not edited.
> - **Gate:** web-dispatched diagrams render in a `WKWebView` that can load nothing but its page; the build fetches and verifies the pinned script; the harness reports `web`.
> - **Budget:** 300–450 production code lines; `build.sh` +30.
> - **Depends on:** W10 (`MermaidDispatch`), W3 (`MermaidCodeBlockChrome`, `MDVMermaidDiagramView`, `MermaidFallbackView`), W4 (harness). **Unlocks:** W14 (`MermaidWebRenderer.pdf(source:theme:width:)`).

## 1. Objective and spec obligations

| Spec id | Obligation | Discharge |
|---|---|---|
| C-13, C-01, K-19, R-34 | fetch 11.4.1 when absent; SHA-256 gate; bundle the script and its licence | `build.sh`, `.gitignore`, `Package.swift` resources |
| R-46, C-06.5, K-19 | the page, height report, 60 pt minimum, spinner, reload key, failure → fallback | `MermaidWebView` |
| C-06.5, I-001, I-003, D-46 | refuse every non-page load; `strict`; `logLevel: 'fatal'`; not inspectable; handler removed on dismantle | `MermaidWebView.makeNSView` / `dismantleNSView` |
| C-06.5 host integration (F-151) | block menu, not WebKit's; wheel to the article; no first responder; no selection | `MermaidWebView` subclass of `WKWebView` |
| R-09, R-10, E-02, E-34, K-07, R-11 | web path: no style menu, no export, no pinch; native failure not retried | `MermaidCodeBlockChrome`, `MDVMermaidDiagramView` |
| R-35 | no console forwarding | no `console` message handler; `logLevel` |
| C-17 | `--scan` status `web`; manifest `expect` values | `HarnessCases`, `render-cases.json` |
| T-54 (unit and render halves) | | §5 |

## 2. Entry preconditions

- W10's `MermaidDispatch`.
- `mdv6/mermaid.LICENSE.txt` (committed v0.14.2).
- Network access to jsDelivr for the first `build.sh`.
- `ImageLoadingTests`' recording HTTP server (W3), reused.

## 3. Deliverables

### 3.1 `build.sh` (+~30), `.gitignore`, `Package.swift`

- `build.sh`: `MERMAID_VERSION=11.4.1`, `MERMAID_SHA256=a43bc1af…`, a download to `.tmp` then a move, `verify` that prints both digests and exits 1, then copy the script and `mermaid.LICENSE.txt` to `Resources/` (C-13).
- `Package.swift`: `resources: [.copy("mermaid.min.js"), .copy("mermaid.LICENSE.txt")]`.
- `.gitignore`: `mdv6/mermaid.min.js`.

### 3.2 `mdv6/Core/MermaidWebView.swift` — NEW, ~250

```swift
public struct MermaidWebContainer: View { public init(source: String, theme: MDVTheme, onFailure: ...) }
final class LockedWebView: WKWebView  // menu(for:) → block menu; scrollWheel → nextResponder chain to the enclosing NSScrollView; acceptsFirstResponder false
public enum MermaidWebPage { public static func html(source: String, theme: MDVTheme, padded: Bool) -> String; public static var script: String? }
@MainActor public enum MermaidWebRenderer { public static func pdf(source: String, theme: MDVTheme, width: CGFloat) async -> (CGPDFDocument, CGPDFPage, CGSize)?; public static func image(...) async -> NSImage? }
```

Rules:

1. HTML-escape `&`, `<`, `>` (C-06.5).
2. Initialise with `securityLevel: 'strict'` and `logLevel: 'fatal'`.
3. Paint the background with `secondaryBackground` as CSS `rgb(…)`.
4. The height is the SVG height + 24, reported after two animation frames plus `ResizeObserver`; ignore reports within 0.5 pt; the minimum is 60.
5. Reload only when (source, theme id, `isDark`) changes.
6. `WKContentRuleList` blocking `.*`, compiled once and awaited before the first load, plus a navigation delegate that allows only the initial `about:blank` (I-001, D-46).
7. `isInspectable = false`.
8. Remove the handler in `dismantleNSView`.
9. The accessibility label is *Mermaid diagram*, with the hint as specified.

### 3.3 `MDVMermaidDiagramView.swift` (+~30)

- Route by `MermaidDispatch.isNative`.
- The chrome hides the style menu and export on the web path; its context menu keeps *Copy Code* and *Show Source*.

### 3.4 `HarnessCases.swift` (+~15), `test-docs/render-cases.json`

`--scan` gives a web-dispatched case status `web`, which counts as an expected result.

## 4. Work items

- **W13-01 — the build fetch.**
  - *Red:* `BuildAndLauncherTests.testMermaidScriptPinned` runs `build.sh`'s `verify` function on a corrupted copy in a temp directory; the expected exit is 1, with both digests in its output (C-13, T-54).
  - *Green:* §3.1.
- **W13-02 — the page and the trust boundary.**
  - *Red:*
    - `MermaidWebTests.testGanttRendersOffscreen`: `gantt.md`'s source in an offscreen `LockedWebView` reports a height > 60 within 5 s.
    - `testNoRequestsLeave`: a flowchart dispatched to web (`flowchart-elk`) with an `<img src="http://127.0.0.1:PORT/x.png">` label and a `click` line produces 0 requests at the recording server (I-001, I-003, E-34).
    - `testRejectsBadSource`: a broken gantt reports `ok: false`.
  - *Green:* §3.2.
- **W13-03 — host integration.**
  - *Red:* `MermaidWebTests.testHostIntegration`: `LockedWebView().acceptsFirstResponder == false`; `menu(for:)` returns the block menu titles; `scrollWheel` is forwarded (a stub superview records the event).
  - *Green:* the `LockedWebView` overrides.
- **W13-04 — dispatch in the views.**
  - *Red:* `MermaidTests.testWebPathChrome`: a gantt block's chrome item set has no style or export (R-09).
  - *Green:* §3.3.
- **W13-05 — harness status.**
  - *Red:* `HarnessTests.testScanReportsWeb`: with a gantt `.mmd` in a temp dir, the record says `web` and the exit is 0 (C-17).
  - *Green:* §3.4.

## 5. Test plan

| File | Spec ids | Runs |
|---|---|---|
| `Tests/mdv6RenderTests/MermaidWebTests.swift` | R-46, C-06, I-001, I-003, E-34, K-19, T-54 | `--filter MermaidWebTests` |
| `MermaidTests.swift` (+) | R-09, R-10, E-02, T-21, T-54 | `--filter MermaidTests` |
| `HarnessTests.swift` (+) | C-17, T-13 | `--filter HarnessTests` |
| `BuildAndLauncherTests.swift` (+) | C-13, R-34, C-01, T-01 | `--filter BuildAndLauncherTests` |

## 6. Gate

1. `rm -f mdv6/mermaid.min.js && ./build.sh debug` → exit 0; `shasum -a 256 build/mdv6.app/Contents/Resources/mermaid.min.js` shows `a43bc1af…`.
2. `swift test --filter "MermaidWebTests|MermaidTests|HarnessTests|BuildAndLauncherTests"` → exit 0.
3. `swift run --package-path tools/render-harness render-harness --scan test-docs/mermaid --output-dir "$TMPDIR/scan"` → exit 0.
4. `swift test --parallel --xunit-output junit.xml` → exit 0.

## 7. Traceability

| Spec id | symbol | test | status |
|---|---|---|---|
| R-46, C-06.5, K-19, E-34 | `MermaidWebView`, `LockedWebView`, `MermaidWebPage` | MermaidWebTests | → realised (observed W15) |
| C-13, C-01, R-34 | `build.sh` | BuildAndLauncherTests | → realised |
| R-09, R-10, E-02 | chrome, diagram view | MermaidTests | → realised |
| C-17 | `HarnessCases` | HarnessTests | → realised |
| I-001, I-003, R-35 | trust boundary | MermaidWebTests | → realised |

## 8. Traps

- **Content rule lists compile asynchronously.** The first page load must await the compiled list, or the first diagram can race it (the I-001 hole).
- **A `WKWebView` in a window that is never shown** may not run animation frames. The offscreen test uses a borderless window, and the page's poll fallback (three equal reads or 3 s) is included for the print variant.
- **Reach.** `MDVMermaidDiagramView` is cited by R-09, R-11, I-005 and K-07. Their tests stay green on native diagrams.
- **Clean room.** The page and handshake are written from C-06.5.

## 9. Exit and handoff

- **Frozen:** `MermaidWebRenderer.pdf(source:theme:width:)`, `.image(source:theme:width:displayWidth:density:)`, `MermaidWebPage.html(source:theme:padded:)`.
- **Re-run gate:** item 4 above.
