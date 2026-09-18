# Detailed implementation plan — W2: Persistence and history

> - **Wave:** W2 of W0–W7 (`IMPLEMENTATION_PLAN.md` §4 item 3 — "Persistence and history").
> - **Spec basis:** `SPEC.md` v0.11, sha256 `eb28cfebe7456a5cfc05dca8df743dc1d2457514c68115a2b85334717437f897`; `TYPOGRAPHY.md`, sha256 `e3a6b1a4882106f26dc9a9dfe5f34ed6a5f41e4e62a60f16edf08cd0d28e52ad`. Neither is edited by this wave.
> - **Gate:** `swift test --filter mdv6Tests.PersistenceTests` exit 0 against a temp-dir store; T-24, T-25, T-26, T-28, T-33, T-42 store clauses green.
> - **Budget:** 700–900 production lines across 5–6 files (`IMPLEMENTATION_PLAN.md` §5 row "Persistence").
> - **Depends on:** W1 (`FTSQuery`, `HistoryCodec`, `bookmarkFingerprint`, `AnchorValidity`, `ThemeCatalog`, `ZoomStep.clampOnRead`, `Diagnostics`). **Unlocks:** W5 (`DocumentSession` uses every service here), W6 (`AppModel`, preference bindings).

## 1. Objective and spec obligations

| spec id | obligation | how discharged |
|---|---|---|
| C-03 (schema half), R-25 (store half), K-03, K-09 | `articles` + `articles_fts` + triggers, search with rank/path order, LIMIT 80, snippet 14 | `Database.indexFile/search/removeFile/prune`; T-24 |
| C-08 (tables), R-06 (store half), E-08 | `bookmarks`, `scroll_positions`, restore validity | `Database.bookmarks/scroll` API; T-26, T-28 |
| §3.3, I-006, I-007, E-12, T-33 | FULLMUTEX/WAL/NORMAL; `meta.schema_version` 4; one-transaction migrations; upserts; degrade on failure | `Database.open/migrate`; corrupt-file and kill-loop tests |
| R-20, R-26, I-013, K-03, C-15 | history list, cap 100, adding vs selecting, eviction prunes index and scroll row, launch re-index skipping unchanged mtime, launch prune | `HistoryManager`; T-25, T-24 |
| R-27 (store half) | persisted order, five slots, reorder, remove, duplicates allowed | `BookmarksManager`; T-26, T-48 (reorder rules) |
| R-28 (store half) | transient in-memory placeholder with path, index, fingerprint, title; never persisted | `PlaceholderStore`; T-27 (relaunch beeps) |
| C-04, R-32, T-42 | every key, default and invalid-value fallback | `Preferences` over an injected `UserDefaults`; T-42 |
| §10 | `MDV6_SUPPORT_DIR`, `MDV6_DEFAULTS_SUITE`; empty = unset; test bootstrap precedence | `AppModel.bootstrap(supportDir:defaultsSuite:)` |
| R-35, I-003 | only `[mdv6]` failure lines; no content in logs | `Diagnostics.log(.storeFailure)` at each failure site; log-capture test |

## 2. Entry preconditions

W1 gate green. `Tests/mdv6Tests/PersistenceTests.swift` stub. System `libsqlite3` linked (W0 `linkerSettings`); `import SQLite3`.

## 3. Deliverables (all `mdv6/Core/`)

### 3.1 `Database.swift` — NEW, ~330 lines
```swift
public final class Database {
    public init(url: URL)                                   // opens (creating the directory), sets pragmas, migrates; failures → Diagnostics + `isAvailable = false`
    public private(set) var isAvailable: Bool
    // C-03
    public func indexFile(path: String, content: String, mtime: Int, size: Int)   // INSERT … ON CONFLICT(path) DO UPDATE
    public func indexedMtime(path: String) -> Int?
    public func removeFile(path: String)                    // articles row (+fts via trigger) + scroll_positions row; bookmarks kept
    public func prune(keeping paths: Set<String>)           // launch: drop index rows not in history
    public struct SearchHit: Equatable { public let path: String; public let filename: String; public let snippet: String }
    public func search(_ input: String) -> [SearchHit]      // FTSQuery.make → nil ⇒ []; ORDER BY rank ASC, path COLLATE NOCASE ASC, path ASC LIMIT 80; snippet(articles_fts,1,char(2),char(3),'…',14)
    // C-08
    public struct BookmarkRow: Equatable, Identifiable { id: Int64, path, title, sortOrder: Int, createdAt: Int, blockIndex: Int, fingerprint: String }
    public func bookmarks() -> [BookmarkRow]; public func addBookmark(path:title:blockIndex:fingerprint:) -> BookmarkRow?
    public func removeBookmark(id:); public func reorderBookmarks(ids: [Int64])   // one transaction, sort_order = position
    public struct ScrollRow: Equatable { blockIndex: Int, fingerprint: String, fileMtime: Int }
    public func scrollPosition(path:) -> ScrollRow?; public func saveScrollPosition(path:blockIndex:fingerprint:fileMtime:); public func removeScrollPosition(path:)
    static let schemaVersion = 4
}
```
`sqlite3_open_v2` with `SQLITE_OPEN_READWRITE | CREATE | FULLMUTEX`; `PRAGMA journal_mode=WAL; synchronous=NORMAL`. `migrate()`: read `meta.schema_version` (0 when absent); for each version `v < 4`: `BEGIN IMMEDIATE`, statements, `UPDATE meta SET value=v+1`, `COMMIT`; on error `ROLLBACK` + `Diagnostics.log(.storeFailure(...))` and stop. Every write is a single statement or a `BEGIN IMMEDIATE…COMMIT` (I-007). Statement failures log once and return empty results (E-12). No query string or content is passed to `Diagnostics`.

