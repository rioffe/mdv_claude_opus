# Detailed implementation plan — W5: Headless session

> - **Wave:** W5 of W0–W7 (`IMPLEMENTATION_PLAN.md` §4 item 6 — "Headless session").
> - **Spec basis:** `SPEC.md` v0.11, sha256 `eb28cfebe7456a5cfc05dca8df743dc1d2457514c68115a2b85334717437f897`; `TYPOGRAPHY.md`, sha256 `e3a6b1a4882106f26dc9a9dfe5f34ed6a5f41e4e62a60f16edf08cd0d28e52ad`. Neither is edited by this wave.
> - **Gate:** `swift test --filter mdv6Tests.SessionTests` exit 0 — every §3.1 transition and every headless clause of T-04, T-22, T-23, T-25, T-27, T-28, T-29, T-38, T-39, T-40 green on temp files and an isolated store.
> - **Budget:** 900–1,200 production lines across 4–5 files (`IMPLEMENTATION_PLAN.md` §5 row "Session").
> - **Depends on:** W1 (contracts), W2 (services), W4 (`ArticleHost`, `FindState`). **Unlocks:** W6 (every view binds to `DocumentSession`).

## 1. Objective and spec obligations

| spec id | obligation | how discharged |
|---|---|---|
| §3.1, R-01, R-04, E-03, E-04 | states; adding vs selecting routes; decode before any history change; multi-URL order, last displayed; directory (R-02); drop (R-03); unreadable keeps previous | `DocumentSession.open(_:route:)`, `loadDirectory`, `handleDrop`; T-04, T-39, T-25 |
| R-05, E-19, E-20, E-21, K-06, D-18 | path watcher; 50 ms, no deferral; rename/delete/recreate; failed read ignored; zero-byte re-read after 500 ms; position kept | `FileWatcher` (FSEvents on the parent directory, `kFSEventStreamCreateFlagFileEvents`, latency 0.05, no `NoDefer` flag); `DocumentSession.reload`; T-29 |
| R-06, C-08, E-08 | persist on close/quit/switch; restore when anchor + mtime + bounds valid | `persistScrollPosition`, `restoreScroll`; T-28 |
| R-18, E-27, D-30 | per-window stacks `(entry, topBlock)`; push rules incl. bookmark/placeholder/cold-start exceptions; drop on row removal; same-doc pushes; find never pushes | `NavStack`, `pushSnapshot`, `goBack/goForward`; T-22, T-25, T-27, T-28, T-40 |
| R-19, C-11, E-05, E-06, E-22, F-117 | resolve then classify; fragment decoded once; same-doc scroll; cross-file load at top with restoration suppressed | `handleLink(_:)`; T-22 |
| R-21 (model), E-29, D-41 | TOC list from `ParsedDocument`; `tocSelectedBlock` set by choice, kept on reload when the heading survives, cleared on document change; cross-file fragment selects | `selectTOC(blockIndex:)`, reload/clear rules; T-44 (model half) |
| R-22 (model), C-12 | `copySection(at:)` → pasteboard Markdown + `flashedRange` for 0.6 s | `copySection`; T-30 (model half) |
| R-23, §5.1 | editor path; ⌘E with none → prompt request; launch failure → `Diagnostics` + alert request | `openInEditor()` returning an `EditorOutcome`; T-38 |
| R-24, E-17, E-18, D-21, D-39 | find model: empty → no matches, verbatim substring, occurrences, wrap, reload recount → first, sidebar-focus routing decision | `FindModel` inside the session; T-23, T-39 |
| R-25 (routing), R-26 | search hits open as adding route when not in history, selecting when in history | `openHit(path:)` |
| R-27, R-28, E-09, E-27, C-18.9 (model) | anchor rule (hovered else topmost visible), title, five slots, missing-file beep, placeholder set/jump/clear, expands pane, current row | `bookmarkCurrentSpot`, `openBookmark`, `setPlaceholder/jumpToPlaceholder/clearPlaceholder`; T-26, T-27 |
| R-31 | Help.md overwritten to the support dir on every ⌘?, opened as adding route | `HelpManager.openHelp(session:)`; T-38 |
| R-40, E-30 (model), D-28, D-29 | launch restores head only; unreadable head stays and enters `EMPTY`; cold-start argument pre-empts with no snapshot | `AppModel.startup(arguments:)`, `DocumentSession.restoreOnLaunch/coldStart`; T-28 |
| E-25 | in-flight renders cancelled on document change | `renderGeneration` counter read by `MDVMermaidDiagramView`/math tasks (W4 reads it through `ArticleHost`) |
| E-26, R-01 (window half), D-19 | commands and open events act on the key window's session only | `AppModel.register(session:window:)`, `session(for: NSWindow?)`, `keySession`; T-40 (model half) |
| R-36, R-41 (document half), E-28 | document over 64 MiB aborts as E-03 before decoding | `readDocument` limit check; T-41 (document clause) |

