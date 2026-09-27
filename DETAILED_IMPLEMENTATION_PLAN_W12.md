# Detailed implementation plan — W12: session and window commands

> - **Wave:** W12 of W10–W15 (`IMPLEMENTATION_PLAN.md` §II.4 "W12 — session and window commands").
> - **Spec basis:** `SPEC.md` v0.14.4, sha256 `2c193583…9fdc`. Not edited.
> - **Gate:** every new command, its enablement and every new §3.1 transition has a headless test; the app runs with no window after its last window closes.
> - **Budget:** 350–550 production code lines.
> - **Depends on:** W10 (`HistoryStep`, `ScrollKeys`), W11 (`ArticleHost.showFrontmatter`). **Unlocks:** W14 (the `print` command slot), W15 (the drive commands).

## 1. Objective and spec obligations

| Spec id | Obligation | Discharge |
|---|---|---|
| C-04, R-44 | `mdv6_show_frontmatter`, default true; View toggle | `Preferences.Key.showFrontmatter`; View menu |
| R-44, R-27, R-28, C-18.9 | hidden header never the anchor; block-0 title `Frontmatter`; header-only document beeps | `DocumentSession.anchorBlock`, `BookmarkTitle.title` |
| R-47, R-06, R-26, E-26, E-36, §3.1 | Close File / Window / All; no persist or snapshot on close; confirmation; cancel in-flight loads; every window `EMPTY` | `DocumentSession.closeFile`, `AppModel.closeAll`, `mdv6App` menus + dialog |
| R-48, E-26 | Next / Previous File, clamped; ⌃⇥ / ⌃⇧⇥ | `DocumentSession.stepFile`; key monitor |
| R-49, K-18, E-37 | keyboard scrolling with the focus rule | `ScrollKeyMonitor` |
| R-01 | frontmost document window target; background opens | `AppModel.targetSession`, `mdv6AppDelegate.application(_:open:)` |
| R-01, E-38 | zero-window state; window on demand only with a file | `applicationShouldTerminateAfterLastWindowClosed` → false; `AppModel.ensureWindow(for:)` |
| T-52, T-55, T-56, T-57, T-61 (headless halves) | | §5 |

## 2. Entry preconditions

- W11's `ArticleHost.showFrontmatter`.
- W5/W6: `DocumentSession.deleteHistoryRow`, `AppModel.register/session(for:)`, `CommandCenter`/`AppCommand`, `mdv6App` menus, and `WindowAccessor`'s drive hook.
- W10: `HistoryStep`, `ScrollKeys`.

## 3. Deliverables

### 3.1 `Preferences.swift` (+~6), `DocumentSession.swift` (+~120), `BookmarkTitle.swift` (+~8)

- **`closeFile()`:** calls `deleteHistoryRow(current)` with `persistOutgoing: false, pushSnapshot: false` (R-06 exception, R-47).
- **`stepFile(by:)`:** routes through `HistoryStep`; a selecting route; pushes a snapshot like a row click (R-48).
- **`anchorBlock()`:** hovered, else topmost visible, skipping a hidden header; nil for a header-only document, which makes ⌘D and ⌘⇧0 beep.
- **`BookmarkTitle`:** titles block 0 with a header as `Frontmatter`.
- **`cancelInFlightLoad()`**, for *Close All*.

### 3.2 `AppModel.swift` (+~60)

- **`closeAll()`:** cancel loads in every session, then `history.clear` (index rows and scroll positions go with it, bookmarks are kept), then clear every session's stacks, then set every session to `EMPTY` (E-36).
- **`targetSession`:** the key window if it is a document window, else the frontmost visible document window (`NSApp.orderedWindows`), else any (R-01).
- **`needsWindow` / `ensureWindow(for:)`:** creates a window only when the action has a file (E-38).

### 3.3 `mdv6App.swift` (+~80)