### 3.2 `HistoryManager.swift` — EDIT (adds the manager below W1's codec), ~180 lines
```swift
public final class HistoryManager: ObservableObject {
    public init(defaults: UserDefaults, database: Database, fileSystem: FileSystem = .live)
    @Published public private(set) var entries: [HistoryEntry]          // most recently added first, ≤ 100, no duplicate paths
    @discardableResult public func add(path: String, content: String? = nil) -> HistoryEntry   // adding route: move/insert at top, index (mtime-gated), evict > 100 (removeFile + scroll row), save
    public func select(path: String) -> HistoryEntry?                    // selecting route: no reorder, no index
    public func remove(_ entry: HistoryEntry) -> HistoryEntry?           // returns the new head (for §3.1 delete-current transitions)
    public func reindexOnLaunch()                                        // background queue: prune(keeping:), then index rows whose mtime changed
    public func clear()                                                  // exists, unreachable from UI (R-26)
    public static let cap = 100
}
```
`FileSystem` is a tiny struct of closures (`readUTF8`, `mtimeSeconds`, `exists`) so tests inject files without touching disk — used again by W5.

### 3.3 `BookmarksManager.swift` — NEW, ~120 lines
`ObservableObject` over `Database`: `bookmarks: [BookmarkRow]` in `sort_order`; `add(path:blocks:toc:index:)` (title by `BookmarkTitle.title`, fingerprint by `bookmarkFingerprint`); `remove(id:)`; `move(id:to:)`, `moveUp/moveDown/moveToTop/moveToBottom(id:)` (persisted through `reorderBookmarks`); `slot(_ n: Int) -> BookmarkRow?` for 1…5; `hasBookmark(path:) -> Bool` (toolbar tint); `isMissing(_:) -> Bool` via `FileSystem.exists`.

### 3.4 `PlaceholderStore.swift` — NEW, ~40 lines
`public struct Placeholder: Equatable { path, blockIndex, fingerprint, title }`; `public final class PlaceholderStore: ObservableObject { @Published public var placeholder: Placeholder?; set/clear }` — memory only; never touches defaults or the database (R-28).

### 3.5 `Preferences.swift` — NEW, ~130 lines
`public final class Preferences: ObservableObject` over an injected `UserDefaults`: one property per C-04 key with the key string as a `static let`, typed reads with the fallback paragraph of C-04 (`themeId` unknown → `high-contrast`; `fontScale` via `ZoomStep.clampOnRead`, wrong type → 1.0; `inspectorWidth` clamped 180…520; `bookmarksHeight` ≥ 120 clamp at use; `mermaidStyle` unknown → `document`; `history` via `HistoryCodec.decode`), writes on `didSet`.

### 3.6 `AppModel.swift` — NEW (W2 owns bootstrap; W5 adds `startup/register`), ~90 lines
```swift
public final class AppModel {
    public static func bootstrap(supportDir: URL? = nil, defaultsSuite: String? = nil, environment: [String: String] = ProcessInfo.processInfo.environment) -> AppModel
    public let supportDirectory: URL; public let defaults: UserDefaults; public let database: Database
    public let preferences: Preferences; public let history: HistoryManager; public let bookmarks: BookmarksManager; public let placeholder: PlaceholderStore
}
```
Precedence: explicit arguments (tests) → `MDV6_SUPPORT_DIR` / `MDV6_DEFAULTS_SUITE` (non-empty) → `~/Library/Application Support/mdv6` and `UserDefaults.standard`. Creates the support directory if absent.

## 4. Work items, in order