## 2. Entry preconditions

W4 gate green. `FileSystem` (W2) available for injection; `ArticleHost` (W4) frozen. `Tests/mdv6Tests/SessionTests.swift` stub.

## 3. Deliverables (all `mdv6/Core/`)

### 3.1 `DocumentSession.swift` — NEW, ~600 lines (split into `DocumentSession.swift`, `DocumentSession+Navigation.swift`, `DocumentSession+Find.swift` if it passes 450)
```swift
public enum DocumentState: Equatable { case empty, loading, viewing, reloading, closed }
public enum OpenRoute { case adding, selecting }
public struct NavSnapshot: Equatable { let entry: HistoryEntry; let topBlock: Int }
@MainActor public final class DocumentSession: ObservableObject, ArticleHost {
    public init(model: AppModel, fileSystem: FileSystem = .live, watcherFactory: (URL, @escaping () -> Void) -> FileWatching = FileWatcher.init, clock: Clock = .live, pasteboard: PasteboardWriting = .system, systemOpener: (URL) -> Void = NSWorkspace…)
    @Published public private(set) var state: DocumentState; @Published public private(set) var document: ParsedDocument?; @Published public private(set) var currentEntry: HistoryEntry?
    @Published public var topVisibleBlock: Int; @Published public var hoveredBlock: Int?; @Published public var scrollTarget: Int?
    @Published public private(set) var tocSelectedBlock: Int?; @Published public private(set) var flashedRange: Range<Int>?; @Published public private(set) var findState: FindState?
    @Published public private(set) var currentBookmarkID: Int64?; @Published public private(set) var placeholderIsCurrent: Bool
    public var windowTitle: String   // file name or "mdv6"
    public var canGoBack/canGoForward: Bool; public var renderGeneration: Int
    // routes (R-01)
    @discardableResult public func open(_ url: URL, route: OpenRoute, suppressRestore: Bool = false, pushSnapshot: Bool = true) -> Bool
    public func open(urls: [URL])                       // each added in order, last displayed
    public func loadDirectory(_ url: URL) -> Bool        // R-02
    public func handleDrop(_ urls: [URL]) -> Bool        // R-03
    public func selectHistoryRow(_ entry: HistoryEntry); public func openHit(path: String); public func deleteHistoryRow(_ entry: HistoryEntry)
    public func handleLink(_ url: URL)                   // R-19
    public func goBack(); public func goForward()        // R-18, E-27 → beep via `beeper`
    public func selectTOC(blockIndex: Int)               // C-18.8 push + scroll + select
    public func copySection(at: Int)                     // R-22
    public func bookmarkCurrentSpot(); public func openBookmark(_ row: Database.BookmarkRow); public func openSlot(_ n: Int)
    public func setPlaceholder(); public func jumpToPlaceholder(); public func clearPlaceholder()
    public func openFind(); public func closeFind(); public func setFindQuery(_:); public func findNext(); public func findPrevious()
    public func persistScrollPosition(); public func windowWillClose()
    public func openInEditor() -> EditorOutcome; public func reloadFromDisk()   // watcher callback
    public func restoreOnLaunch(); public func coldStart(_ urls: [URL])
}
public enum EditorOutcome { case opened, needsChooser, failed(message: String) }
```
Rules, each cited in code: read+decode (UTF-8, ≤ 64 MiB) **before** any history change; adding → `history.add`, selecting → `history.select`; unreadable → previous state, no changes, `Diagnostics` silent; empty content → `viewing` with empty `ParsedDocument`; watcher re-armed only on success; `renderGeneration += 1` on every document change; `tocSelectedBlock` cleared on a different document, kept on reload when `blocks[i]` still starts with the same heading line; snapshots hold `(entry, topVisibleBlock)`; removing a row filters both stacks; `goBack` on a missing file → beep, discard, unchanged; fragments percent-decoded once (`removingPercentEncoding` nil → no match); `handleLink` classification exactly R-19's; `open(… suppressRestore: true)` for cross-file fragments; find recount on reload → current = 0; scroll persistence via `Database.saveScrollPosition` with mtime; restore via `AnchorValidity` + `resolveBookmarkAnchor`; bookmark anchor = `hoveredBlock ?? topVisibleBlock`; placeholder `current` from set/jump until document change; `openSlot` beeps on a missing file; `copySection` writes `sectionMarkdown` and sets `flashedRange` for 0.6 s (`clock`).

