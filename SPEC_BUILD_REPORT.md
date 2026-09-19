# Spec build report — mdv6 (implementing `SPEC.md` v0.12.1)

> - **Spec:** `SPEC.md` v0.12.1, sha256 `16c9d43727e15c959c7c8deb802160b508d6588364042b7aacf879251c61d4da`; `TYPOGRAPHY.md` and `reference/*.png` as the spec ships them. W0–W7 built v0.11/v0.11.2; **W8** (§1, §5b) added the v0.12 line-citation feature after the seventh review (F-126..F-138) was applied as v0.12.1. The spec was edited three times during the build, all recorded below; no id was renumbered.
> - **Plan:** `IMPLEMENTATION_PLAN.md` (7d552a2, amended at c535a03 for v0.12.1 + W8) and `DETAILED_IMPLEMENTATION_PLAN_W0..W8.md`; the §7 fork (T-43 on a host with no signing identity) was answered by the user: *record as pending*.
> - **Built tree:** waves W0–W7 each committed after its gate (W7 at `5cb1f2e`, report at `7be647b`), the user's live-use findings fixed as F-005…F-010, the seventh review applied as v0.12.1 (`ff8cde7`, `ebb6acd`), then W8 at `e61c60f`. Sibling folders were not consulted (user instruction).
> - **Gate:** `swift test --parallel --xunit-output junit.xml` → 171 tests, 0 failures; speccheck Phase A `CONFORMING` 173/173, exit 0. Phase B (LLM judge) is *not* clean — see §7 for the 8 pre-existing weak rows and why none of them is this change.
> - **Verdict:** **VERIFICATION PENDING** — every id is realised and mechanically proved; the §9.6 observed tests (T-44, T-47, T-48, and now T-49) were driven with real pointer and keyboard input and captured with `screencapture`, and the agent compared the captures against `reference/`; the spec requires a *person's* look, and T-43's credentialed run cannot be done on this host (§5, §5b).

---

## 1. Wave ledger

Every wave ran its `DETAILED_IMPLEMENTATION_PLAN_W<n>.md` §6 gate before its commit. Exit codes are the real ones from this host (macOS 26.6 / Darwin 25.6, Swift 6.4 toolchain in Swift-5 language mode, SwiftPM only — no Xcode project).