- **W2-01** `testOpenCreatesSchemaV4` (temp dir; tables exist; `meta.schema_version == 4`; `PRAGMA journal_mode` = `wal`) → `Database.init/migrate`.
- **W2-02** `testMigrationIsAtomic` (inject a failing statement into migration 3 through a test hook `Database.migrationOverride`; version stays 2; next open with the hook removed reaches 4) → transaction wrapping.
- **W2-03** `testCorruptFileDegrades` (write 100 random bytes to `mdv6.db`; `isAvailable == false`; `search` → `[]`; `bookmarks()` → `[]`; a `[mdv6]` line captured via a `Diagnostics.sink` test hook) → E-12 paths.
- **W2-04** `testIndexAndSearch_*` (T-24: `auth` finds `authentication` with U+0002/U+0003 around the term; `résumé` matches `resume`; empty/whitespace → `[]`; re-index skipped on equal mtime; 81 equal-rank files inserted in reverse path order → first 80 by `path COLLATE NOCASE` then binary; repeated query identical) → `indexFile/search`.
- **W2-05** `testRemoveFileDropsIndexAndScrollKeepsBookmarks`, `testPruneKeepsOnlyHistory` → `removeFile/prune`.
- **W2-06** `testBookmarks_*` (add returns row with title/fingerprint; duplicates create two rows; reorder persists; remove) and `testScroll_*` (upsert; `AnchorValidity` applied by W5, here the row round-trips) → bookmark/scroll API.
- **W2-07** `testUpsertIsWholeRow` (T-33 kill-loop stand-in: run 200 `addBookmark` calls on a background thread while the main thread reopens the file with a second `Database`; every row read is complete — non-empty title and fingerprint) → I-007.
- **W2-08** `testHistoryAdd_*` (T-25: 101 adds → 100 entries, newest first, evicted path removed from index and scroll table; re-add moves to top; `select` leaves order and index untouched; `remove` returns the new head; encoded value decodes per C-15) → `HistoryManager`.
- **W2-09** `testReindexOnLaunch` (changed mtime re-indexed; unchanged skipped; orphan index row pruned) → `reindexOnLaunch`.
- **W2-10** `testPreferences_*` (T-42: every key default; wrong type, out-of-range, malformed history JSON, unknown theme and Mermaid ids fall back exactly) → `Preferences`.
- **W2-11** `testBootstrapIsolation` (env vars honoured; empty value = unset; explicit args win; directory created) → `AppModel.bootstrap`.
- **W2-12** `testPlaceholderNeverPersists` (set, then a new `AppModel` on the same store has none) → `PlaceholderStore`.

## 5. Test plan

| target file | spec ids | asserted | runs |
|---|---|---|---|
| `Tests/mdv6Tests/PersistenceTests.swift` | C-03, C-04, C-08, C-15, R-06, R-20, R-25, R-26, R-27, R-28, R-32, R-35, I-003, I-006, I-007, I-013, K-03, K-06, K-09, E-08, E-12, E-24, §3.3, §10, T-24, T-25, T-26, T-28, T-33, T-42 | §4 outcomes on a temp-dir store and a suite-named `UserDefaults` that is removed in `tearDown` | `swift test --filter PersistenceTests` |

## 6. Gate

1. `swift test --filter mdv6Tests --xunit-output junit.xml` — exit 0, 0 skipped.
2. `speccheck … --judge mock --out build/speccheck` — 0 dangling, 0 stale; every §1 id `PASSING` or, for the "(half)" ids, cited by a passing test.
3. `ls ~/Library/Application\ Support/mdv6 2>/dev/null` unchanged by the test run (isolation proven: the test bootstrap never touched the real store).

## 7. Traceability

§1 ids: not yet realised → realised (store half). R-06/R-27/R-28 remainder → W5; C-04 bindings in menus → W6.

## 8. Risks and traps

- **FTS5 external-content tables** need the three triggers (`ai`, `ad`, `au`) with the `'delete'` command form; a missing `au` trigger leaves stale snippets. Test W2-04's re-index case catches it.
- **`sqlite3_bind_text` lifetime:** always `SQLITE_TRANSIENT`.
- **`UserDefaults(suiteName:)` persists to disk**; tests call `removePersistentDomain(forName:)` in `tearDown`.
- **Rule (§6 "parser before ceiling"):** not applicable here; **Rule (R-35):** `Diagnostics` receives only `sqlite3_errmsg` text and the store path, never a query or content — asserted by W2-03's captured line.

## 9. Exit criteria and handoff contract

Frozen: every signature in §3. W5 calls `AppModel.bootstrap`, `HistoryManager.add/select/remove/reindexOnLaunch`, `BookmarksManager.*`, `PlaceholderStore`, `Database.scrollPosition/saveScrollPosition`, `Database.search`; W6 binds `Preferences`. Next wave re-runs `swift test --filter mdv6Tests` (expected exit 0).