### 3.2 `FileWatcher.swift` — NEW, ~120 lines
`public protocol FileWatching: AnyObject { func cancel() }`; `public final class FileWatcher: FileWatching { public init(path: URL, onChange: @escaping () -> Void) }` — `FSEventStreamCreate` on the parent directory with `kFSEventStreamCreateFlagFileEvents | UseCFTypes`, latency 0.05, **without** `kFSEventStreamCreateFlagNoDefer` (the spec's "no deferral" is the first-event-at-once behaviour — as built: no `NoDefer`, latency 0.05 batches later events); filters events whose path equals the watched path; dispatches to main.

### 3.3 `HelpManager.swift` — NEW, ~40 lines
`public enum HelpManager { public static func openHelp(in session: DocumentSession, model: AppModel) }` — copy `Bundle.module` `Help.md` over `<supportDir>/Help.md` (overwrite every time), then `session.open(url, route: .adding)`.

### 3.4 `EditorLauncher.swift` — NEW, ~50 lines
`public enum EditorLauncher { static func open(file: URL, editorAppPath: String) -> Result<Void, Error> }` via `NSWorkspace.open(_:withApplicationAt:configuration:)`; failure → `Diagnostics.log(.editorLaunchFailure(text))`.

### 3.5 `AppModel.swift` — EDIT (adds startup/registry), ~90 lines added
`public func startup(arguments: [URL]) -> DocumentSession` (creates the main session; `arguments.isEmpty ? restoreOnLaunch() : coldStart(arguments)`), `register(session:window:)`, `unregister(window:)`, `session(for window: NSWindow?) -> DocumentSession?`, `var keySession: DocumentSession?` (by `NSApp.keyWindow`), `handleOpenEvent(urls:)` → `keySession?.open(urls:)` (or the main session when no key window yet: cold start).

## 4. Work items, in order

- **W5-01** `testEmptyToViewingOnOpen`, `testUnreadableKeepsPreviousAndHistory` (chmod 000, ISO-8859-1, vanished; state, entry, watcher count unchanged), `testEmptyFileIsViewing`, `testOversizedDocumentAbortsLikeE03` → `open`, `readDocument`.
- **W5-02** `testMultiURLOrderLastDisplayed`, `testDirectoryReadmeElseFirst`, `testDirectoryIgnoresHiddenAndOtherExtensions`, `testEmptyDirectoryNoChange`, `testDropFirstItemOnly`, `testDropRejectsPDF` → `open(urls:)`, `loadDirectory`, `handleDrop`.
- **W5-03** `testAddingVsSelectingRoutes` (sidebar row/search hit in history/⌘← keep order and index; ⌘O/link/bookmark/placeholder reorder) → routes.
- **W5-04** `testDeleteDisplayedRowLoadsNewHead`, `testDeleteLastRowEntersEmpty`, `testSnapshotsOfDeletedRowDropped` → `deleteHistoryRow`.
- **W5-05** `testBackForward_*` (push/clear forward; bookmark/placeholder/cold-start no push; same-doc fragment and TOC push; find never pushes; reopen current pushes nothing; missing file beeps and discards) → `NavStack`.
- **W5-06** `testHandleLink_*` (T-22 model clauses: sibling in-app; `file:` sibling in-app; `file:` `.txt`/missing → opener; `https:` → opener; broken local → opener, no navigation; same-doc fragment first match; `#example-1` no-op; percent-encoded UTF-8; invalid percent → no-op; cross-file fragment → top or slug, restore suppressed; h4/setext no-op) → `handleLink`.
- **W5-07** `testTOCSelection_*` (E-29: set by choice; scroll does not clear; reload keeps when heading survives; document change clears; cross-file fragment selects) → `selectTOC`.
- **W5-08** `testCopySectionFlash` (pasteboard text; range; flash cleared after 0.6 s of injected clock) → `copySection`.
- **W5-09** `testFind_*` (T-23/T-39 model: empty → no matches, stepping disabled; whitespace verbatim; three "the" in one block → +3 and three steps in that block; wrap; reload adds one → `m+1`, `1 of m`) → `FindModel`.
- **W5-10** `testBookmarks_*` (anchor hovered else topmost; title; slots 1–5; missing file beeps; opening a bookmark in another file loads without push) and `testPlaceholder_*` (T-27 model: set → current, expands pane pref; jump returns; jump loads other file as adding without push; missing → beep keep; clear → beep; new `AppModel` on relaunch → none) → bookmark/placeholder APIs.
- **W5-11** `testScrollPersistAndRestore_*` (T-28 model: persisted on switch/close; restored when mtime within 1 s and index in bounds; mtime changed → top; fingerprint moves; index clamped) → scroll.
- **W5-12** `testWatcher_*` (T-29 with a real temp file and `FileWatcher`: five writes within 50 ms → ≤ 2 reloads, last content; atomic rename reloads; delete keeps; recreate reloads; invalid UTF-8 ignored; zero-byte then write 100 ms later → no empty document ever published; zero-byte left 1 s → empty) → `FileWatcher`, `reloadFromDisk`.
- **W5-13** `testStartup_*` (T-28 model: head restored with position; unreadable head → `EMPTY`, rows retained, later row untried; empty history → `EMPTY`; cold-start B with head A → B displayed, `canGoBack == false`) → `AppModel.startup`, `restoreOnLaunch/coldStart`.
- **W5-14** `testKeyWindowRouting` (two sessions registered with two `NSWindow`s; `handleOpenEvent` reaches only the key one; `session(for:)`) → registry (T-40 model half).
- **W5-15** `testHelpOverwritten` (two `openHelp` calls → the file rewritten, history has one Help row at top, adding route) and `testEditorOutcomes` → `HelpManager`, `EditorLauncher`.

## 5. Test plan

| target file | spec ids | asserted | runs |
|---|---|---|---|
| `Tests/mdv6Tests/SessionTests.swift` (+ `NavigationTests.swift`, `FindModelTests.swift`, `WatcherTests.swift`) | §3.1, R-01..R-06, R-18, R-19, R-21..R-28, R-31, R-36, R-40, R-41, C-08, C-11, C-12, I-004, I-013, K-06, E-03..E-06, E-08, E-09, E-17..E-22, E-25..E-30, T-04, T-22, T-23, T-25, T-26, T-27, T-28, T-29, T-30, T-38, T-39, T-40 | §4 outcomes with injected `FileSystem`/clock where stated and real files for the watcher | `swift test --filter mdv6Tests` |

## 6. Gate

1. `swift test --xunit-output junit.xml` — exit 0, 0 skipped.
2. `speccheck … --judge mock` — 0 dangling, 0 stale; every §1 id `PASSING`.
3. `grep -c "history.add\|history.select" mdv6/Core/DocumentSession*.swift` ≥ 2 and every `history.add` call is preceded in the same function by `readDocument` (inspection; note the line numbers in the commit body).

## 7. Traceability

§1 ids: not yet realised → realised (model); their window clauses (menus, panels, beeps as sound, pointer, selection) → W6/W7.

## 8. Risks and traps

- **FSEvents latency semantics:** `kFSEventStreamCreateFlagNoDefer` delivers the *first* event immediately and defers later ones — the spec's "first event of a burst is delivered at once and later events batched into at most one further delivery" is exactly `NoDefer` behaviour; R-05's parenthetical "no deferral" names the flag. Use `NoDefer` + 0.05 s and let W5-12 measure ≤ 2 reloads; if the count exceeds 2, the flag is the first suspect (this corrects §3.2's wording above — the test decides).
- **`@MainActor` tests:** mark the test class `@MainActor` and use `XCTestExpectation` for watcher events (timeouts ≥ 2 s).
- **Rule (§6 "multi-window"):** no `static` current session; everything routes through `AppModel.session(for:)`.
- **Rule (R-04):** `readDocument` is the only reader and is called before `history.add` in every adding path — gate 3.

## 9. Exit criteria and handoff contract

Frozen: every signature in §3.1 and §3.5; `EditorOutcome`; `FileWatching`. W6 calls them by name; W6 provides `beeper`, `pasteboard`, `systemOpener` defaults from AppKit. Next wave re-runs `swift test` (expected exit 0).