- **File menu:** *Close File* ⌘W, disabled while `EMPTY`; *Close Window* ⇧⌘W; *Close All* ⌥⌘W, disabled with empty history, opening a confirmation `NSAlert` with R-47's texts; *Print…* ⌘P, reserved and posted to the target (W14 fills it).
- **Navigate menu:** *Next File* ⇧⌘] and *Previous File* ⇧⌘[, with R-48's enablement.
- **View menu:** *Show Frontmatter*.
- **App delegate:**
  - `applicationShouldTerminateAfterLastWindowClosed` returns false;
  - `applicationShouldHandleReopen` creates a window that follows R-40;
  - `application(_:open:)` targets `targetSession`, creates a window via `ensureWindow` when there is none, and activates or fronts the window only when `NSApp.isActive`.

### 3.4 `ScrollKeys.swift` (+~70)

- `ScrollKeyMonitor`, fed by an enclosing-scroll-view accessor planted in `ArticleView`.
- The focus rule: first responder nil, the window, or a non-editable `NSText`.
- No ⌘, ⌥ or ⌃ modifier.
- Clamping through `constrainBoundsRect`.
- The *End* re-aim loop (K-18).
- `FileStepMonitor`, which consumes only Control-Tab.

### 3.5 `DocumentRootView.swift`, `WindowAccessor.swift` (+~30)

- Plant the accessor.
- Register the monitors per window.
- Add the drive-hook actions: `closeFile`, `closeAll` (with confirmation bypass), `nextFile`, `previousFile`, `scrollKey:<code>`.

## 4. Work items

- **W12-01 — preference key.**
  - *Red:* `PersistenceTests.testShowFrontmatterKey`: default true, wrong type → true, persists (C-04, T-42 list).
  - *Green:* the key.
- **W12-02 — header anchor rules.**
  - *Red:* `SessionTests.testHiddenHeaderAnchor`: with the header hidden and the top visible block 0, ⌘D anchors block 1; the block-0 bookmark title is `Frontmatter`; a header-only document makes ⌘D and ⌘⇧0 beep and add nothing (R-44, R-27, R-28, T-52).
  - *Green:* §3.1.
- **W12-03 — Close File.**
  - *Red:* `SessionTests.testCloseFile`: history A, B, C with C displayed; `closeFile` loads B; C's scroll position is absent from `scroll_positions`; no snapshot of C; ⌘← does not reach C; the last row gives `EMPTY` (R-47, R-06, T-55).
  - *Green.*
- **W12-04 — Close All.**
  - *Red:* `SessionTests.testCloseAllTwoSessions`: two sessions, one with a load in flight; after `closeAll`, history and index are empty, bookmarks remain, both sessions are `EMPTY` with empty stacks, and the in-flight load's completion adds no row (E-36, E-26).
  - *Green.*
- **W12-05 — Next / Previous File.**
  - *Red:* `SessionTests.testStepFile`: order unchanged; no reindex (index `indexed_at` unchanged); a snapshot is pushed; clamps at the ends (R-48, T-56).
  - *Green.*
- **W12-06 — routing and the zero-window state.**
  - *Red:* `SessionTests.testTargetSession`: the key doc window wins; with no key window, the frontmost doc window in the supplied order wins. `testTerminateAfterLastWindow` asserts false. `testEnsureWindowOnlyWithFile`: a cancelled open and ⌘0 with no placeholder create no window (R-01, E-38, T-61).
  - *Green:* §3.2 and §3.3.
- **W12-07 — keyboard scrolling.**
  - *Red:* `ChromeModelTests.testScrollKeyOwnership`: the focus rule as a pure function over responder kinds (E-37).
  - *Green:* §3.4.
  - *Evidence:* the drive hook scrolls the running app in the gate.

## 5. Test plan

| File | Spec ids | Runs |
|---|---|---|
| `SessionTests.swift` (+) | R-44, R-27, R-28, R-47, R-06, R-26, E-26, E-36, R-48, R-01, E-38, T-52, T-55, T-56, T-61 | `--filter SessionTests` |
| `PersistenceTests.swift` (+) | C-04, R-32, T-42 | `--filter PersistenceTests` |
| `ChromeModelTests.swift` (+) | R-49, E-37, K-18, T-57 | `--filter ChromeModelTests` |

## 6. Gate

1. `swift test --filter "SessionTests|ChromeModelTests|PersistenceTests"` → exit 0.
2. `make` → exit 0.
3. `tools/observe.sh w12 test-docs/math.md`. Then drive `closeFile`, `nextFile` and `scrollKey:119` (End), and `tools/observe.sh snap w12-end`. Expected: `build/observed/w12-end.png` shows the document's last block.
4. `swift test --parallel --xunit-output junit.xml` → exit 0.

## 7. Traceability

| Spec id | symbol | test | status |
|---|---|---|---|
| R-47, E-36 | `closeFile`, `AppModel.closeAll` | SessionTests | → realised (dialog observed W15) |
| R-48 | `stepFile`, `FileStepMonitor` | SessionTests | → realised (⌃⇥ observed W15) |
| R-49, E-37, K-18 | `ScrollKeyMonitor` | ChromeModelTests | → realised (observed W15) |
| R-01, E-38 | `targetSession`, `ensureWindow`, delegate | SessionTests | → realised (`open -g` observed W15) |
| R-44 session, R-27, R-28 | `anchorBlock`, `BookmarkTitle` | SessionTests | → realised |
| C-04 | `Preferences.Key.showFrontmatter` | PersistenceTests | → realised |

## 8. Traps

- **Reach.** `deleteHistoryRow` is cited by R-18, R-20, R-26 and §3.1, so its existing tests must stay green. `BookmarkTitle` is cited by R-27, R-28 and C-18.9, which has the placeholder row title.
- **Terminate-after-last-window** was `true` from W6. Flipping it changes a W6 behaviour, and T-47's "delete the only row reverts title" still holds.
- **Clean room**, as in W10.

## 9. Exit and handoff

- **Frozen:** `DocumentSession.closeFile()`, `.stepFile(by:)`, `.anchorBlock()`, `AppModel.closeAll()`, `.targetSession`, `.ensureWindow(for:)`, `AppCommand.print` (a slot W14 implements), the drive actions of §3.5.
- **Re-run gate:** item 4 above.
