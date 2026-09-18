# Detailed implementation plan — W6: Window chrome

> - **Wave:** W6 of W0–W7 (`IMPLEMENTATION_PLAN.md` §4 item 7 — "Window chrome").
> - **Spec basis:** `SPEC.md` v0.11, sha256 `eb28cfebe7456a5cfc05dca8df743dc1d2457514c68115a2b85334717437f897`; `TYPOGRAPHY.md`, sha256 `e3a6b1a4882106f26dc9a9dfe5f34ed6a5f41e4e62a60f16edf08cd0d28e52ad`. Neither is edited by this wave.
> - **Gate:** `swift build` and `make` exit 0; `swift test --filter ChromeModelTests` exit 0 (T-48 menu order/enablement/reorder, C-18 metrics, I-015 over `MDVTheme.all`); the app launches on `test-docs/math.md` with an isolated store and shows the three panes.
> - **Budget:** 1,100–1,500 production lines across 6–7 files (`IMPLEMENTATION_PLAN.md` §5 row "Chrome").
> - **Depends on:** W5 (`DocumentSession`, `AppModel`), W4 (`ArticleView`), W2 (`Preferences`). **Unlocks:** W7 (the observed pass).

## 1. Objective and spec obligations

| spec id | obligation | how discharged |
|---|---|---|
| §5.1, C-14, R-23, R-29, R-30, R-31, R-16, R-17, R-20, R-21, R-27, R-28, R-18, R-24, R-25 | every menu item, shortcut, enablement and beep; the CLI-install alert flow; the editor alert with *Choose Different Editor…*/*Cancel* | `mdv6App.swift` (`Commands`), notifications addressed to `NSApp.keyWindow` (E-26) |
| E-30, R-40 | `NSWindow.isRestorable = false`; no state-restoration opt-in; one window per launch | `WindowAccessor.swift`, `applicationSupportsSecureRestorableState` false |
| C-18.1, R-42, T-47 | title = file name or `mdv6`; toolbar strip painted page colour; window colour scheme by `isDark`; 1 pt dividers in 8 pt handles; collapse chevron (hover-only on the handle; always visible when collapsed) | `DocumentRootView.swift` |
| C-18.2, §5.1 Toolbar | five icon-only trailing buttons in order with `.help` tooltips; palette pop-up with checkmark; bookmark filled when the file has one; `sidebar.right` tinted when shown | `DocumentRootView` toolbar |
| C-18.3, C-18.4, C-18.5, C-18.6, C-18.8, C-18.9, K-16, I-015 | headers, reveal-on-click search, history rows, hits, TOC rows, bookmark and placeholder rows, badges, states, context menus | `SidebarViews.swift` over `ChromeModel.swift` |
| C-18.7 (find button) | floating 28 pt find button top-trailing while the bar is closed | `DocumentRootView` overlay |
| R-24 (bar), E-18 | find bar with "n of m"/"No matches", ⌘G/⇧⌘G/Esc; ⌘F routes to the history field when the sidebar has focus | `FindBar.swift`; first-responder check in `DocumentRootView` |
| R-25 (UI) | global search field + hit list ≤ 80 with highlighted snippets | `SidebarViews` search section |
| K-04, R-20, R-21, C-04 | sidebar 180–400 (not persisted), inspector 180–520 persisted, bookmarks height ≥ 120 with TOC ≥ 80 | drag handles in `DocumentRootView`, `Preferences` |
| R-30 (HUD), K-06 | zoom HUD 0.9 s showing `hudPercent` | `ZoomHUD` in `DocumentRootView` |
| R-09 (style menu persistence), R-16 (toggle cancels in-flight) | View menu toggles bound to `Preferences`; `RemoteImageLoader.cancelAll()` on off | `mdv6App` |
| T-48 (scripted half), R-27 | context-menu order, enablement on first/last rows, reorder semantics and slot follow | `ChromeModel.bookmarkMenu(for:)`, `BookmarksManager.move*` (W2) |

## 2. Entry preconditions

W5 gate green; `Tests/mdv6Tests/ChromeModelTests.swift` stub; `mdv6/AppIcon.icns` present; `make` works (W0).

## 3. Deliverables (all `mdv6/Core/`)

### 3.1 `ChromeModel.swift` — NEW, ~200 lines
```swift
public enum ChromeMetrics { headerFont 11 semibold uppercase, tracking 0.6; headerPaddingH 14, top 14, bottom 6; bookmarksHeaderHeight 32; chevron 9 semibold / 10 wide; countCapsule 10 medium monospacedDigit, 5/1; searchButton 11 semibold, hit 18×18; historyGlyph 13 / 16 wide, name 13, path 11, vPad 2; hitSnippet; tocFont 12, indent 14, pad 8/5, radius 4, maxLines 2; bookmarkGlyph 11 / 16 wide, title 13, file 10, badgeCmd 9 bold rounded, badgeDigit 10 bold rounded, badgeRadius 4, badgePad 5/1, rowPad 8/5, rowRadius 5; placeholderGlyph 12, title 13 medium; dividerInset 8 / 2; findButton 28, stroke 0.5, glyph 13 semibold; stripeWidth 3; revealDuration 0.20, focusDelay 0.05; emptyTray 24 light, emptyText 12; handleWidth 8; chevronGlyph 11 }
public enum ChromeOpacity { hover 0.06, tocHover 0.08, dropTarget 0.18, badge 0.85, glyph 0.70, placeholderTint 0.08, placeholderStroke 0.25, missing 0.60, capsule 0.06 }
public enum ChromeRules {
    static func windowTitle(fileName: String?) -> String
    static func colorScheme(for: MDVTheme) -> ColorScheme
    static func historyPathDisplay(_ path: String, home: String) -> String          // ~ abbreviation; head truncation is a view modifier
    static func tocIndent(level: Int) -> CGFloat; static func tocFont(level:) -> (size: CGFloat, weight: Font.Weight); static func tocColor(level:, theme:) -> Color
    public enum BookmarkMenuItem: Equatable { goTo, revealInFinder, moveUp, moveDown, moveToTop, moveToBottom, remove }
    static func bookmarkMenu(rowIndex: Int, count: Int, fileExists: Bool) -> [(item: BookmarkMenuItem, enabled: Bool)]   // exact C-18.9 order (separators are view-level)
    static let placeholderMenu: [String] = ["Clear Placeholder"]
    static func rowStyle(current: Bool, hovered: Bool, missing: Bool, dropTarget: Bool, theme: MDVTheme) -> RowStyle   // fill, text colour, glyph colour, badge fg/bg, opacity
    static func badge(slot: Int?) -> String?; static func toolbarItems() -> [ToolbarItemSpec]  // plus, pencil, paintpalette, bookmark, sidebar.right with tooltips
    static func sidebarHasFocus(firstResponder: NSResponder?, sidebarView: NSView?) -> Bool
}
```
Everything here is theme-independent data; colours come only from the `MDVTheme` argument (I-015).

### 3.2 `SidebarViews.swift` — NEW, ~450 lines
`HistorySidebar` (header `HISTORY` + magnifier → `RevealSearchField`; `List(selection:)` `.sidebar` style of `HistoryRow` — `doc.text`, name middle-truncated, `~` path head-truncated (`.truncationMode(.head)`), swipe-to-delete; empty state `tray` + *No files yet*; hit list of `SearchHitRow` when the field has text — current file accent fill with page-colour text, hover `text.opacity(0.06)`), `Inspector` (`ON THIS PAGE` header + filter field; `TOCRow`s; `BookmarksPane` with the 32 pt toggle header, chevron, count capsule, draggable height; `PlaceholderRow` first with divider; `BookmarkRow`s with badges, drag reorder (`onMove`), both context menus built from `ChromeRules`). All colours from `theme`; all sizes from `ChromeMetrics`.

### 3.3 `DocumentRootView.swift` — NEW, ~380 lines
`HSplit`-like custom layout: sidebar (collapsible; width 180–400 drag; handle with hover chevron), article (`ArticleView` + floating find button + `FindBar` + `ZoomHUD` + stripe host + drop target + `EMPTY` placeholder panel), inspector (width persisted 180–520; left-edge drag). `.navigationTitle(session.windowTitle)`, `.toolbarBackground(theme.background, for: .windowToolbar)` + `.toolbarColorScheme`, `.preferredColorScheme(ChromeRules.colorScheme(for: theme))` scoped to the window, `.toolbar { ToolbarItemGroup(placement: .primaryAction) { … five buttons … } }`. `NotificationHandlers` view modifier: every `Notification.Name.mdv6*` command is honoured only when `notification.userInfo["window"] as? NSWindow === hostWindow`. `WindowAccessor` (`NSViewRepresentable`) captures the `NSWindow`, sets `isRestorable = false`, `tabbingMode = .disallowed`, registers with `AppModel`, unregisters and calls `session.windowWillClose()` on close.

### 3.4 `FindBar.swift` — NEW, ~90 lines
Field, "n of m"/"No matches", previous/next/close buttons, ⌘G/⇧⌘G/Esc key handling; stepping disabled with no matches.

### 3.5 `mdv6App.swift` — EDIT (replaces the W0 stub), ~300 lines
`mdv6Main.run()` builds `AppModel.bootstrap()`, registers fonts, sets `NSApplicationDelegateAdaptor`-equivalent delegate (`application(_:open:)` → `model.handleOpenEvent`; `applicationSupportsSecureRestorableState` false; cold-start argument from `CommandLine.arguments`), `WindowGroup` with `DocumentRootView(session:)` — `handlesExternalEvents` disabled so LaunchServices does not spawn windows; ⌘⇧O creates a second window with its own session. `Commands`: the §5.1 table verbatim (`mdv6 · Install Command Line Tool…`, File, Edit, Navigate, View incl. `Show/Hide Inspector ⌥⌘0`, Bookmarks with slots 1–5, Help), each posting an addressed notification or acting on `model.keySession`; enablement rules (zoom clamps, Actual Size at 1.0, slot empty, smart typography "(off for this theme)"); CLI install (`ln -s` unprivileged, then `NSAppleScript` with administrator privileges; the four `NSAlert`s; cancel → no alert); editor alert with *Choose Different Editor…*; `NSOpenPanel` for ⌘O/⌘⇧O and the editor chooser (`.app` bundles).

## 4. Work items, in order

- **W6-01** `ChromeModelTests.testBookmarkMenuOrderAndEnablement` (seven items in order; first row: `moveUp`/`moveToTop` disabled; last: `moveDown`/`moveToBottom`; missing file: `revealInFinder` disabled), `testPlaceholderMenuIsExactlyClear` → `ChromeRules.bookmarkMenu`.
- **W6-02** `testReorderFollowsSlots` (W2's `move*` through a temp store: third → `moveUp` → second and `slot(2)` is it; `moveToBottom` → last; relaunch keeps order) — T-48 scripted half.
- **W6-03** `testMetricsTable` (every K-16 number equals `ChromeMetrics`), `testRowStyleOverAllThemes` (for each of the nine themes: current → fill accent and text = background; hovered → `text.opacity(0.06)`; missing → 0.6; badge inverted when current), `testWindowTitle`, `testColorScheme`, `testHistoryPathAbbreviation`, `testTOCIndent` → `ChromeModel`.
- **W6-04** `testSidebarFocusRule` (an `NSTextField` inside a marked sidebar `NSView` as first responder → true; nil → false) → `ChromeRules.sidebarHasFocus`.
- **W6-05** `testToolbarSpec` (five items, glyph names, tooltips, order) → `ChromeRules.toolbarItems`.
- **W6-06** Build the views (`SidebarViews`, `DocumentRootView`, `FindBar`, `mdv6App`) against the rules; `swift build`; `make`; launch with the isolated store on `test-docs/math.md`; quit. (No test certifies a view here — W7 looks.)
- **W6-07** `ChromeSnapshotTests.testHostedWindowSnapshot` (stand-in for the live pass, §6 of the plan: hosts `DocumentRootView` in an offscreen window with the T-44 fixture, writes `build/observed/snapshot-<theme>.png` for Sevilla/Charcoal/Twilight; asserts only that the file exists and is non-blank — a person compares it in W7).

## 5. Test plan

| target file | spec ids | asserted | runs |
|---|---|---|---|
| `Tests/mdv6Tests/ChromeModelTests.swift` | C-18, K-16, I-015, R-27, R-28, R-42, E-18, T-48 (scripted half), T-44 (rule half) | §4 outcomes over `MDVTheme.all` | `swift test --filter ChromeModelTests` |
| `Tests/mdv6RenderTests/ChromeSnapshotTests.swift` | C-18, I-015, T-44 (stand-in) | snapshot files written | `swift test --filter ChromeSnapshotTests` |

## 6. Gate

1. `swift test --xunit-output junit.xml` — exit 0.
2. `make` — exit 0; `codesign --verify --deep --strict build/mdv6.app` — exit 0.
3. `MDV6_SUPPORT_DIR="$TMPDIR/mdv6-w6" MDV6_DEFAULTS_SUITE=mdv6.w6 open -W -a build/mdv6.app test-docs/math.md` — the window opens titled `math.md` with the three panes (observed by the executor; quit with ⌘Q); `ls "$TMPDIR/mdv6-w6"` shows `mdv6.db`; `defaults read mdv6.w6 mdv6_history` decodes with one entry.
4. `speccheck … --judge mock` — 0 dangling, 0 stale; §1 ids cited.

## 7. Traceability

§1 ids: not yet realised → realised (*verification pending* until W7's observed pass for C-18, R-42, I-015, K-16, T-44, T-47, T-48, E-30).

## 8. Risks and traps

- **`.preferredColorScheme` is app-wide in SwiftUI** — apply the scheme on the `NSWindow.appearance` through `WindowAccessor` instead (C-18.1 says the application-wide appearance is not changed).
- **`List(selection:)` with `.sidebar` style** draws the selection; a `ForEach` in a `ScrollView` does not — C-18.5 names the list style.
- **Reveal-on-click focus** needs `@FocusState` set after 0.05 s; setting it in the same transaction as the animation fails silently.
- **Rule (§6 "chrome without oracle"):** every number in a view comes from `ChromeMetrics`; `grep -n "[0-9]\+ *pt\|font(.system(size: [0-9]" mdv6/Core/SidebarViews.swift` must return nothing (literal sizes live in `ChromeModel`).
- **Rule (E-26):** `NSApp.keyWindow` is read when the notification is *posted*, not handled.

## 9. Exit criteria and handoff contract

Frozen: `ChromeRules`, `ChromeMetrics`, `ChromeOpacity`, notification names, `WindowAccessor`. W7 drives the built app and reads the isolated store. Next wave re-runs `swift test && make` (expected exit 0).