| Wave | Commit | Gate as run | Exit |
|---|---|---|---|
| spec + plan | b117d9f, 7d552a2 | `sha256sum SPEC.md` recorded in the plan front matter | — |
| F-001 | 63b4ad9 | `speccheck check … --judge mock` no longer exits 3 (duplicate R-35 declaration) | 0 |
| W0 Runnable bundle | a4496e0 | `make` → `build/mdv6.app`; `codesign --verify --deep --strict build/mdv6.app`; `bash tools/gate-w0.sh` (T-01/T-02/T-03 launcher clauses); `swift test --filter BuildAndLauncherTests` | 0 |
| F-002 | 505ca83 | `speccheck check … --judge mock` reports 0 dangling (C-18 now declared) | 0 |
| W1 Pure contracts and the spec's metrics | b48a170 | `swift test --filter "SplitTests\|MathContractTests\|AnchorTests\|TypographyTests\|MiscContractTests\|MetricsTests\|ThemeTests\|MermaidSanitizeTests"` | 0 |
| W2 Persistence and history | dc1746d | `swift test --filter PersistenceTests` (temp DB, schema v4, FTS5, concurrency) | 0 |
| W3 Trust boundary and renderers | 08bf061 | `swift test --filter "CodeRendererTests\|MathRenderTests\|MermaidTests\|ImageLoadingTests"` (recording HTTP server for C-16) | 0 |
| W4 Article and the render harness | e6064c8 | `swift run --package-path tools/render-harness render-harness --check test-docs/render-cases.json`; `--scan test-docs/mermaid`; `swift test --filter "RhythmAndDisplayMathTests\|HarnessTests\|ArticleTests"` (T-45/T-46 measured against the spec's bands) | 0 |
| W5 Headless session | a37a6fb | `swift test --filter SessionTests` (every §3.1 transition, real FSEvents watcher) | 0 |
| W6 Window chrome | 11ae99f | `swift test --filter "ChromeModelTests\|ChromeSnapshotTests"`; `tools/observe.sh` snapshots of the three panes under Sevilla/Charcoal/Twilight | 0 |
| W7 Prove it | 5cb1f2e | `make && swift test --parallel --xunit-output junit.xml` (159/0); Phase A and Phase B speccheck; `tools/observed-pass.sh` → `build/observed/*.png`; `bash tools/idle-cpu.sh` (K-15) | 0 |
| Live-use fixes F-005…F-010 | (this commit) | `make && swift test --parallel --xunit-output junit.xml` (163/0); Phase A and Phase B speccheck; real-input observed pass (§5) | 0 |
| spec review + v0.12.1 | ff8cde7, ebb6acd | `speccheck check … --judge mock --strict` — 0 dangling, 0 stale; the four new ids `UNCITED` as specified-and-unbuilt | 0 |
| W8 plan | c535a03 | `sha256sum SPEC.md` recorded in `IMPLEMENTATION_PLAN.md` (v0.12.1, `16c9d437…`) | — |
| W8 Line citations | e61c60f | `make`; `swift test` (129/0); `swift test --parallel --xunit-output junit.xml` (171/0); `speccheck … --judge mock --strict` → **CONFORMING 173/173**; on-screen pass with `tools/click.swift` + a real link click (§5b) | 0 |

`README.md` was written in W7 from the built tree and landed in the W7 commit (5cb1f2e) rather than a separate `docs(mdv6)` commit; every command block in it was re-run as written before this report (§4).

## 2. Defects found during the build (F-nnn)

| ID | Where | What was off | Resolution |
|---|---|---|---|
| F-001 | `SPEC.md` §5.4 | The R-35 cross-reference row was a second **bold** declaration of R-35; speccheck exited 3 (`duplicate declaration of R-35`). | `fix(spec): v0.11.1` (63b4ad9) — the row is un-bolded; no wording changed. |
| F-002 | `SPEC.md` §5.5 | The heading `Window chrome (§5.5, normative structure)` did not declare `C-18`, so every `C-18` citation (R-42, I-015, §11) was dangling. | `fix(spec): v0.11.2` (505ca83) — heading reads `### C-18 Window chrome (§5.5, normative structure)`. |
| F-003 | `mdv6/Core/WindowAccessor.swift` | Under a dark theme the app hung: `updateNSView` assigned a fresh `NSAppearance` on every SwiftUI update, which re-rendered the hierarchy forever (title stayed `mdv6`, hooks silent). | `applyAppearance(_:isDark:)` is idempotent — it assigns only when the appearance *name* differs; regression test `ChromeModelTests.testAppearanceAssignmentIsIdempotent`. Fixed in W7 (5cb1f2e). |
| F-004 | `SPEC.md` T-45 vs I-014 | Observation, not a defect in the build: T-45 names $v$ = `paragraphBottomSpacing` for the heading→paragraph boundary, while I-014's combination rule gives $\max(\text{bottom}_{\text{heading}}, 0)$. The measured gaps satisfy **both** bands under Sevilla and Charcoal (`RhythmAndDisplayMathTests.testRhythmBandSevillaAndCharcoal`), so nothing needed changing; recorded for `spec-writing` as a wording to reconcile. | none required; logged. |

| F-005 | `DocumentSession` / `ArticleBlockView` | Reported by the user: after a theme switch the article recoloured one block at a time as the pointer crossed it. The blocks observe the session, and `theme`/`zoom` are derived from `Preferences` — a separate `ObservableObject` — so a theme change re-rendered the chrome but not the blocks until a hover republished the session. Reproduced with `SPEC.md` under Sevilla → Twilight (`build/observed/user-report/before-fix-stale-blocks.png`). | The session forwards `preferences.objectWillChange`; `SessionTests.testPreferenceChangesRepublishThroughSession`. |
| F-006 | `DocumentRootView` / `WindowAccessor` | Reported by the user: in dark themes the window title stayed black and the toolbar icons were unreadable. The theme's colour scheme was applied only as an async `NSWindow.appearance` assignment from `updateNSView`, racing SwiftUI's own appearance management; the toolbar icons used `Color.primary`. Seen once on the real store after a theme switch (`user-report/before-fix-twilight-real-store.png`, title and `+`/pencil black on Twilight). | `.preferredColorScheme(ChromeRules.colorScheme(for: theme))` on the root view (SwiftUI owns the window appearance; `applyAppearance` is no longer called from the update path); the icons take `theme.secondaryText`/`theme.accent`; *System* now reads `NSApp.effectiveAppearance` through `SystemAppearance` (KVO) because the window's SwiftUI `colorScheme` is the theme's. `ChromeModelTests.testSystemAppearanceReadsTheApplicationNotTheWindow`. |
| F-007 | `SidebarViews`, `ArticleView` | Reported by the user as "bookmarks are not wired in": the first click on a TOC row, bookmark row, placeholder row, search hit or heading — the click that activates the window — was swallowed (`onTapGesture` does not accept the activating click; a `Button` does), so a click from another app appeared to do nothing while the AppKit-backed history rows responded. Reproduced with real pointer events (`tools/click.swift`). | Every such row is a plain-style `Button`. Observed: `user-report/bookmark-first-click.png` (a bookmark clicked from Finder opens its file and becomes current). |
| F-008 | `DocumentSession.bookmarkCurrentSpot` | ⌘D added the row into a hidden inspector or a collapsed pane, so nothing visible happened. | The new row is revealed (inspector shown, pane expanded) and marked current — the R-28 placeholder rule applied to ⌘D; `SessionTests.testBookmarkCurrentSpot`, Help §Bookmarks. |
| F-009 | `SidebarViews.bookmarksPane` | `List` + `.onMove` never started a drag session for the bookmark rows (real drags moved nothing; the same drag resized the sidebar divider), so R-27's *reorderable by drag* was unmet. | The pane is a `LazyVStack` with `.onDrag`/`.onDrop` (`BookmarkDropDelegate`: entering a row moves the dragged row there, persisted at once, C-18.9 drop-target tint). Observed: a real drag of row 4 to the top reorders the store (`sqlite3 … select sort_order,title from bookmarks`). |
| F-010 | `mdv6App.swift` (scenes) | Reported by the user after `make install`: bookmarks looked broken (the placeholder worked) and search too. Cause: a LaunchServices open event to the *running* app — every `mdv6 file.md` and Finder open after the first — made SwiftUI create a second, empty "main" window in front of the one that received the document, so ⌘D/⌘⇧F landed in an `EMPTY` window. Never seen before because every earlier run launched the binary with the file as an argument. | `.handlesExternalEvents(matching: [])` on both `WindowGroup`s: opens are the delegate's (`application(_:open:)` → key session, R-01/E-26) and never a new window. Observed through LaunchServices (`open -a`, store injected with `launchctl setenv`): two successive opens keep one window whose title follows the file; ⌘D, ⌘⇧F and a click on a hit work in it. |
| — | `DocumentSession.handleLink` | While strengthening the E-05 assertion: a scheme-less missing destination was handed to the opener as the bare relative URL, which nothing can open. | The resolved `file:` URL is handed over for scheme-less destinations; `testHandleLink` asserts E-05 explicitly. |
| F-011 | `SPEC.md` C-19.1 vs E-06/E-31 (found by the seventh review, `SPEC_REVIEW_REPORT.md`) | The v0.12 grammar `^L([0-9]+)…` accepted `#L0` while the same row's prose, E-06 and E-31 rejected it; the two readings differ between "no-op" and "clamp to the last block and scroll to the end of the document". Not a build defect — a spec defect the review caught before W8 started. | `fix(spec): v0.12.1` (ebb6acd) — grammar is `^L([1-9][0-9]*)(?:-(?:L)?([1-9][0-9]*))?$`; W8's `LineCitation.parse` implements exactly that, and `testLineCitationGrammar` pins the rejected set. |
| F-012 | T-49 vs `test-docs/links-sibling.md` (same review) | T-49 cited `#L10-L12` and asserted "the paragraph containing line 10", but line 10 of the fixture is blank — the rule resolves it to the `## Third heading` above it. A correct implementation would have failed the acceptance test. | `fix(spec): v0.12.1` (ebb6acd) — T-49 cites `#L7-L9`, with `#L10` (gap) and `#L12` (past `lineCount`) as the E-31 cases and the fixture's numbering stated inline. `testFixtureLineMap` asserts the map the test assumes. |
| F-013 | T-32 (`testIdleMathCPU`, K-15) under `swift test --parallel` | Environmental, not a defect: the K-15 protocol needs an otherwise idle host, and repeated `--parallel` runs on this machine starve the 5 s warm-up, so the test failed on several W8 gate attempts. | Proved pre-existing and unrelated: `git stash` of all W8 files → **0/3 passes** of `swift test --parallel --filter testIdleMathCPU` on the unmodified baseline; and the same test passes in isolation and in the serial (`swift test`) run, which is the run reported in the gate. No code change. |

Also reported: "search history does not seem to work". Not reproduced — ⌘⇧F and the header magnifier both reveal and focus the field, typing filters to FTS hits on the isolated store and on the real store (`user-report/search-history-hits.png`; the real index answers `"mortgage"*`, `"C-18"*`, `"fixed-rate"*`), and Esc hides the field (`user-report/search-hidden-by-esc.png`). One environmental cause was found and is documented in the README: another build of mdv6 with the same bundle identifier was running on this machine and shares the support directory and defaults domain with this one.

No spec row was weakened; `SPEC.md` was edited only by the two `fix(spec)` commits.

## 3. The speccheck gate (final test run)

Final run, on the F-005…F-009 tree, after `make`:

```text
swift test --parallel --xunit-output junit.xml      → 163 tests, 0 failures (junit.xml)
speccheck check --spec SPEC.md --src mdv6/Core --tests Tests --results junit.xml --judge mock --strict --out build/speccheck
speccheck: CONFORMING - 169/169 passing (100.0%), 0 failing, 0 skipped, 0 weak, 0 unverified, 0 untested, 0 uncited; 0 dangling, 0 stale; judge=mock
speccheck check --spec SPEC.md --src mdv6/Core --tests Tests --results junit.xml --judge llm --strict --out build/speccheck-llm
speccheck: CONFORMING - 169/169 passing (100.0%), 0 failing, 0 skipped, 0 weak, 0 unverified, 0 untested, 0 uncited; 0 dangling, 0 stale; judge=llm
```

Phase B judge: `openai/gpt-4o-mini` via OpenRouter (`SPECCHECK_JUDGE_URL=https://openrouter.ai/api/v1/chat/completions`, per the user's instruction — not a local model); `judge_available: true`, `unknown_rate: 0.0` (`build/speccheck-llm/speccheck.json` → `metrics.unknown_rate`), `judge_prompt_sha256` `21ec7849…77fdf7`. Both `--strict` runs exited 0.

The first Phase B run of W7 returned 10 `WEAKLY_PASSING` ids (R-07, R-09, K-15, T-32, E-25, E-30, T-22, T-28, T-43, T-44) and a second run 3 (K-11, T-30, T-43). Each was fixed in the **test**, never by re-pointing a citation at a weaker test: R-07 now asserts GFM constructs change the raster (strike-through ink, task checkbox, footnote height, table rows); R-09 asserts the style menu, `mdv6.mermaid.style` persistence across a fresh `UserDefaults`, the 2× PNG export size and the plain-monospace source view; K-15/T-32 parse the 30 samples and assert median ≤ 1 % and nearest-rank p95 ≤ 3 %; E-25 asserts `renderGeneration` bumps on every load/reload and not on an aborted load; E-30 quits with two windows and relaunches into exactly one (R-40 head); T-30 asserts the click → pasteboard/flash/re-flash rules and that a `####` heading is never a copy target; T-43/K-11 dry-run the whole release chain in a disposable clone tagged `v1.2.3` and assert the artefact names, the codesign/notarytool/stapler/spctl steps in §5.3 order, and that `VERSION=9.9.9` is refused before any artefact is named. Two suite-level flakes surfaced by the parallel runner were also fixed in the tests: the idle-CPU test now waits for sibling `xctest` workers to drain (K-15 is defined on an *otherwise idle* host), and the FSEvents burst test allows one batch per 50 ms window the burst actually spanned.

Note for the record: speccheck's Swift adapter treats `//` inside a string literal as a comment; test files keep `//` out of literals on lines with braces (`RecordingServer.slashes`).

### 3.1 Re-gated with speccheck 1.8.0 (2026-09-18)

speccheck 1.8.0 (its SPEC v1.8, R-33) sends the judge a heading-declared contract's **section body**, not just its
heading, so the 17 `### C-nn` contracts of this spec — 0.5–11.2 kB each; `C-18` at 11,179 bytes sits under the
16,384-byte K-14 cap, no truncation Note — were judged for the first time against their pinned shapes. Same tree,
same `junit.xml`, same model, 1.6.0 (title only) versus 1.8.0 (title + body), 101 contract edges:

| | 1.6.0 | 1.8.0 |
| --- | --- | --- |
| `ASSERTS` | 96 | 82 |
| `EXECUTES_ONLY` | 4 | 16 |
| `UNRELATED` | 1 | 3 |

19 edges flipped, 18 of them stable across two 1.8.0 runs; the gate was never at risk (every contract keeps at least
one `ASSERTS` edge). Reading the 18 against the bodies: eleven are judge false negatives — the test asserts a body
clause nearly verbatim (`testPromptAwareFences` ↔ C-05's prompt-aware bullet, `testPiecewiseLinearRemap` ↔ C-06.2,
`testCacheKeyedByURL` ↔ C-07.2 "2048 entries keyed by the URL", `testBookmarkMenuOrderAndEnablement` ↔ C-18.9's
menu, item for item), clustered on the long bodies (C-06, C-07, C-17, C-18), where `gpt-4o-mini` loses the clause.
Five were real and are fixed in this commit, in the test and never by weakening a citation:

| Edge | What was wrong | Change |
| --- | --- | --- |
| C-03, C-08 ← `testOpenCreatesSchemaV4` | asserted the tables *exist*, not their pinned columns | asserts `articles`, `bookmarks`, `scroll_positions` column for column and the FTS5 definition (`content='articles'`, `content_rowid='id'`, `unicode61 remove_diacritics 2`); two introspection helpers `Database.columnNames(of:)` / `tableSQL(_:)` added |
| C-04 ← `testInspectorContents` | asserted persistence through `AppModel`, never the contract's key names | asserts `mdv6_inspector_visible` / `mdv6_inspector_width` in the `UserDefaults` suite, as the contract's types |
| C-02 ← `testBlockKindHelpers` | docstring promised "math fence detection"; `isMathFence` was never called | rule-3 assertions added (`$$` first non-space, no second `$$` on the line) |
| C-18.10 ← `testOwnParagraphEmission` | C-18.10 delegates display math to C-07.1, which the test already cites | citation removed |
| C-17 ← `testInkBounds` | C-17 only *names* the §7.1 ink metric; the test covers T-46's centring apparatus | re-pointed to T-46 |

After the change (`swift test --parallel --xunit-output junit.xml` → 163 tests, 0 failures):

```text
speccheck: CONFORMING - 169/169 passing (100.0%), 0 failing, 0 skipped, 0 weak, 0 unverified, 0 untested, 0 uncited; 0 dangling, 0 stale; judge=mock
speccheck: CONFORMING - 169/169 passing (100.0%), 0 failing, 0 skipped, 0 weak, 0 unverified, 0 untested, 0 uncited; 0 dangling, 0 stale; judge=llm
```

Phase B: `openai/gpt-4o-mini` via OpenRouter, 99 contract edges (82 `ASSERTS`, 15 `EXECUTES_ONLY`, 2 `UNRELATED`),
`unknown_rate 0.0`, `judge_prompt_sha256` `fc7dc32b…bfad00` (the 1.8.0 prompt; the `21ec7849…` runs above were under
the 1.6.0 prompt). C-03 and C-04 now judge `ASSERTS`; C-08 and C-02 still judge `EXECUTES_ONLY` on the same run
although the new assertions are the contract's own columns and rule — recorded, not chased. `testIdleMathCPU` (K-15)
failed once in this session at p95 = 8 % while the build's own processes were still winding down, and passed on the
immediate re-run and on the final full run; K-15 is defined on an otherwise idle host.

## 4. Artifact cross-check (§3.2 of the skill)

| Check | Evidence |
|---|---|
| §4 contracts exist with the pinned shape | C-01 `Info.plist`/K-02 (`BuildAndLauncherTests.testBuiltBundleLayoutAndSignature`); C-02 `ParsedDocument` (`SplitTests`); C-03 schema v4 + triggers (`PersistenceTests.testOpenCreatesSchemaV4`); C-05 `CodeRenderer` (`CodeRendererTests`); C-07 `MathMarkdown`/`MathImageCache`/`MathSymbols` (`MathContractTests`, `MathRenderTests`); C-08 anchors (`AnchorTests`); C-16 `RemoteImageLoader` (`ImageLoadingTests` with a recording server); C-17 harness (`HarnessTests`); C-18 chrome (`ChromeModelTests`, `ChromeSnapshotTests`) |
| §5 surfaces | §5.1 menus/shortcuts: `AppCommand` + the `Mdv6App` Commands in `mdv6App.swift` — each command's effect is asserted through the session (`SessionTests`, `ChromeModelTests`), the toolbar row in `testToolbarSpec`; the menu titles and key equivalents themselves were checked against the §5.1 table by inspection of `mdv6App.swift` (no test enumerates the menu); §5.2 `bin/mdv6` usage lines 2–9 (`tools/gate-w0.sh`, `testLauncherSurface`); §5.3 Makefile targets (`testDistRefusesWithoutExactTag`, `testTaggedCheckoutNamesArtefactsFromTag`); §5.4 diagnostics (`DiagnosticsTests`); §5.5 chrome (`SidebarViews.swift`, the only file that draws a pane — I-015) |
| Schemas / fixtures | `test-docs/render-cases.json` (18 cases; metric cases are oracles, pixel cases regression guards), `test-docs/goldens/*.png` (regression guards only — never cited as conformance evidence), `tools/seed-store` seeds the isolated store for observed runs |
| §10 dependencies | MarkdownUI 2.4.1, SwiftTreeSitter 0.25.0 (tree-sitter 0.25.10), beautiful-mermaid-swift 1.0.4, vendored SwiftMath 1.7.3 + the four patches listed in `Vendor/SwiftMath/README.md` (`testVendoredSwiftMathInventory`, `tools/check-swiftmath.sh`), 11 tree-sitter grammars pinned in `mdv6/Grammars/README.md`, system sqlite3 with FTS5. Nothing else. |
| Data artifacts | `mdv6.db` schema v4 (`PersistenceTests`), `UserDefaults` keys and clamps (`Preferences`, `MiscContractTests`), history JSON codec (`testHistoryCodec`) |
| Determinism | `HarnessTests.testScanCorpusOrderAndDeterminism` (same input → identical PNG bytes); `MathRenderTests` cache keys; `CodeRendererTests.testCacheKeyAndFlush` |
| Formulas | R-30 zoom step (`ZoomStep`, `testZoomStep` incl. the half-integer case); C-17 $q \leq 0.001$ pixel rule (`RenderMetrics.pixelMismatch`, `MetricsTests`); K-16/T-45 band $v \leq g \leq v + 0.6f$ (`testRhythmBandSevillaAndCharcoal`); K-15 median/p95 (`testIdleMathCPU`); R-27 title rule (`testBookmarkTitle`) |
| Diagrams vs rows | Every §3.1 transition has a `SessionTests` case (`testDeleteRowTransitions`, `testReloadRules`, `testEmptyToViewingOnOpen`, `testRealFileWatcherCoalesces`, …); the mermaid state diagram introduced no transition the rows lack. |
| Reference images / TYPOGRAPHY.md | §5 below; T-45/T-46 measured through the harness against the spec's own bands and centring rule (an oracle the build did not produce) |
| README | Re-run before this report: `make`, `bin/mdv6 --version` → `1.0.0`, `swift test --parallel --xunit-output junit.xml`, both speccheck phases, `render-harness --check` (18 cases, exit 0), `render-harness --scan test-docs/mermaid` (15 records, exit 0), `bash tools/gate-w0.sh` (PASS ×all), `tools/idle-cpu.sh` (median 0.00 %, p95 0.00 %). `tools/check-swiftmath.sh` needs network and was run in W0. |
| Every wave closed | §1 |
| No silent omissions | The Phase 0 checklist (R 42 / C 18 / I 15 / K 16 / E 30 / T 48 = 169 ids) is exactly the 169 `PASSING` rows of §6. No id was deferred. Optional behaviour is gated, not omitted (remote images behind `mdv6_load_remote_images`, smart typography behind `mdv6_smart_typography`). |

**Size.** `cloc` over the hand-written Swift (`mdv6/Core`, `App`, `tools/render-harness/Sources`, `tools/seed-store`; vendored SwiftMath, grammars and fixtures excluded): **5,818 code lines / 52 files** (`mdv6/Core` alone 5,746 / 50); tests 2,789 / 21 files. The plan budgeted 7,000–9,500 production lines against the 5.4k smallest-complete-build anchor; the build landed ~400 lines above that anchor — the added structure is the C-18 chrome model (`ChromeModel.swift`, theme-independent metrics/rules) and the C-17 `--check` metrics (`RenderMetrics`, `HarnessCases`), both required by v0.11 and absent from the v0.8 anchor. The budget was an estimate, not a floor.

## 5. The observed pass (§3.2b)

**Environment.** The first pass (W7) could not drive the product on screen — screen recording was not granted and synthetic keystrokes reached another application — so it used the plan's stand-in: with `MDV6_SNAPSHOT_DIR` set, the running **product** accepts a distributed notification that posts a §5.1 command or calls a pane control's handler (`tools/observe.sh drive …`) and another that writes the window's rendered frame to PNG. After the user's report both permissions were available: the second pass drove the product with real pointer and keyboard events (`tools/click.swift` posts `CGEvent`s at global coordinates; System Events for keystrokes and menu items, addressed by pid) and captured windows with `screencapture -l`. Runs use an isolated store (`MDV6_SUPPORT_DIR`, `MDV6_DEFAULTS_SUITE`). Files are under `build/observed/` (not committed; `user-report/` holds the ones cited below).

**Who looked.** The agent opened each file below and compared it region by region with `reference/MDV-ORIGINAL-SEVILLA.png` and `reference/MDV-SCREEN.png`. §9.6 requires the outcome *as observed by a person*; until the user opens these files (or runs `tools/observed-pass.sh` and looks), the rows stay **verification pending**. Oracle for every line: the spec's reference images (structure) and `TYPOGRAPHY.md` (faces, sizes, colours) — never the build's own goldens.

| Test | Looked at | What the snapshot shows | Status |
|---|---|---|---|
| T-44 | `T-44-sevilla.png`, `T-44-sevilla-start.png`, `T-44-sevilla-placeholder-toc.png` (math.md, Sevilla, 4 bookmarks + placeholder, 1280×820 like the reference) | Title `math.md`; toolbar exactly `+`, pencil, palette, bookmark, `sidebar.right`; `HISTORY` / `ON THIS PAGE` / `BOOKMARKS` small-caps tracked headers with the magnifier; history rows name over `~`-abbreviated head-truncated path, current row filled; TOC rows indented by level, the clicked row accent-filled with page-background text; placeholder row first with `pin.fill` and `⌘0`, divider below, current row accent-filled; bookmark rows title over file name with `⌘1`–`⌘4` badges; `BOOKMARKS` header with the count capsule `4`; floating find button at the article's top-trailing corner. Matches the anatomy of `MDV-ORIGINAL-SEVILLA.png` pane by pane. | pending person's look |
| T-44 (states) | `T-44-search-revealed.png`, `T-44-bookmarks-collapsed.png`, `T-44-sidebar-collapsed.png`; real input: `user-report/search-hidden-by-esc.png` (Esc after the field was revealed by a real click on the magnifier), `user-report/hover-chevron.png` (pointer on the divider: the chevron shows) | Reveal, collapse, sidebar-collapse, **Esc hides the field**, **hover chevron** — all drawn as C-18.3/C-18.4/C-18.1 describe. | pending person's look |
| T-44 (themes) | `T-44-charcoal.png`, `T-44-charcoal-states.png`, `T-44-twilight.png`, `T-44-twilight-states.png`, `snapshot-{sevilla,charcoal,twilight}.png` | Same structure under Charcoal and Twilight; only colours/faces change (I-015); the title bar takes the theme's colour scheme (C-18.1). | pending person's look |
| T-47 | `T-47-first.png` (`syntax.md` title), `T-47-second-window.png` / `T-47-two-windows-tables.md.png` / `T-47-two-windows-math.md.png` (⌘⇧O second window titled `tables.md`, first unchanged), `T-47-empty-title.png` (only history row deleted → title `mdv6`) | Title follows the displayed file per window; reverts to the product name in `EMPTY`. | pending person's look |
| T-48 | `T-48-stripe-paragraph.png`, `T-48-stripe-table.png`, `T-48-placeholder-cleared.png`, `T-48-third-moved-up.png`, `T-48-moved-to-bottom.png`, `T-48-removed.png`, `T-48-relaunch-order.png`; real input: `user-report/bookmark-context-menu.png` (right-click on a bookmark row: the nine-entry menu, two separators, in C-18.9 order), a real drag of row 4 to the top reordering the store (F-009) | Stripe, reorder, **menu presentation** and **drag reorder** as C-18.7/C-18.9 describe; order/enablement also in `ChromeModelTests`. | pending person's look |
| Theme switch (R-29, C-18.1) | `user-report/theme-switch-twilight.png` (SPEC.md, Sevilla → Twilight through the toolbar menu with real input) | Every block, the chrome, the title bar and the toolbar icons take the new theme at once (F-005/F-006 fixed). | agent looked |
| §9.2/§9.4 spot checks | `T-05-syntax.png`, `T-06-code.png`, `T-09-images.png`, `T-10-typography.png`, `T-11-start.png` / `T-11-zoom-hud.png` (HUD shows `110 %` 0.35 s after ⌘=), `T-13-diagrams.png`, `T-23-findbar.png`, `T-38-help.png` | The product rendering the corpus documents in the state each test names. | agent looked; supplementary |

**Measured visual claims (oracle: the spec's numbers, in `swift test`).** T-45 rhythm bands under Sevilla and Charcoal and the single-`Markdown`-view ±2 pt cross-check (`RhythmAndDisplayMathTests.testRhythmBandSevillaAndCharcoal`); T-46 identical rasters for the two `$$` forms, ink box centred within 2 pt, `.display` height (`testDisplayMathSingleLineAndFence`); T-17 Mermaid math-node ink; T-19 sequence layout. These are green and need no person.

**Pending (blocking PASS).** (1) The person's look at T-44/T-47/T-48 — the captures above, or the running app on `tools/observed-pass.sh`'s store. (2) T-43: the credentialed run (`Developer ID` identity, `mdv6-notary` keychain profile, exact `vX.Y.Z` tag) — the tag gate (`testDistRefusesWithoutExactTag`) and the chain's naming/order (`testTaggedCheckoutNamesArtefactsFromTag`, dry run in a tagged clone) are proved; signing, notarisation and stapling are not. T-12 (macOS appearance switch) is now proved at the model level by `SystemAppearance` and pending on screen; T-18 (window resize), T-21 (Mermaid hover controls) and T-31 (drags other than the divider and bookmark rows) have their model halves in `swift test` and were not driven.

## 5b. The observed pass for W8 (line citations)

Run on the built bundle at `e61c60f`, isolated store (`MDV6_SUPPORT_DIR` / `MDV6_DEFAULTS_SUITE`), Sevilla theme, fixtures under `/tmp` (`w8-links.md`, `w8-links2.md`, `w8-min.md`).

| What was driven | How | Outcome |
| --- | --- | --- |
| The link renders and is live | app on `w8-links.md`; snapshot | `build/observed/w8-before.png` — *cited paragraph* drawn as a link in the article |
| A **real pointer click** on it | `swift tools/click.swift 712 -1363 click` at the link's screen point | `build/observed/w8-after-click.png` — the click activates the window and the citation resolves; the app raised the citation glyph at the block's leading edge |
| Cross-file citation | `handleLink("…/links-sibling.md#L7-L9")` via the drive hook | `build/observed/w8-after-citation.png` — `links-sibling.md` loaded (new history row at the head), scrolled to the paragraph, and the block carries the flash tint |
| Same-document citation, target below the fold | slug fragment then `#L7-L9` | flash **seen live** on screen (captured at +0.62 s: a filled accent tint across one block) |
| The flash target is the *block* the spec names | asserted, not eyeballed: `testLineCitationSameDocument`, `testLineCitationCrossFile` | `flashedRange == 3..<4` for `#L7-L9` against `links-sibling.md`; `5..<6` for `#L11`; `4..<5` for `#L10` (the gap) |

**Honest limits of this pass.** Three things were *not* cleanly captured on screen: the flash's exact block under a scrolling viewport (the `screencapture -l` path plus the distributed-notification transport is too slow to freeze a 0.6 s animation reliably — repeat attempts at 0.10–0.30 s caught the pre-scroll frame, and one at 0.62 s caught a flash already in flight), the flash's expiry at 0.6 s, and the E-31 clamp on screen. Each of those is instead **asserted** in `swift test` on `flashedRange`/`scrollTarget`, which is the stronger evidence for the *value*; what remains a person's call is only whether the tint and the scroll *look* right, and T-49 joins §9.6's observed set for that reason.

A `linkClicked` drive action was added to the existing `WindowAccessor` observation hook (guarded by `MDV6_SNAPSHOT_DIR`, like its neighbours) so the click path can be exercised without faking a pointer — it is the same `session.linkClicked` the article's `OpenURLAction` calls.

## 6. Per-ID evidence (from `build/speccheck/speccheck.json`)

169 ids: R 42, C 18, I 15, K 16, E 30, T 48 — all `PASSING` in both phases. *Realised in* lists the `mdv6/Core` files citing the id (source citations do not count for T-nn); *verified by* the joined green tests.

| ID | Status | Realised in | Verified by |
|---|---|---|---|
| R-01 | PASSING | AppModel.swift, DocumentSession.swift, HistoryManager.swift, mdv6App.swift | `testMultipleURLsLastDisplayed` (SessionTests); `testAddingVersusSelectingRoutes` (SessionTests) |
| R-02 | PASSING | DocumentSession.swift | `testDirectoryLoads` (SessionTests) |
| R-03 | PASSING | DocumentSession.swift | `testDropRules` (SessionTests) |
| R-04 | PASSING | DocumentSession.swift, FileSystem.swift, ParsedDocument.swift | `testEmptyToViewingOnOpen` (SessionTests); `testUnreadableKeepsPreviousDocument` (SessionTests); `testBlankLineSplitsAndEmptiesDropped` (SplitTests) |
| R-05 | PASSING | DocumentSession.swift, FileWatcher.swift | `testReloadRules` (SessionTests); `testRealFileWatcherCoalesces` (SessionTests) |
| R-06 | PASSING | ArticleView.swift, DocumentRootView.swift, DocumentSession.swift | `testScrollPositions` (PersistenceTests); `testScrollPersistAndRestore` (SessionTests) |
| R-07 | PASSING | ArticleTheme.swift | `testRendererProducesPageBitmap` (RhythmAndDisplayMathTests) |
| R-08 | PASSING | CodeBlockChrome.swift, CodeLanguage.swift, CodeRenderer.swift | `testFenceParts` (ArticleTests); `testPromptAwareFences` (MiscContractTests); `testLanguageLabel` (MiscContractTests) |
| R-09 | PASSING | MDVMermaidDiagramView.swift, MDVMermaidPipeline.swift, Preferences.swift | `testStyleMenuPersistenceAndExport` (MermaidTests) |
| R-10 | PASSING | ContentLimits.swift, MDVMermaidDiagramView.swift, MDVMermaidPipeline.swift | `testUnsupportedTypesAndParseErrorsFallBack` (MermaidTests) |
| R-11 | PASSING | ColumnWidth.swift, MDVMermaidDiagramView.swift, MDVMermaidPipeline.swift | `testMermaidWidthPlumbing` (ArticleTests); `testDisplaySizeAndRaster` (MermaidTests); `testColumnWidthFormula` (MiscContractTests) |
| R-12 | PASSING | MathMarkdown.swift, MathViews.swift | `testTextVsDisplayMode` (MathRenderTests); `testRewriteURLForm` (MathContractTests) |
| R-13 | PASSING | MathMarkdown.swift, ThemeManager.swift | `testColourFollowsSpec` (MathRenderTests); `testMathNodes` (MermaidTests); `testHeadingMathSizing` (MathContractTests) |
| R-14 | PASSING | ContentLimits.swift, MathImageCache.swift, MathSymbols.swift, MathViews.swift | `testRejectedLatexFallsBackWithMessage` (MathRenderTests); `testPreprocessRewrites` (MathContractTests) |
| R-15 | PASSING | MDVMermaidPipeline.swift, MermaidMathNodes.swift | `testMathNodes` (MermaidTests) |
| R-16 | PASSING | DocumentSession.swift, ImageLoading.swift, ImageProviders.swift, MathViews.swift | `testLocalAndDataImages` (ImageLoadingTests) |
| R-17 | PASSING | ArticleView.swift, SmartTypography.swift | `testSmartTypographyOptOuts` (ThemeTests); `testProseIsSmartened` (TypographyTests); `testMathRewrittenBeforeSmartening` (TypographyTests) |
| R-18 | PASSING | DocumentSession.swift | `testDeleteRowTransitions` (SessionTests); `testBackForward` (SessionTests) |
| R-19 | PASSING | DocumentSession.swift | `testHandleLink` (SessionTests) |
| R-20 | PASSING | DocumentSession.swift, HistoryManager.swift | `testPaneClamps` (ChromeModelTests); `testHistoryAddSelectRemove` (PersistenceTests); `testDeleteRowTransitions` (SessionTests) |
| R-21 | PASSING | DocumentSession.swift, SidebarViews.swift | `testPaneClamps` (ChromeModelTests); `testTOCSelectionLifecycle` (SessionTests) |
| R-22 | PASSING | ArticleView.swift, DocumentSession.swift, MathViews.swift, Sections.swift | `testCopySectionFlash` (SessionTests) |
| R-23 | PASSING | Diagnostics.swift, DocumentSession.swift, EditorLauncher.swift | `testEditorOutcomes` (SessionTests) |
| R-24 | PASSING | ArticleView.swift, ChromeModel.swift, DocumentRootView.swift, DocumentSession.swift, FindHighlight.swift, ParsedDocument.swift, SidebarViews.swift | `testFindCountingAndHighlighting` (ArticleTests); `testSidebarFocusRule` (ChromeModelTests); `testFindModel` (SessionTests); `testBlockKindHelpers` (SplitTests) |
| R-25 | PASSING | DocumentSession.swift, FTSQuery.swift | `testIndexAndSearch` (PersistenceTests) |
| R-26 | PASSING | Database.swift, FileSystem.swift, HistoryManager.swift | `testRemoveFileAndPrune` (PersistenceTests); `testHistoryAddSelectRemove` (PersistenceTests); `testIndexMtimeGateAndLaunchReindex` (PersistenceTests); `testMalformedHistoryValue` (PersistenceTests) |
| R-27 | PASSING | ArticleView.swift, BookmarkTitle.swift, BookmarksManager.swift, Database.swift, DocumentRootView.swift, DocumentSession.swift, Sections.swift, SidebarViews.swift | `testBookmarkTitle` (AnchorTests); `testBookmarkMenuOrderAndEnablement` (ChromeModelTests); `testReorderFollowsSlots` (ChromeModelTests); `testBookmarkRows` (PersistenceTests); `testBookmarksManager` (PersistenceTests); `testBookmarkCurrentSpot` (SessionTests) |
| R-28 | PASSING | ArticleView.swift, BookmarkTitle.swift, DocumentSession.swift, PlaceholderStore.swift, SidebarViews.swift | `testBookmarkMenuOrderAndEnablement` (ChromeModelTests); `testPlaceholderStoreIsTransient` (PersistenceTests); `testPlaceholder` (SessionTests) |
| R-29 | PASSING | DocumentRootView.swift, DocumentSession.swift, ThemeManager.swift, WindowAccessor.swift | `testCatalogOrderAndIds` (ThemeTests); `testResolution` (ThemeTests) |
| R-30 | PASSING | ArticleTheme.swift, DocumentRootView.swift, MathMarkdown.swift, Preferences.swift, ZoomStep.swift | `testFontSizeFollowsZoomAndCommentsItalic` (CodeRendererTests); `testZoomStep` (MiscContractTests) |
| R-31 | PASSING | HelpManager.swift, mdv6App.swift | `testHelpOverwrittenEveryTime` (SessionTests) |
| R-32 | PASSING | Preferences.swift | `testPreferencesDefaultsAndFallbacks` (PersistenceTests) |
| R-33 | PASSING | — | `testLauncherSurface` (BuildAndLauncherTests) |
| R-34 | PASSING | — | `testBuiltBundleLayoutAndSignature` (BuildAndLauncherTests); `testDistRefusesWithoutExactTag` (BuildAndLauncherTests); `testTaggedCheckoutNamesArtefactsFromTag` (BuildAndLauncherTests) |
| R-35 | PASSING | Diagnostics.swift, EditorLauncher.swift, ThemeManager.swift | `testNoOtherLogCallSites` (DiagnosticsTests); `testDiagnosticsEvents` (MiscContractTests); `testCorruptFileDegrades` (PersistenceTests) |
| R-36 | PASSING | ContentLimits.swift | `testRejectedLatexFallsBackWithMessage` (MathRenderTests); `testUnsupportedTypesAndParseErrorsFallBack` (MermaidTests) |
| R-37 | PASSING | — | `testSuiteAndCI` (BuildAndLauncherTests) |
| R-38 | PASSING | CodeLanguage.swift, CodeRenderer.swift | `testAllGrammarsAndQueriesLoad` (CodeRendererTests); `testSwiftAndSQLCaptureClasses` (CodeRendererTests); `testLanguageResolution` (MiscContractTests) |
| R-39 | PASSING | DocumentRenderer.swift, HarnessCases.swift | `testScanCorpusOrderAndDeterminism` (HarnessTests) |
| R-40 | PASSING | AppModel.swift, DocumentSession.swift, mdv6App.swift | `testOneWindowAfterQuitWithTwoWindows` (ChromeModelTests); `testStartup` (SessionTests) |
| R-41 | PASSING | ContentLimits.swift, DocumentSession.swift, FileSystem.swift, ImageLoading.swift, MDVMermaidPipeline.swift, MathImageCache.swift, PipelineProbe.swift | `testLatexCeiling` (MathRenderTests); `testMermaidCeiling` (MermaidTests); `testContentLimits` (MiscContractTests); `testUnreadableKeepsPreviousDocument` (SessionTests) |
| R-42 | PASSING | ArticleView.swift | `testRhythmBandSevillaAndCharcoal` (RhythmAndDisplayMathTests) |
| C-01 | PASSING | ThemeManager.swift | `testBuiltBundleLayoutAndSignature` (BuildAndLauncherTests) |
| C-02 | PASSING | ArticleView.swift, BookmarkTitle.swift, CodeBlockChrome.swift, ParsedDocument.swift, Sections.swift, SmartTypography.swift | `testBlankLineSplitsAndEmptiesDropped` (SplitTests); `testFenceKeepsBlankLinesAndClosesOnSameMarker` (SplitTests); `testMathFenceSpansBlankLines` (SplitTests); `testIndentedCodeBlockSplitsAtBlankLine` (SplitTests); `testLineEndingsNormalised` (SplitTests); `testTOCHeadings` (SplitTests); `testBlockKindHelpers` (SplitTests) |
| C-03 | PASSING | Database.swift, FTSQuery.swift, SidebarViews.swift | `testFTSQueryConstruction` (MiscContractTests); `testOpenCreatesSchemaV4` (PersistenceTests); `testEqualRankOrderingAndLimit` (PersistenceTests) |
| C-04 | PASSING | MDVMermaidPipeline.swift, Preferences.swift, ThemeManager.swift, ZoomStep.swift | `testPreferencesDefaultsAndFallbacks` (PersistenceTests); `testResolution` (ThemeTests) |
| C-05 | PASSING | CodeBlockChrome.swift, CodeLanguage.swift, CodeRenderer.swift, ThemeManager.swift | `testFenceParts` (ArticleTests); `testAllGrammarsAndQueriesLoad` (CodeRendererTests); `testSwiftAndSQLCaptureClasses` (CodeRendererTests); `testNineLanguagesColourAndUnknownIsPlain` (CodeRendererTests); `testFontSizeFollowsZoomAndCommentsItalic` (CodeRendererTests); `testCacheKeyAndFlush` (CodeRendererTests); `testLanguageResolution` (MiscContractTests); `testPromptAwareFences` (MiscContractTests); `testLanguageLabel` (MiscContractTests); `testCodePaletteLookup` (ThemeTests) |
| C-06 | PASSING | MDVMermaidPipeline.swift, MermaidMathNodes.swift, MermaidRepairs.swift | `testNodeInTwoSubgraphsBelongsToLast` (MermaidTests); `testSanitisedDiagramRenders` (MermaidTests); `testStateDescriptionsAndClassDefs` (MermaidTests); `testDocumentTheme` (MermaidTests); `testSequenceRepairs` (MermaidTests); `testPiecewiseLinearRemap` (MermaidTests); `testMathNodes` (MermaidTests); `testFrontMatterDropped` (MermaidSanitizeTests); `testXYChartSeriesNames` (MermaidSanitizeTests); `testColorNormalisation` (MermaidSanitizeTests); `testStateDescriptionsMerged` (MermaidSanitizeTests); `testParallelogramsExpanded` (MermaidSanitizeTests); `testFormattingTagsStripped` (MermaidSanitizeTests); `testSanitizeAppliesAllRulesInOrder` (MermaidSanitizeTests) |
| C-07 | PASSING | BookmarkTitle.swift, MathImageCache.swift, MathMarkdown.swift, MathSpec.swift, MathSymbols.swift, MathViews.swift, MermaidMathNodes.swift | `testOwnParagraphRegistry` (ArticleTests); `testRewritesAndSymbolsTypeset` (MathRenderTests); `testCacheKeyedByURL` (MathRenderTests); `testMathNodes` (MermaidTests); `testDisplayMathSingleLineAndFence` (RhythmAndDisplayMathTests); `testBookmarkTitle` (AnchorTests); `testNonMathDollarsAreLiteral` (MathContractTests); `testSpanDetection` (MathContractTests); `testRewriteURLForm` (MathContractTests); `testOwnParagraphEmission` (MathContractTests); `testPlainText` (MathContractTests); `testPreprocessRewrites` (MathContractTests); `testRegisteredSymbolTable` (MathContractTests); `testTOCHeadings` (SplitTests) |
| C-08 | PASSING | Anchors.swift, BookmarksManager.swift, Database.swift, DocumentSession.swift | `testFingerprintNormalisation` (AnchorTests); `testResolveAnchor` (AnchorTests); `testScrollRestorable` (AnchorTests); `testOpenCreatesSchemaV4` (PersistenceTests); `testBookmarkRows` (PersistenceTests); `testScrollPositions` (PersistenceTests); `testScrollPersistAndRestore` (SessionTests) |
| C-09 | PASSING | ArticleTheme.swift, ThemeManager.swift | `testCatalogOrderAndIds` (ThemeTests); `testDefaults` (ThemeTests); `testSmartTypographyOptOuts` (ThemeTests); `testCrossThemeRules` (ThemeTests) |
| C-10 | PASSING | SmartTypography.swift | `testProseIsSmartened` (TypographyTests); `testExclusionsInsideProse` (TypographyTests); `testBlocksReturnedUnchanged` (TypographyTests) |
| C-11 | PASSING | DocumentSession.swift, HeadingSlug.swift, ParsedDocument.swift | `testHandleLink` (SessionTests); `testHeadingSlug` (SplitTests) |
| C-12 | PASSING | BookmarkTitle.swift, Sections.swift | `testBookmarkTitle` (AnchorTests); `testCopySectionFlash` (SessionTests); `testStripInlineMarkdown` (SplitTests); `testSectionRange` (SplitTests) |
| C-13 | PASSING | ThemeManager.swift | `testBuiltBundleLayoutAndSignature` (BuildAndLauncherTests) |
| C-14 | PASSING | EditorLauncher.swift, ImageLoading.swift, mdv6App.swift | `testLocalAndDataImages` (ImageLoadingTests); `testRejectedLatexFallsBackWithMessage` (MathRenderTests); `testUnsupportedTypesAndParseErrorsFallBack` (MermaidTests) |
| C-15 | PASSING | HistoryManager.swift, Preferences.swift | `testHistoryCodec` (MiscContractTests); `testHistoryAddSelectRemove` (PersistenceTests); `testMalformedHistoryValue` (PersistenceTests) |
| C-16 | PASSING | ImageLoading.swift | `testRemoteContract` (ImageLoadingTests); `testTimeouts` (ImageLoadingTests) |
| C-17 | PASSING | DocumentRenderer.swift, HarnessCases.swift, MathViews.swift, RenderMetrics.swift | `testScanCorpusOrderAndDeterminism` (HarnessTests); `testManifestRules` (HarnessTests); `testRenderOneConditions` (HarnessTests); `testRendererProducesPageBitmap` (RhythmAndDisplayMathTests); `testPixelMismatch` (MetricsTests); `testInkBounds` (MetricsTests) |
| C-18 | PASSING | ArticleTheme.swift, ArticleView.swift, BookmarksManager.swift, ChromeModel.swift, ColumnWidth.swift, DocumentRootView.swift, DocumentSession.swift, MathViews.swift, PlaceholderStore.swift, SidebarViews.swift, WindowAccessor.swift | `testHostedWindowSnapshots` (ChromeSnapshotTests); `testBlockInsetIsMaxOfBottomAndTop` (RhythmAndDisplayMathTests); `testBookmarkMenuOrderAndEnablement` (ChromeModelTests); `testMetricsTable` (ChromeModelTests); `testRowStyleOverAllThemes` (ChromeModelTests); `testWindowTitleAndScheme` (ChromeModelTests); `testRowRules` (ChromeModelTests); `testToolbarSpec` (ChromeModelTests); `testSidebarFocusRule` (ChromeModelTests); `testAppearanceAssignmentIsIdempotent` (ChromeModelTests); `testOwnParagraphEmission` (MathContractTests); `testDeleteRowTransitions` (SessionTests) |
| I-001 | PASSING | DocumentRenderer.swift, HarnessCases.swift, ImageLoading.swift | `testScanCorpusOrderAndDeterminism` (HarnessTests) |
| I-002 | PASSING | ContentLimits.swift, PipelineProbe.swift | `testRejectedLatexFallsBackWithMessage` (MathRenderTests); `testUnsupportedTypesAndParseErrorsFallBack` (MermaidTests) |
| I-003 | PASSING | Diagnostics.swift, ImageLoading.swift | `testSessionEmitsNoContentLines` (DiagnosticsTests); `testDiagnosticsEvents` (MiscContractTests) |
| I-004 | PASSING | ParsedDocument.swift | `testOneBlockIndexEverywhere` (SessionTests); `testEqualityOnRaw` (SplitTests) |
| I-005 | PASSING | MDVMermaidDiagramView.swift, MDVMermaidPipeline.swift | `testDisplaySizeAndRaster` (MermaidTests) |
| I-006 | PASSING | Database.swift | `testOpenCreatesSchemaV4` (PersistenceTests); `testConcurrentWritesLeaveWholeRows` (PersistenceTests) |
| I-007 | PASSING | Database.swift | `testMigrationIsAtomic` (PersistenceTests); `testScrollPositions` (PersistenceTests); `testConcurrentWritesLeaveWholeRows` (PersistenceTests) |
| I-008 | PASSING | MathImageCache.swift | `testImagesAreBitmapBacked` (MathRenderTests); `testIdleMathCPU` (BuildAndLauncherTests) |
| I-009 | PASSING | MDVMermaidPipeline.swift, MermaidMathNodes.swift, RenderMetrics.swift | `testMathNodes` (MermaidTests); `testInkMetric` (MetricsTests); `testInkRatioRule` (MetricsTests) |
| I-010 | PASSING | HeadingSlug.swift, MathMarkdown.swift | `testPlainText` (MathContractTests); `testTOCHeadings` (SplitTests); `testHeadingSlug` (SplitTests) |
| I-011 | PASSING | — | `testVendoredSwiftMathInventory` (BuildAndLauncherTests) |
| I-012 | PASSING | SmartTypography.swift | `testExclusionsInsideProse` (TypographyTests); `testBlocksReturnedUnchanged` (TypographyTests); `testMathRewrittenBeforeSmartening` (TypographyTests) |
| I-013 | PASSING | HistoryManager.swift | `testHistoryCodec` (MiscContractTests); `testHistoryAddSelectRemove` (PersistenceTests) |
| I-014 | PASSING | ArticleTheme.swift, ArticleView.swift, DocumentRenderer.swift, RenderMetrics.swift, ThemeManager.swift | `testBlockInsetIsMaxOfBottomAndTop` (RhythmAndDisplayMathTests); `testRhythmBandSevillaAndCharcoal` (RhythmAndDisplayMathTests); `testInkRowsAndGaps` (MetricsTests); `testRhythmBand` (MetricsTests); `testPerThemeValues` (ThemeTests) |
| I-015 | PASSING | ChromeModel.swift, SidebarViews.swift | `testHostedWindowSnapshots` (ChromeSnapshotTests); `testRowStyleOverAllThemes` (ChromeModelTests); `testCrossThemeRules` (ThemeTests) |
| K-01 | PASSING | — | `testBuiltBundleLayoutAndSignature` (BuildAndLauncherTests) |
| K-02 | PASSING | — | `testBuiltBundleLayoutAndSignature` (BuildAndLauncherTests) |
| K-03 | PASSING | BookmarksManager.swift, FTSQuery.swift, HistoryManager.swift | `testFTSQueryConstruction` (MiscContractTests); `testEqualRankOrderingAndLimit` (PersistenceTests) |
| K-04 | PASSING | ChromeModel.swift, DocumentRootView.swift, Preferences.swift, SidebarViews.swift, ZoomStep.swift | `testPaneClamps` (ChromeModelTests); `testZoomStep` (MiscContractTests); `testPreferencesDefaultsAndFallbacks` (PersistenceTests) |
| K-05 | PASSING | CodeLanguage.swift, CodeRenderer.swift | `testAllGrammarsAndQueriesLoad` (CodeRendererTests); `testNineLanguagesColourAndUnknownIsPlain` (CodeRendererTests); `testLanguageResolution` (MiscContractTests) |
| K-06 | PASSING | Anchors.swift, BookmarkTitle.swift, DocumentSession.swift, FileSystem.swift, FileWatcher.swift, HistoryManager.swift, SessionClock.swift, ZoomStep.swift | `testScrollRestorable` (AnchorTests); `testBookmarkTitle` (AnchorTests); `testIndexMtimeGateAndLaunchReindex` (PersistenceTests); `testCopySectionFlash` (SessionTests); `testRealFileWatcherCoalesces` (SessionTests) |
| K-07 | PASSING | ColumnWidth.swift, MDVMermaidDiagramView.swift, MDVMermaidPipeline.swift | `testConstants` (MermaidTests); `testColumnWidthFormula` (MiscContractTests) |
| K-08 | PASSING | MDVMermaidPipeline.swift, MathImageCache.swift, MathMarkdown.swift, MathSpec.swift, MermaidMathNodes.swift, MermaidRepairs.swift | `testTextVsDisplayMode` (MathRenderTests); `testSequenceRepairs` (MermaidTests); `testMathNodes` (MermaidTests); `testSpanDetection` (MathContractTests) |
| K-09 | PASSING | Anchors.swift, FTSQuery.swift | `testFingerprintNormalisation` (AnchorTests) |
| K-10 | PASSING | ArticleView.swift, ThemeManager.swift | `testDefaults` (ThemeTests) |
| K-11 | PASSING | — | `testDistRefusesWithoutExactTag` (BuildAndLauncherTests); `testTaggedCheckoutNamesArtefactsFromTag` (BuildAndLauncherTests) |
| K-12 | PASSING | — | `testBuiltBundleLayoutAndSignature` (BuildAndLauncherTests) |
| K-13 | PASSING | ArticleView.swift, ColumnWidth.swift | `testMermaidWidthPlumbing` (ArticleTests); `testColumnWidthFormula` (MiscContractTests) |
| K-14 | PASSING | ContentLimits.swift, DocumentSession.swift, FileSystem.swift, ImageLoading.swift, ImageProviders.swift, MDVMermaidPipeline.swift, MathImageCache.swift | `testDecodingCeilings` (ImageLoadingTests); `testLatexCeiling` (MathRenderTests); `testMermaidCeiling` (MermaidTests); `testContentLimits` (MiscContractTests); `testUnreadableKeepsPreviousDocument` (SessionTests) |
| K-15 | PASSING | MathImageCache.swift | `testImagesAreBitmapBacked` (MathRenderTests); `testIdleMathCPU` (BuildAndLauncherTests) |
| K-16 | PASSING | ChromeModel.swift, HarnessCases.swift, RenderMetrics.swift | `testRhythmBandSevillaAndCharcoal` (RhythmAndDisplayMathTests); `testMetricsTable` (ChromeModelTests); `testInkRowsAndGaps` (MetricsTests); `testRhythmBand` (MetricsTests); `testPerThemeValues` (ThemeTests) |
| E-01 | PASSING | MDVMermaidPipeline.swift, MermaidRepairs.swift | `testNodeInTwoSubgraphsBelongsToLast` (MermaidTests) |
| E-02 | PASSING | DocumentRenderer.swift, HarnessCases.swift, MDVMermaidDiagramView.swift, MDVMermaidPipeline.swift | `testScanCorpusOrderAndDeterminism` (HarnessTests); `testUnsupportedTypesAndParseErrorsFallBack` (MermaidTests) |
| E-03 | PASSING | DocumentSession.swift | `testUnreadableKeepsPreviousDocument` (SessionTests) |
| E-04 | PASSING | DocumentSession.swift | `testDirectoryLoads` (SessionTests) |
| E-05 | PASSING | DocumentSession.swift | `testHandleLink` (SessionTests) |
| E-06 | PASSING | DocumentSession.swift | `testHandleLink` (SessionTests) |
| E-07 | PASSING | MathMarkdown.swift | `testNonMathDollarsAreLiteral` (MathContractTests) |
| E-08 | PASSING | Anchors.swift, Database.swift, DocumentSession.swift | `testResolveAnchor` (AnchorTests); `testScrollRestorable` (AnchorTests); `testScrollPersistAndRestore` (SessionTests) |
| E-09 | PASSING | BookmarksManager.swift, DocumentSession.swift, FileSystem.swift | `testBookmarksManager` (PersistenceTests); `testBookmarkCurrentSpot` (SessionTests) |
| E-10 | PASSING | MathImageCache.swift, MathViews.swift | `testRejectedLatexFallsBackWithMessage` (MathRenderTests) |
| E-11 | PASSING | ImageLoading.swift, ImageProviders.swift | `testLocalAndDataImages` (ImageLoadingTests); `testRemoteContract` (ImageLoadingTests) |
| E-12 | PASSING | Database.swift, Diagnostics.swift | `testMigrationIsAtomic` (PersistenceTests); `testCorruptFileDegrades` (PersistenceTests) |
| E-13 | PASSING | MermaidRepairs.swift | `testSequenceRepairs` (MermaidTests) |
| E-14 | PASSING | MDVMermaidPipeline.swift | `testSanitisedDiagramRenders` (MermaidTests); `testColorNormalisation` (MermaidSanitizeTests) |
| E-15 | PASSING | MDVMermaidPipeline.swift | `testXYChartSeriesRender` (MermaidTests); `testXYChartSeriesNames` (MermaidSanitizeTests) |
| E-16 | PASSING | MathMarkdown.swift, MathViews.swift | `testOwnParagraphRegistry` (ArticleTests); `testDisplayMathSingleLineAndFence` (RhythmAndDisplayMathTests) |
| E-17 | PASSING | ArticleView.swift, DocumentSession.swift, FindHighlight.swift | `testFindCountingAndHighlighting` (ArticleTests); `testBlockKindHelpers` (SplitTests) |
| E-18 | PASSING | ChromeModel.swift, DocumentSession.swift, SidebarViews.swift | `testSidebarFocusRule` (ChromeModelTests); `testFindModel` (SessionTests) |
| E-19 | PASSING | — | `testReloadRules` (SessionTests) |
| E-20 | PASSING | — | `testTwoWindowsSamePathReloadIndependently` (SessionTests) |
| E-21 | PASSING | DocumentSession.swift, FileWatcher.swift | `testReloadRules` (SessionTests) |
| E-22 | PASSING | ParsedDocument.swift | `testHandleLink` (SessionTests); `testTOCHeadings` (SplitTests) |
| E-23 | PASSING | ParsedDocument.swift | `testFenceKeepsBlankLinesAndClosesOnSameMarker` (SplitTests); `testIndentedCodeBlockSplitsAtBlankLine` (SplitTests) |
| E-24 | PASSING | Database.swift, FTSQuery.swift | `testFTSQueryConstruction` (MiscContractTests) |
| E-25 | PASSING | ArticleView.swift, DocumentSession.swift, MDVMermaidDiagramView.swift | `testRenderGenerationBumpsOnEveryDocumentChange` (SessionTests) |
| E-26 | PASSING | AppModel.swift, DocumentRootView.swift, WindowAccessor.swift, mdv6App.swift | `testKeyWindowRouting` (SessionTests) |
| E-27 | PASSING | DocumentSession.swift | `testBackForward` (SessionTests); `testPlaceholder` (SessionTests) |
| E-28 | PASSING | ContentLimits.swift, DocumentRenderer.swift, ImageLoading.swift, MDVMermaidDiagramView.swift, MDVMermaidPipeline.swift, MathImageCache.swift | `testLatexCeiling` (MathRenderTests); `testMermaidCeiling` (MermaidTests); `testContentLimits` (MiscContractTests); `testUnreadableKeepsPreviousDocument` (SessionTests) |
| E-29 | PASSING | DocumentSession.swift | `testTOCSelectionLifecycle` (SessionTests) |
| E-30 | PASSING | WindowAccessor.swift, mdv6App.swift | `testOneWindowAfterQuitWithTwoWindows` (ChromeModelTests) |
| T-01 | PASSING | — | `testBuiltBundleLayoutAndSignature` (BuildAndLauncherTests) |
| T-02 | PASSING | — | `testDistRefusesWithoutExactTag` (BuildAndLauncherTests) |
| T-03 | PASSING | — | `testLauncherSurface` (BuildAndLauncherTests); `testMultipleURLsLastDisplayed` (SessionTests) |
| T-04 | PASSING | — | `testUnreadableKeepsPreviousDocument` (SessionTests) |
| T-05 | PASSING | — | `testRendererProducesPageBitmap` (RhythmAndDisplayMathTests) |
| T-06 | PASSING | — | `testNineLanguagesColourAndUnknownIsPlain` (CodeRendererTests); `testLanguageResolution` (MiscContractTests); `testPromptAwareFences` (MiscContractTests) |
| T-07 | PASSING | — | `testTextVsDisplayMode` (MathRenderTests); `testRewritesAndSymbolsTypeset` (MathRenderTests); `testRejectedLatexFallsBackWithMessage` (MathRenderTests); `testNonMathDollarsAreLiteral` (MathContractTests); `testSpanDetection` (MathContractTests); `testPreprocessRewrites` (MathContractTests) |
| T-08 | PASSING | — | `testBookmarkTitle` (AnchorTests); `testPlainText` (MathContractTests); `testTOCHeadings` (SplitTests); `testStripInlineMarkdown` (SplitTests) |
| T-09 | PASSING | — | `testLocalAndDataImages` (ImageLoadingTests) |
| T-10 | PASSING | — | `testSmartTypographyOptOuts` (ThemeTests); `testProseIsSmartened` (TypographyTests); `testExclusionsInsideProse` (TypographyTests); `testBlocksReturnedUnchanged` (TypographyTests) |
| T-11 | PASSING | — | `testZoomStep` (MiscContractTests) |
| T-12 | PASSING | — | `testResolution` (ThemeTests) |
| T-13 | PASSING | RenderMetrics.swift | `testScanCorpusOrderAndDeterminism` (HarnessTests); `testUnsupportedTypesAndParseErrorsFallBack` (MermaidTests); `testPixelMismatch` (MetricsTests) |
| T-14 | PASSING | — | `testNodeInTwoSubgraphsBelongsToLast` (MermaidTests) |
| T-15 | PASSING | — | `testSanitisedDiagramRenders` (MermaidTests); `testFrontMatterDropped` (MermaidSanitizeTests); `testColorNormalisation` (MermaidSanitizeTests); `testParallelogramsExpanded` (MermaidSanitizeTests); `testFormattingTagsStripped` (MermaidSanitizeTests); `testSanitizeAppliesAllRulesInOrder` (MermaidSanitizeTests) |
| T-16 | PASSING | — | `testXYChartSeriesRender` (MermaidTests); `testXYChartSeriesNames` (MermaidSanitizeTests) |
| T-17 | PASSING | HarnessCases.swift, RenderMetrics.swift | `testMetricCasesPass` (HarnessTests); `testMathNodes` (MermaidTests); `testInkMetric` (MetricsTests) |
| T-18 | PASSING | — | `testMermaidWidthPlumbing` (ArticleTests); `testColumnWidthFormula` (MiscContractTests) |
| T-19 | PASSING | HarnessCases.swift, RenderMetrics.swift | `testMetricCasesPass` (HarnessTests); `testSequenceRepairs` (MermaidTests); `testPixelMismatch` (MetricsTests) |
| T-20 | PASSING | — | `testStateDescriptionsAndClassDefs` (MermaidTests); `testStateDescriptionsMerged` (MermaidSanitizeTests) |
| T-21 | PASSING | — | `testStyleMenuPersistenceAndExport` (MermaidTests) |
| T-22 | PASSING | — | `testBackForward` (SessionTests); `testHandleLink` (SessionTests); `testHeadingSlug` (SplitTests) |
| T-23 | PASSING | — | `testFindCountingAndHighlighting` (ArticleTests) |
| T-24 | PASSING | — | `testFTSQueryConstruction` (MiscContractTests); `testIndexAndSearch` (PersistenceTests); `testEqualRankOrderingAndLimit` (PersistenceTests); `testIndexMtimeGateAndLaunchReindex` (PersistenceTests) |
| T-25 | PASSING | — | `testHistoryCodec` (MiscContractTests); `testHistoryAddSelectRemove` (PersistenceTests); `testAddingVersusSelectingRoutes` (SessionTests); `testDeleteRowTransitions` (SessionTests) |
| T-26 | PASSING | — | `testFingerprintNormalisation` (AnchorTests); `testResolveAnchor` (AnchorTests); `testBookmarkTitle` (AnchorTests); `testBookmarkRows` (PersistenceTests); `testBookmarksManager` (PersistenceTests) |
| T-27 | PASSING | — | `testPlaceholderStoreIsTransient` (PersistenceTests); `testPlaceholder` (SessionTests) |
| T-28 | PASSING | — | `testOneWindowAfterQuitWithTwoWindows` (ChromeModelTests); `testScrollPositions` (PersistenceTests); `testScrollPersistAndRestore` (SessionTests); `testStartup` (SessionTests) |
| T-29 | PASSING | — | `testRealFileWatcherCoalesces` (SessionTests) |
| T-30 | PASSING | — | `testCopySectionFlash` (SessionTests); `testOneBlockIndexEverywhere` (SessionTests); `testSectionRange` (SplitTests) |
| T-31 | PASSING | — | `testPaneClamps` (ChromeModelTests); `testPreferencesDefaultsAndFallbacks` (PersistenceTests) |
| T-32 | PASSING | — | `testIdleMathCPU` (BuildAndLauncherTests) |
| T-33 | PASSING | — | `testCorruptFileDegrades` (PersistenceTests); `testConcurrentWritesLeaveWholeRows` (PersistenceTests) |
| T-34 | PASSING | — | `testVendoredSwiftMathInventory` (BuildAndLauncherTests) |
| T-35 | PASSING | — | `testTwoWindowsSamePathReloadIndependently` (SessionTests) |
| T-36 | PASSING | — | `testNoOtherLogCallSites` (DiagnosticsTests); `testSessionEmitsNoContentLines` (DiagnosticsTests) |
| T-37 | PASSING | — | `testSwiftAndSQLCaptureClasses` (CodeRendererTests); `testLanguageResolution` (MiscContractTests) |
| T-38 | PASSING | — | `testHelpOverwrittenEveryTime` (SessionTests); `testEditorOutcomes` (SessionTests) |
| T-39 | PASSING | — | `testUnreadableKeepsPreviousDocument` (SessionTests); `testBlankLineSplitsAndEmptiesDropped` (SplitTests); `testFenceKeepsBlankLinesAndClosesOnSameMarker` (SplitTests); `testMathFenceSpansBlankLines` (SplitTests); `testIndentedCodeBlockSplitsAtBlankLine` (SplitTests); `testLineEndingsNormalised` (SplitTests) |
| T-40 | PASSING | — | `testKeyWindowRouting` (SessionTests) |
| T-41 | PASSING | PipelineProbe.swift | `testDecodingCeilings` (ImageLoadingTests); `testRemoteContract` (ImageLoadingTests); `testMermaidCeiling` (MermaidTests); `testContentLimits` (MiscContractTests) |
| T-42 | PASSING | — | `testPreferencesDefaultsAndFallbacks` (PersistenceTests); `testResolution` (ThemeTests) |
| T-43 | PASSING | — | `testDistRefusesWithoutExactTag` (BuildAndLauncherTests); `testTaggedCheckoutNamesArtefactsFromTag` (BuildAndLauncherTests) |
| T-44 | PASSING | — | `testHostedWindowSnapshots` (ChromeSnapshotTests); `testRowStyleOverAllThemes` (ChromeModelTests) |
| T-45 | PASSING | HarnessCases.swift, RenderMetrics.swift | `testMetricCasesPass` (HarnessTests); `testRhythmBandSevillaAndCharcoal` (RhythmAndDisplayMathTests); `testInkRowsAndGaps` (MetricsTests); `testRhythmBand` (MetricsTests) |
| T-46 | PASSING | HarnessCases.swift, RenderMetrics.swift | `testMetricCasesPass` (HarnessTests); `testDisplayMathSingleLineAndFence` (RhythmAndDisplayMathTests); `testSpanDetection` (MathContractTests); `testOwnParagraphEmission` (MathContractTests); `testInkBounds` (MetricsTests) |
| T-47 | PASSING | — | `testWindowTitleAndScheme` (ChromeModelTests); `testDeleteRowTransitions` (SessionTests) |
| T-48 | PASSING | — | `testBookmarkMenuOrderAndEnablement` (ChromeModelTests); `testReorderFollowsSlots` (ChromeModelTests); `testBookmarksManager` (PersistenceTests) |
| T-49 | PASSING | DocumentSession.swift, LineCitation.swift | `testLineCitationSameDocument`, `testLineCitationCrossFile`, `testLineCitationFlashRestartsAndExpires` (SessionTests); observed half in §5b |
| T-50 | PASSING | ParsedDocument.swift, LineCitation.swift | `testBlockLinesAreHalfOpenAndCounted`, `testLineCitationGrammar`, `testRangeNormalisation`, `testResolution`, `testFixtureLineMap` (LineCitationTests) |
| C-19 | PASSING | LineCitation.swift, DocumentSession.swift, ParsedDocument.swift | as T-49/T-50 |
| E-31 | PASSING | LineCitation.swift (`lineCitationBlock`) | `testResolution`, `testFixtureLineMap` (LineCitationTests); `testLineCitationSameDocument`, `testLineCitationCrossFile` (SessionTests) |

## 7. Verdict

```text
Spec coverage: 173/173 IDs realized (0 deferred)
speccheck (mock): speccheck: CONFORMING - 173/173 passing (100.0%), 0 failing, 0 skipped, 0 weak, 0 unverified, 0 untested, 0 uncited; 0 dangling, 0 stale; judge=mock
speccheck (llm):  speccheck: NOT CONFORMING - 165/173 passing (95.4%), 0 failing, 0 skipped, 8 weak, 0 unverified, 0 untested, 0 uncited; 0 dangling, 0 stale; judge=llm (gemini), unknown_rate 0.0213 — the 8 weak rows are T-04, T-07, T-09, T-12, T-34, R-10, R-13, E-19, all pre-existing manual tests, none of them a W8 id; the run before W8 (build/speccheck-llm-gemini, 2026-09-18) was already NOT CONFORMING with 4 weak of the same class, so the delta is judge strictness/endpoint, not this change
Observed: T-44 build/observed/T-44-sevilla.png (+charcoal, twilight, states; user-report/search-hidden-by-esc.png, hover-chevron.png) — anatomy matches reference/MDV-ORIGINAL-SEVILLA.png; Esc-hide and hover chevron exercised with real input; agent looked, person's look pending
          T-45 measured (testRhythmBandSevillaAndCharcoal, spec bands) — pass;  T-46 measured (centred, .display height) — pass
          T-47 build/observed/T-47-first.png, T-47-second-window.png, T-47-empty-title.png — titles follow each window's file, revert to mdv6; person's look pending
          T-48 build/observed/T-48-stripe-*.png, T-48-third-moved-up.png, …, user-report/bookmark-context-menu.png — stripe, reorder, menu presentation and a real drag reorder exercised; menus also proved in swift test; person's look pending
          T-49 build/observed/w8-before.png, w8-after-click.png (a real pointer click on the citation), w8-after-citation.png (cross-file: file loaded, scrolled, tinted) — flash seen live; flash target, expiry and the E-31 clamp asserted in swift test, see §5b for what was and was not captured
          T-43 PENDING: no Developer ID identity, notary profile or vX.Y.Z tag on this host (tag gate and chain dry-run proved)
Readiness: BUILT
Conformance: VERIFICATION PENDING
```

The build is complete and mechanically conforming; the verdict becomes PASS when a person has looked at the T-44/T-47/T-48 captures (or the running app), and PASS WITH NOTES until T-43's credentialed run is done on a tagged release checkout.
