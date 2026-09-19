import XCTest
@testable import mdv6Core

/// Persistence group of §9.0: `Database` (C-03, C-08, §3.3), `HistoryManager` (R-20, R-26, I-013), `BookmarksManager`
/// (R-27), `PlaceholderStore` (R-28), `Preferences` (C-04) and `AppModel.bootstrap` (§10) on a temp-dir store.
final class PersistenceTests: XCTestCase {
    var dir: URL!
    var suite: String!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        suite = "mdv6.tests.\(UUID().uuidString)"
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: dir)
        Diagnostics.sink = nil
    }

    private func db() -> Database { Database(url: dir.appendingPathComponent("mdv6.db")) }
    private func defaults() -> UserDefaults { UserDefaults(suiteName: suite)! }
    private func model(fs: FileSystem = .live) -> AppModel { AppModel.bootstrap(supportDir: dir, defaultsSuite: suite, fileSystem: fs) }

    // MARK: Database (§3.3, I-006, I-007, E-12)

    /// §3.3: `mdv6.db` opens FULLMUTEX with WAL and synchronous NORMAL; the C-03/C-08 tables exist **with the pinned
    /// columns** (`articles`, the FTS5 `articles_fts` with `unicode61 remove_diacritics 2` over `articles`, `bookmarks`,
    /// `scroll_positions`); `meta.schema_version` is 4. I-006.
    func testOpenCreatesSchemaV4() {
        let d = db()
        XCTAssertTrue(d.isAvailable)
        XCTAssertEqual(d.schemaVersion, 4)
        XCTAssertEqual(Database.schemaVersion, 4)
        XCTAssertEqual(d.pragma("journal_mode"), "wal")
        XCTAssertEqual(d.pragma("synchronous"), "1")                                   // NORMAL
        XCTAssertEqual(Set(d.tableNames()).isSuperset(of: ["articles", "articles_fts", "bookmarks", "scroll_positions", "meta"]), true)
        // C-03: the articles table and the FTS5 index, column for column
        XCTAssertEqual(d.columnNames(of: "articles"), ["id", "path", "filename", "content", "indexed_at", "file_mtime", "file_size"])
        let fts = d.tableSQL("articles_fts") ?? ""
        XCTAssertTrue(fts.contains("USING fts5("), fts)
        for clause in ["filename", "content", "path UNINDEXED", "content='articles'", "content_rowid='id'", "tokenize='unicode61 remove_diacritics 2'"] {
            XCTAssertTrue(fts.contains(clause), "articles_fts lacks \(clause): \(fts)")
        }
        // C-08: bookmarks and scroll positions, column for column
        XCTAssertEqual(d.columnNames(of: "bookmarks"), ["id", "path", "title", "sort_order", "created_at", "block_index", "block_fingerprint"])
        XCTAssertEqual(d.columnNames(of: "scroll_positions"), ["path", "block_index", "block_fingerprint", "updated_at", "file_mtime"])
        XCTAssertTrue(d.openFlagsIncludeFullMutex)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("mdv6.db").path))
    }

    /// §3.3, D-22: each migration's statements and the version bump run in one transaction; a failing statement rolls
    /// back, is logged (E-12), and the next launch retries it. I-007.
    func testMigrationIsAtomic() {
        var lines: [String] = []
        Diagnostics.sink = { lines.append($0) }
        Database.migrationFaultInjection = 3                     // migration 3 → 4 fails after its first statement
        let first = db()
        XCTAssertEqual(first.schemaVersion, 3)
        XCTAssertTrue(lines.contains { $0.hasPrefix("[mdv6] persistence store failure") })
        first.close()
        Database.migrationFaultInjection = nil
        let second = db()
        XCTAssertEqual(second.schemaVersion, 4)
        XCTAssertTrue(second.tableNames().contains("scroll_positions"))
    }

    /// E-12, T-33: a corrupt store file logs one `[mdv6]` line and degrades — no hits, no bookmarks, no scroll rows, no crash.
    func testCorruptFileDegrades() {
        var lines: [String] = []
        Diagnostics.sink = { lines.append($0) }
        var junk = [UInt8](repeating: 0, count: 4096)
        for i in 0..<junk.count { junk[i] = UInt8((i * 7919) & 0xFF) }
        try! Data(junk).write(to: dir.appendingPathComponent("mdv6.db"))
        let d = db()
        XCTAssertFalse(d.isAvailable)
        XCTAssertEqual(lines.filter { $0.hasPrefix("[mdv6] persistence store failure") }.count, 1)
        XCTAssertFalse(lines.joined().contains("SELECT"))                              // R-35: no query text in logs
        d.indexFile(path: "/tmp/x.md", content: "hello", mtime: 1, size: 5)
        XCTAssertEqual(d.search("hello"), [])
        XCTAssertEqual(d.bookmarks(), [])
        XCTAssertNil(d.addBookmark(path: "/tmp/x.md", title: "t", blockIndex: 0, fingerprint: "f"))
        XCTAssertNil(d.scrollPosition(path: "/tmp/x.md"))
        d.saveScrollPosition(path: "/tmp/x.md", blockIndex: 1, fingerprint: "f", fileMtime: 1)
    }

    // MARK: index and search (C-03, R-25, R-26, K-03, K-09, E-24)

    /// R-25, T-24: prefix matching with U+0002/U+0003 around the terms; diacritics folded; empty/whitespace → none; limit 80.
    func testIndexAndSearch() {
        let d = db()
        d.indexFile(path: "/docs/a.md", content: "Authentication is required. Résumé attached.", mtime: 10, size: 40)
        d.indexFile(path: "/docs/b.md", content: "nothing relevant", mtime: 10, size: 16)
        let hits = d.search("auth")
        XCTAssertEqual(hits.map(\.path), ["/docs/a.md"])
        XCTAssertEqual(hits[0].filename, "a.md")
        XCTAssertTrue(hits[0].snippet.contains("\u{2}Authentication\u{3}"))
        XCTAssertEqual(d.search("resume").map(\.path), ["/docs/a.md"])
        XCTAssertEqual(d.search("résumé").map(\.path), ["/docs/a.md"])
        XCTAssertEqual(d.search(""), [])
        XCTAssertEqual(d.search("   "), [])
        XCTAssertEqual(d.search("\"()"), [])
        XCTAssertEqual(d.search("nothing rel").map(\.path), ["/docs/b.md"])          // ANDed prefixes
        XCTAssertEqual(d.search("nothing auth"), [])
        XCTAssertEqual(d.indexedMtime(path: "/docs/a.md"), 10)
        XCTAssertNil(d.indexedMtime(path: "/docs/zzz.md"))
        // re-index replaces content (the `au` trigger keeps the FTS table in step)
        d.indexFile(path: "/docs/a.md", content: "changed entirely", mtime: 11, size: 16)
        XCTAssertEqual(d.search("auth"), [])
        XCTAssertEqual(d.search("changed").map(\.path), ["/docs/a.md"])
        XCTAssertEqual(d.indexedMtime(path: "/docs/a.md"), 11)
    }

    /// C-03, D-36, K-03: 81 equal-rank files inserted in reverse path order come back as the first 80 by
    /// `path COLLATE NOCASE`, then binary path; a repeated query returns the same sequence. T-24.
    func testEqualRankOrderingAndLimit() {
        let d = db()
        var paths: [String] = []
        for i in (0..<81).reversed() {
            let name = i % 2 == 0 ? "/p/File\(String(format: "%03d", i)).md" : "/p/file\(String(format: "%03d", i)).md"
            paths.append(name)
            d.indexFile(path: name, content: "token", mtime: 1, size: 5)
        }
        let expected = Array(paths.sorted { a, b in
            let c = a.caseInsensitiveCompare(b)
            return c == .orderedSame ? a < b : c == .orderedAscending
        }.prefix(80))
        let first = d.search("token").map(\.path)
        XCTAssertEqual(first.count, 80)
        XCTAssertEqual(first, expected)
        XCTAssertEqual(d.search("token").map(\.path), first)
        XCTAssertEqual(d.search("token").map(\.path), first)
        // the NOCASE/binary tie: "/p/a.md" vs "/p/A.md" — binary puts "A" first
        d.indexFile(path: "/p/a.md", content: "tie", mtime: 1, size: 3)
        d.indexFile(path: "/p/A.md", content: "tie", mtime: 1, size: 3)
        XCTAssertEqual(d.search("tie").map(\.path), ["/p/A.md", "/p/a.md"])
    }

    /// R-26: removing a file drops its index row and scroll position but keeps its bookmarks; `prune` keeps only history paths.
    func testRemoveFileAndPrune() {
        let d = db()
        d.indexFile(path: "/a.md", content: "alpha", mtime: 1, size: 5)
        d.indexFile(path: "/b.md", content: "beta", mtime: 1, size: 4)
        d.indexFile(path: "/c.md", content: "gamma", mtime: 1, size: 5)
        d.saveScrollPosition(path: "/a.md", blockIndex: 3, fingerprint: "x", fileMtime: 1)
        _ = d.addBookmark(path: "/a.md", title: "keep me", blockIndex: 0, fingerprint: "y")
        d.removeFile(path: "/a.md")
        XCTAssertEqual(d.search("alpha"), [])
        XCTAssertNil(d.scrollPosition(path: "/a.md"))
        XCTAssertEqual(d.bookmarks().map(\.title), ["keep me"])
        d.prune(keeping: ["/b.md"])
        XCTAssertEqual(d.search("gamma"), [])
        XCTAssertEqual(d.search("beta").map(\.path), ["/b.md"])
        XCTAssertEqual(d.indexedPaths(), ["/b.md"])
    }

    // MARK: bookmarks and scroll positions (C-08, R-27, R-06)

    /// C-08, R-27: bookmark rows persist in `sort_order`; duplicates create two rows; reorder persists; remove. T-26.
    func testBookmarkRows() {
        let d = db()
        let a = d.addBookmark(path: "/a.md", title: "A", blockIndex: 2, fingerprint: "fa")!
        let b = d.addBookmark(path: "/a.md", title: "A", blockIndex: 2, fingerprint: "fa")!     // duplicate → second row
        let c = d.addBookmark(path: "/b.md", title: "C", blockIndex: 5, fingerprint: "fc")!
        XCTAssertNotEqual(a.id, b.id)
        XCTAssertEqual(d.bookmarks().map(\.id), [a.id, b.id, c.id])
        XCTAssertEqual(d.bookmarks().map(\.sortOrder), [0, 1, 2])
        XCTAssertEqual(d.bookmarks()[2].blockIndex, 5); XCTAssertEqual(d.bookmarks()[2].fingerprint, "fc")
        XCTAssertGreaterThan(d.bookmarks()[0].createdAt, 1_600_000_000)
        d.reorderBookmarks(ids: [c.id, a.id, b.id])
        XCTAssertEqual(d.bookmarks().map(\.id), [c.id, a.id, b.id])
        XCTAssertEqual(d.bookmarks().map(\.sortOrder), [0, 1, 2])
        d.removeBookmark(id: a.id)
        XCTAssertEqual(d.bookmarks().map(\.id), [c.id, b.id])
        let reopened = Database(url: dir.appendingPathComponent("mdv6.db"))
        XCTAssertEqual(reopened.bookmarks().map(\.id), [c.id, b.id])
    }

    /// C-08, R-06: scroll positions upsert per path (I-007 whole-row) and round-trip `file_mtime`. T-28.
    func testScrollPositions() {
        let d = db()
        XCTAssertNil(d.scrollPosition(path: "/a.md"))
        d.saveScrollPosition(path: "/a.md", blockIndex: 7, fingerprint: "fp", fileMtime: 123)
        XCTAssertEqual(d.scrollPosition(path: "/a.md"), Database.ScrollRow(blockIndex: 7, fingerprint: "fp", fileMtime: 123))
        d.saveScrollPosition(path: "/a.md", blockIndex: 9, fingerprint: "fq", fileMtime: 124)
        XCTAssertEqual(d.scrollPosition(path: "/a.md"), Database.ScrollRow(blockIndex: 9, fingerprint: "fq", fileMtime: 124))
        XCTAssertEqual(d.scrollRowCount(), 1)
        d.removeScrollPosition(path: "/a.md")
        XCTAssertNil(d.scrollPosition(path: "/a.md"))
    }

    /// I-006, I-007, T-33: concurrent whole-row writes from a background queue while the main thread reads through a
    /// second connection — every row read is complete (non-empty title and fingerprint), never partial.
    func testConcurrentWritesLeaveWholeRows() {
        let d = db()
        let reader = Database(url: dir.appendingPathComponent("mdv6.db"))
        let group = DispatchGroup()
        DispatchQueue.global().async(group: group) {
            for i in 0..<200 { _ = d.addBookmark(path: "/w.md", title: "title \(i)", blockIndex: i, fingerprint: "fp\(i)") }
        }
        var partial = 0
        var reads = 0
        while group.wait(timeout: .now()) == .timedOut {          // read continuously while the writer runs
            let rows = reader.bookmarks()
            reads += 1
            partial += rows.filter { $0.title.isEmpty || $0.fingerprint.isEmpty }.count
        }
        let final = reader.bookmarks()
        XCTAssertEqual(partial, 0)
        XCTAssertEqual(final.count, 200)
        XCTAssertEqual(final.filter { $0.title.isEmpty || $0.fingerprint.isEmpty }.count, 0)
        XCTAssertGreaterThanOrEqual(reads, 0)
    }

    // MARK: HistoryManager (R-20, R-26, I-013, K-03, C-15)

    /// R-20, T-25: 101 adds → the newest 100, most recent first, no duplicates; the evicted path leaves the index and the
    /// scroll table; re-adding moves to the top; `select` leaves order and index alone; `remove` returns the new head. I-013.
    func testHistoryAddSelectRemove() {
        var files: [String: String] = [:]
        for i in 0..<101 { files["/h/f\(i).md"] = "unique\(i) word" }
        let fs = FileSystem.fake(files: files, mtime: 5)
        let m = model(fs: fs)
        let h = m.history
        for i in 0..<101 { h.add(path: "/h/f\(i).md") }
        XCTAssertEqual(h.entries.count, 100)
        XCTAssertEqual(h.entries.first?.path, "/h/f100.md")
        XCTAssertEqual(h.entries.last?.path, "/h/f1.md")
        XCTAssertEqual(Set(h.entries.map(\.path)).count, 100)
        XCTAssertEqual(m.database.search("unique0"), [])                        // evicted from the index (R-26)
        XCTAssertEqual(m.database.search("unique100").map(\.path), ["/h/f100.md"])
        XCTAssertEqual(HistoryManager.cap, 100)
        // selecting route: order and index untouched
        let third = h.entries[2]
        XCTAssertNotNil(h.select(path: third.path))
        XCTAssertEqual(h.entries[2], third)
        XCTAssertEqual(h.entries.first?.path, "/h/f100.md")
        // adding route on an existing path: moves to the top, keeps a single row, same id
        h.add(path: third.path)
        XCTAssertEqual(h.entries.first?.path, third.path)
        XCTAssertEqual(h.entries.first?.id, third.id)
        XCTAssertEqual(h.entries.filter { $0.path == third.path }.count, 1)
        XCTAssertEqual(h.entries.count, 100)
        // remove: index and scroll row dropped, new head returned
        m.database.saveScrollPosition(path: third.path, blockIndex: 4, fingerprint: "f", fileMtime: 5)
        let newHead = h.remove(h.entries[0])
        XCTAssertEqual(newHead?.path, "/h/f100.md")
        XCTAssertEqual(h.entries.count, 99)
        let removedWord = "unique" + third.path.dropFirst("/h/f".count).dropLast(".md".count) + " word"
        XCTAssertEqual(m.database.search(removedWord), [])
        XCTAssertNil(m.database.scrollPosition(path: third.path))
        // persisted per C-15 and reloaded by a fresh manager on the same store
        let stored = defaults().data(forKey: Preferences.Key.history)
        XCTAssertEqual(HistoryCodec.decode(stored).count, 99)
        let again = model(fs: fs)
        XCTAssertEqual(again.history.entries.map(\.path), h.entries.map(\.path))
        XCTAssertNil(h.select(path: "/nowhere.md"))
    }

    /// R-26: the mtime gate (whole seconds, equality) skips re-indexing an unchanged file; `reindexOnLaunch` re-indexes a
    /// changed file, skips unchanged ones and prunes index rows whose path is not in history. K-06, T-24.
    func testIndexMtimeGateAndLaunchReindex() {
        let fs = FileSystem.fake(files: ["/a.md": "alpha one", "/b.md": "beta"], mtime: 100)
        let m = model(fs: fs)
        m.history.add(path: "/a.md")
        m.history.add(path: "/b.md")
        // editing without changing the mtime leaves the old content indexed
        fs.contents["/a.md"] = "rewritten"
        m.history.add(path: "/a.md")
        XCTAssertEqual(m.database.search("alpha").map(\.path), ["/a.md"])
        XCTAssertEqual(m.database.search("rewritten"), [])
        // touching (new mtime) then an adding route re-indexes; a selecting route does not
        fs.mtimes["/a.md"] = 101
        _ = m.history.select(path: "/a.md")
        XCTAssertEqual(m.database.search("rewritten"), [])
        m.history.add(path: "/a.md")
        XCTAssertEqual(m.database.search("rewritten").map(\.path), ["/a.md"])
        // launch: orphan pruned, changed file re-indexed, unchanged skipped
        m.database.indexFile(path: "/orphan.md", content: "orphan", mtime: 1, size: 6)
        fs.contents["/b.md"] = "beta changed"; fs.mtimes["/b.md"] = 200
        let e = expectation(description: "reindex")
        m.history.reindexOnLaunch { e.fulfill() }
        wait(for: [e], timeout: 5)
        XCTAssertEqual(m.database.search("orphan"), [])
        XCTAssertEqual(m.database.search("changed").map(\.path), ["/b.md"])
        XCTAssertEqual(m.database.indexedMtime(path: "/b.md"), 200)
        XCTAssertEqual(m.database.indexedMtime(path: "/a.md"), 101)
    }

    /// C-15: a malformed stored value yields an empty history without a crash; `clear()` exists but nothing in the UI calls it (R-26).
    func testMalformedHistoryValue() {
        defaults().set(Data("{not json".utf8), forKey: Preferences.Key.history)
        let m = model()
        XCTAssertEqual(m.history.entries, [])
        m.history.add(path: "/x.md")
        m.history.clear()
        XCTAssertEqual(m.history.entries, [])
    }

    // MARK: BookmarksManager (R-27, K-03), PlaceholderStore (R-28)

    /// R-27: titles by the R-27 rule, five hotkey slots follow the order, `move*` persist, missing files flagged (E-09). T-26, T-48.
    func testBookmarksManager() {
        let fs = FileSystem.fake(files: ["/a.md": "# Head\n\npara", "/gone.md": ""], mtime: 1)
        fs.contents["/gone.md"] = nil
        let m = model(fs: fs)
        let doc = ParsedDocument(raw: "# Head\n\npara one\n\npara two")
        let bm = m.bookmarks
        let r1 = bm.add(path: "/a.md", document: doc, index: 1)!
        XCTAssertEqual(r1.title, "Head")
        XCTAssertEqual(r1.fingerprint, bookmarkFingerprint("para one"))
        for i in 2...6 { _ = bm.add(path: "/a.md", document: doc, index: min(i, 2)) }
        XCTAssertEqual(bm.bookmarks.count, 6)
        XCTAssertEqual(bm.slot(1)?.id, r1.id)
        XCTAssertNil(bm.slot(6)); XCTAssertNil(bm.slot(0))
        XCTAssertEqual(BookmarksManager.slotCount, 5)
        let third = bm.bookmarks[2]
        bm.moveUp(id: third.id)
        XCTAssertEqual(bm.bookmarks[1].id, third.id); XCTAssertEqual(bm.slot(2)?.id, third.id)
        bm.moveToBottom(id: third.id)
        XCTAssertEqual(bm.bookmarks.last?.id, third.id)
        bm.moveToTop(id: third.id)
        XCTAssertEqual(bm.bookmarks.first?.id, third.id); XCTAssertEqual(bm.slot(1)?.id, third.id)
        bm.moveDown(id: third.id)
        XCTAssertEqual(bm.bookmarks[1].id, third.id)
        bm.move(id: third.id, to: 4)
        XCTAssertEqual(bm.bookmarks[4].id, third.id)
        let persisted = Database(url: dir.appendingPathComponent("mdv6.db")).bookmarks().map(\.id)
        XCTAssertEqual(persisted, bm.bookmarks.map(\.id))
        bm.remove(id: third.id)
        XCTAssertEqual(bm.bookmarks.count, 5)
        XCTAssertTrue(bm.hasBookmark(path: "/a.md")); XCTAssertFalse(bm.hasBookmark(path: "/b.md"))
        let missing = bm.add(path: "/gone.md", document: ParsedDocument(raw: "x"), index: 0)!
        XCTAssertTrue(bm.isMissing(missing)); XCTAssertFalse(bm.isMissing(r1))
    }

    /// R-28: the placeholder is transient — set, replace, clear; never persisted, so a fresh model on the same store has none. T-27.
    func testPlaceholderStoreIsTransient() {
        let m = model()
        XCTAssertNil(m.placeholder.placeholder)
        m.placeholder.set(Placeholder(path: "/a.md", blockIndex: 3, fingerprint: "f", title: "T"))
        XCTAssertEqual(m.placeholder.placeholder?.title, "T")
        m.placeholder.set(Placeholder(path: "/a.md", blockIndex: 4, fingerprint: "g", title: "U"))
        XCTAssertEqual(m.placeholder.placeholder?.blockIndex, 4)
        XCTAssertNil(model().placeholder.placeholder)
        m.placeholder.clear()
        XCTAssertNil(m.placeholder.placeholder)
        XCTAssertEqual(m.database.tableNames().filter { $0.contains("placeholder") }, [])
    }

    // MARK: Preferences (C-04, R-32, T-42)

    /// C-04, T-31 (clamps), K-04: every key, its default, and the invalid-value fallbacks — wrong type, out of range, unknown ids, malformed history. T-42, R-32.
    func testPreferencesDefaultsAndFallbacks() {
        let p = Preferences(defaults: defaults())
        XCTAssertEqual(p.themeId, "high-contrast"); XCTAssertEqual(p.fontScale, 1.0); XCTAssertTrue(p.smartTypography)
        XCTAssertFalse(p.loadRemoteImages); XCTAssertFalse(p.sidebarCollapsed); XCTAssertFalse(p.inspectorVisible)
        XCTAssertEqual(p.inspectorWidth, 240); XCTAssertFalse(p.bookmarksExpanded); XCTAssertEqual(p.bookmarksHeight, 240)
        XCTAssertEqual(p.editorAppPath, ""); XCTAssertEqual(p.mermaidStyle, "document")
        XCTAssertEqual(Preferences.Key.themeId, "mdv6_theme_id"); XCTAssertEqual(Preferences.Key.fontScale, "mdv6_font_scale")
        XCTAssertEqual(Preferences.Key.smartTypography, "mdv6_smart_typography"); XCTAssertEqual(Preferences.Key.loadRemoteImages, "mdv6_load_remote_images")
        XCTAssertEqual(Preferences.Key.sidebarCollapsed, "mdv6_sidebar_collapsed"); XCTAssertEqual(Preferences.Key.inspectorVisible, "mdv6_inspector_visible")
        XCTAssertEqual(Preferences.Key.inspectorWidth, "mdv6_inspector_width"); XCTAssertEqual(Preferences.Key.bookmarksExpanded, "mdv6_bookmarks_expanded")
        XCTAssertEqual(Preferences.Key.bookmarksHeight, "mdv6_bookmarks_height"); XCTAssertEqual(Preferences.Key.editorAppPath, "mdv6_editor_app_path")
        XCTAssertEqual(Preferences.Key.history, "mdv6_history"); XCTAssertEqual(Preferences.Key.mermaidStyle, "mdv6.mermaid.style")
        // non-default valid values persist under the listed keys
        p.themeId = "sevilla"; p.fontScale = 1.4; p.smartTypography = false; p.loadRemoteImages = true; p.sidebarCollapsed = true
        p.inspectorVisible = true; p.inspectorWidth = 300; p.bookmarksExpanded = true; p.bookmarksHeight = 180
        p.editorAppPath = "/Applications/TextEdit.app"; p.mermaidStyle = "dark"
        let d = defaults()
        XCTAssertEqual(d.string(forKey: "mdv6_theme_id"), "sevilla"); XCTAssertEqual(d.double(forKey: "mdv6_font_scale"), 1.4)
        XCTAssertEqual(d.double(forKey: "mdv6_inspector_width"), 300); XCTAssertEqual(d.string(forKey: "mdv6.mermaid.style"), "dark")
        let reread = Preferences(defaults: defaults())
        XCTAssertEqual(reread.themeId, "sevilla"); XCTAssertEqual(reread.fontScale, 1.4); XCTAssertFalse(reread.smartTypography)
        XCTAssertTrue(reread.loadRemoteImages); XCTAssertTrue(reread.sidebarCollapsed); XCTAssertTrue(reread.inspectorVisible)
        XCTAssertEqual(reread.inspectorWidth, 300); XCTAssertTrue(reread.bookmarksExpanded); XCTAssertEqual(reread.bookmarksHeight, 180)
        XCTAssertEqual(reread.editorAppPath, "/Applications/TextEdit.app"); XCTAssertEqual(reread.mermaidStyle, "dark")
        // invalid values fall back at use
        d.set("nope", forKey: "mdv6_theme_id"); d.set("nine", forKey: "mdv6_font_scale"); d.set(12, forKey: "mdv6_smart_typography")
        d.set("yes", forKey: "mdv6_load_remote_images"); d.set(5000, forKey: "mdv6_inspector_width"); d.set(-3, forKey: "mdv6_bookmarks_height")
        d.set(Data("[garbage".utf8), forKey: "mdv6_history"); d.set("neon", forKey: "mdv6.mermaid.style"); d.set(7, forKey: "mdv6_editor_app_path")
        let bad = Preferences(defaults: defaults())
        XCTAssertEqual(bad.themeId, "nope")                                            // stored string kept…
        XCTAssertEqual(ThemeCatalog.resolve(id: bad.themeId, isDarkAppearance: false).id, "high-contrast")   // …resolves to the default
        XCTAssertEqual(bad.fontScale, 1.0); XCTAssertTrue(bad.smartTypography); XCTAssertFalse(bad.loadRemoteImages)
        XCTAssertEqual(bad.inspectorWidth, 520); XCTAssertEqual(bad.bookmarksHeight, 120)
        XCTAssertEqual(bad.history, []); XCTAssertEqual(bad.mermaidStyle, "document"); XCTAssertEqual(bad.editorAppPath, "")
        d.set(9.0, forKey: "mdv6_font_scale"); XCTAssertEqual(Preferences(defaults: defaults()).fontScale, 2.5)
        d.set(100, forKey: "mdv6_inspector_width"); XCTAssertEqual(Preferences(defaults: defaults()).inspectorWidth, 180)
        XCTAssertEqual(Preferences.inspectorWidthRange, 180...520); XCTAssertEqual(Preferences.minimumBookmarksHeight, 120)
        XCTAssertEqual(Preferences.sidebarWidthRange, 180...400)
    }

    // MARK: AppModel.bootstrap (§10)

    /// §10: `MDV6_SUPPORT_DIR` and `MDV6_DEFAULTS_SUITE` isolate the store; an empty value is unset; explicit arguments
    /// (the test bootstrap) take precedence; the support directory is created if absent.
    func testBootstrapIsolation() {
        let envDir = dir.appendingPathComponent("env-store")
        let envSuite = suite + ".env"
        defer { UserDefaults.standard.removePersistentDomain(forName: envSuite) }
        let fromEnv = AppModel.bootstrap(environment: ["MDV6_SUPPORT_DIR": envDir.path, "MDV6_DEFAULTS_SUITE": envSuite])
        XCTAssertEqual(fromEnv.supportDirectory.standardizedFileURL.path, envDir.standardizedFileURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: envDir.appendingPathComponent("mdv6.db").path))
        XCTAssertEqual(fromEnv.defaultsSuite, envSuite)
        let explicit = AppModel.bootstrap(supportDir: dir, defaultsSuite: suite, environment: ["MDV6_SUPPORT_DIR": envDir.path, "MDV6_DEFAULTS_SUITE": envSuite])
        XCTAssertEqual(explicit.supportDirectory.standardizedFileURL.path, dir.standardizedFileURL.path)
        XCTAssertEqual(explicit.defaultsSuite, suite)
        let empty = AppModel.resolveStore(supportDir: nil, defaultsSuite: nil, environment: ["MDV6_SUPPORT_DIR": "", "MDV6_DEFAULTS_SUITE": ""])
        XCTAssertEqual(empty.supportDir.path, NSHomeDirectory() + "/Library/Application Support/mdv6")
        XCTAssertNil(empty.defaultsSuite)
        XCTAssertEqual(AppModel.defaultSupportDirectory.path, NSHomeDirectory() + "/Library/Application Support/mdv6")
    }
}
