import XCTest
import Combine
import AppKit
@testable import mdv6Core

/// The headless `DocumentSession` (§3.1 lifecycle; R-01..R-06, R-18, R-19, R-21..R-28, R-31, R-36, R-40, R-41) on a
/// fake file system and an isolated store: the model halves of T-04, T-22, T-23, T-25, T-26, T-27, T-28, T-38, T-39, T-40.
@MainActor
final class SessionTests: XCTestCase {
    var dir: URL!
    var suite: String!
    var fs: FileSystem!
    var model: AppModel!
    var beeps = 0
    var opened: [URL] = []
    var pasteboard: [String] = []
    var watchers: [FakeWatcher] = []
    var clock: TestClock!

    final class FakeWatcher: FileWatching {
        let path: String; let onChange: () -> Void; var cancelled = false
        init(path: String, onChange: @escaping () -> Void) { self.path = path; self.onChange = onChange }
        func cancel() { cancelled = true }
    }

    final class TestClock: SessionClock {
        var pending: [(id: Int, fire: TimeInterval, block: () -> Void)] = []
        var now: TimeInterval = 0
        var nextId = 0
        func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) -> SessionTimer {
            nextId += 1
            let id = nextId
            pending.append((id, now + delay, block))
            return SessionTimer { [weak self] in self?.pending.removeAll { $0.id == id } }
        }
        func advance(_ dt: TimeInterval) {
            now += dt
            let due = pending.filter { $0.fire <= now }.sorted { $0.fire < $1.fire }
            pending.removeAll { $0.fire <= now }
            for d in due { d.block() }
        }
    }

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-session-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        suite = "mdv6.session.\(UUID().uuidString)"
        fs = FileSystem.fake(files: [
            "/d/a.md": "# A\n\npara a1\n\npara a2\n\n## Second heading\n\npara a3 with the word",
            "/d/b.md": "# B\n\npara b with the and the",
            "/d/c.md": "# C\n\n### Example\n\nfirst\n\n### Example\n\nsecond\n\n### a - b\n\nx\n\n#### deep\n\ny\n\n### Ünicode\n\nz",
            "/d/notes.txt": "plain",
            "/e/README.md": "# Readme",
            "/e/B.md": "# big b",
            "/e/a.md": "# small a",
            "/e/.hidden.md": "# hidden",
            "/e/x.txt": "no",
            "/f/B.md": "# fb",
            "/f/a.md": "# fa",
        ], mtime: 100)
        fs.directories = ["/d", "/e", "/f", "/empty"]
        model = AppModel.bootstrap(supportDir: dir, defaultsSuite: suite, fileSystem: fs)
        beeps = 0; opened = []; pasteboard = []; watchers = []
        clock = TestClock()
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: dir)
    }

    private func session() -> DocumentSession {
        let s = DocumentSession(model: model, clock: clock,
                                watcherFactory: { path, onChange in let w = FakeWatcher(path: path.path, onChange: onChange); self.watchers.append(w); return w },
                                pasteboard: { self.pasteboard.append($0) }, systemOpener: { self.opened.append($0) }, beeper: { self.beeps += 1 })
        return s
    }

    private func u(_ p: String) -> URL { URL(fileURLWithPath: p) }

    // MARK: §3.1, R-01, R-04, E-03

    /// §3.1: `EMPTY` → `LOADING` → `VIEWING` on an adding route; the row is added, the file indexed, the watcher armed;
    /// an empty file is a success (empty article, row selected); R-04.
    func testEmptyToViewingOnOpen() {
        let s = session()
        XCTAssertEqual(s.state, .empty); XCTAssertEqual(s.windowTitle, "mdv6")
        XCTAssertTrue(s.open(u("/d/a.md"), route: .adding))
        XCTAssertEqual(s.state, .viewing); XCTAssertEqual(s.document?.blocks.count, 5); XCTAssertEqual(s.windowTitle, "a.md")
        XCTAssertEqual(model.history.entries.map(\.path), ["/d/a.md"])
        XCTAssertEqual(model.database.search("a3").map(\.path), ["/d/a.md"])
        XCTAssertEqual(watchers.map(\.path), ["/d/a.md"])
        fs.contents["/d/empty.md"] = "   \n\n"
        XCTAssertTrue(s.open(u("/d/empty.md"), route: .adding))
        XCTAssertEqual(s.state, .viewing); XCTAssertEqual(s.document?.blocks, []); XCTAssertEqual(s.currentEntry?.path, "/d/empty.md")
        XCTAssertTrue(watchers[0].cancelled); XCTAssertEqual(watchers.last?.path, "/d/empty.md")
    }

    /// E-03, R-04, T-04, T-39: an unreadable file (missing, not UTF-8 via the fake's failure, over the K-14 ceiling) aborts
    /// the load — the previous document, selection, history and watcher are unchanged; with no prior document the window
    /// stays `EMPTY`. R-41, E-28 (document).
    func testUnreadableKeepsPreviousDocument() {
        let s = session()
        XCTAssertFalse(s.open(u("/d/missing.md"), route: .adding))
        XCTAssertEqual(s.state, .empty); XCTAssertEqual(model.history.entries, [])
        XCTAssertTrue(s.open(u("/d/a.md"), route: .adding))
        let before = (s.document, model.history.entries, watchers.count)
        XCTAssertFalse(s.open(u("/d/missing.md"), route: .adding))
        fs.contents["/d/huge.md"] = String(repeating: "x", count: ContentLimits.documentBytes + 1)
        XCTAssertFalse(s.open(u("/d/huge.md"), route: .adding))
        XCTAssertEqual(s.document, before.0); XCTAssertEqual(model.history.entries.map(\.path), ["/d/a.md"])
        XCTAssertEqual(watchers.count, before.2 + 0)
        XCTAssertEqual(s.currentEntry?.path, "/d/a.md"); XCTAssertEqual(s.state, .viewing)
        XCTAssertNotNil(model.history.entries.first { $0.path == "/d/a.md" })
    }

    /// R-01: several URLs are added in order and the last is displayed; T-03 (`mdv6 a.md b.md`).
    func testMultipleURLsLastDisplayed() {
        let s = session()
        s.open(urls: [u("/d/a.md"), u("/d/b.md")])
        XCTAssertEqual(s.currentEntry?.path, "/d/b.md")
        XCTAssertEqual(model.history.entries.map(\.path), ["/d/b.md", "/d/a.md"])
        XCTAssertEqual(model.database.search("a3").map(\.path), ["/d/a.md"])
    }

    // MARK: R-02, R-03, E-04 (T-04)

    /// R-02: a directory loads `README.md` (case-insensitive stem) else the first file by localized case-insensitive order;
    /// hidden files and other extensions are skipped; the other files become history rows (primary first, then in order).
    func testDirectoryLoads() {
        let s = session()
        XCTAssertTrue(s.loadDirectory(u("/e")))
        XCTAssertEqual(s.currentEntry?.path, "/e/README.md")
        XCTAssertEqual(model.history.entries.map(\.path), ["/e/README.md", "/e/a.md", "/e/B.md"])
        XCTAssertEqual(model.database.search("small").map(\.path), ["/e/a.md"])
        XCTAssertTrue(s.loadDirectory(u("/f")))
        XCTAssertEqual(s.currentEntry?.path, "/f/a.md")                                   // no README: first by case-insensitive order
        XCTAssertFalse(s.loadDirectory(u("/empty")))                                       // E-04
        XCTAssertEqual(s.currentEntry?.path, "/f/a.md")
        XCTAssertTrue(s.open(u("/e"), route: .adding))                                    // an opened directory path takes the directory route
        XCTAssertEqual(s.currentEntry?.path, "/e/README.md")
    }

    /// R-03: only the first dropped item counts; accepted extensions md/markdown/txt/mdown/mkd; other drops are ignored.
    func testDropRules() {
        let s = session()
        fs.contents["/d/z.mkd"] = "# mkd"; fs.contents["/d/p.pdf"] = "pdf"
        XCTAssertTrue(s.handleDrop([u("/d/z.mkd"), u("/d/a.md")]))
        XCTAssertEqual(s.currentEntry?.path, "/d/z.mkd"); XCTAssertEqual(model.history.entries.count, 1)
        XCTAssertFalse(s.handleDrop([u("/d/p.pdf")]))
        XCTAssertTrue(s.handleDrop([u("/d/notes.txt")]))
        XCTAssertFalse(s.handleDrop([]))
    }

    // MARK: adding vs selecting (R-01, R-20, R-26, I-013), delete-row transitions (§3.1)

    /// R-01, T-25: a sidebar row / a hit already in history / ⌘← keep the order and do not re-index; ⌘O of an existing
    /// path moves it to the top.
    func testAddingVersusSelectingRoutes() {
        let s = session()
        s.open(urls: [u("/d/a.md"), u("/d/b.md"), u("/d/c.md")])
        XCTAssertEqual(model.history.entries.map(\.path), ["/d/c.md", "/d/b.md", "/d/a.md"])
        fs.contents["/d/a.md"] = "# A changed\n\nnewword"; fs.mtimes["/d/a.md"] = 101
        s.selectHistoryRow(model.history.entries[2])
        XCTAssertEqual(s.currentEntry?.path, "/d/a.md")
        XCTAssertEqual(model.history.entries.map(\.path), ["/d/c.md", "/d/b.md", "/d/a.md"])
        XCTAssertEqual(model.database.search("newword"), [])                                  // not re-indexed
        s.openHit(path: "/d/b.md")
        XCTAssertEqual(model.history.entries.map(\.path), ["/d/c.md", "/d/b.md", "/d/a.md"])
        XCTAssertTrue(s.open(u("/d/a.md"), route: .adding))
        XCTAssertEqual(model.history.entries.map(\.path), ["/d/a.md", "/d/c.md", "/d/b.md"])
        XCTAssertEqual(model.database.search("newword").map(\.path), ["/d/a.md"])
        fs.contents["/d/new.md"] = "# new"
        s.openHit(path: "/d/new.md")                                                          // not in history → adding
        XCTAssertEqual(model.history.entries.first?.path, "/d/new.md")
    }

    /// §3.1, R-20, R-18, T-25, T-47, C-18.1: deleting the displayed row loads the new head as a selecting route with no snapshot of the
    /// deleted entry; deleting the last row enters `EMPTY` and the title reverts to the product name (T-47).
    func testDeleteRowTransitions() {
        let s = session()
        s.open(urls: [u("/d/a.md")])
        XCTAssertTrue(s.open(u("/d/b.md"), route: .adding))
        XCTAssertTrue(s.canGoBack)
        s.deleteHistoryRow(model.history.entries[0])                                          // b (displayed)
        XCTAssertEqual(s.currentEntry?.path, "/d/a.md"); XCTAssertEqual(s.state, .viewing)
        s.goBack(); s.goForward()
        XCTAssertEqual(s.currentEntry?.path, "/d/a.md", "no snapshot leads back to the deleted row")
        XCTAssertEqual(beeps, 0)
        s.deleteHistoryRow(model.history.entries[0])
        XCTAssertEqual(s.state, .empty); XCTAssertNil(s.document); XCTAssertEqual(s.windowTitle, "mdv6")
        XCTAssertTrue(watchers.allSatisfy(\.cancelled))
    }

    // MARK: R-18 stacks (T-22, T-27, T-28)

    /// T-22, R-18: loads push and clear forward; bookmark, placeholder and cold-start routes push nothing; same-document
    /// fragment/TOC jumps push; find never pushes; re-opening the current path pushes nothing; E-27 missing files beep.
    func testBackForward() {
        let s = session()
        s.open(urls: [u("/d/a.md")])
        XCTAssertFalse(s.canGoBack)
        XCTAssertTrue(s.open(u("/d/b.md"), route: .adding))
        XCTAssertTrue(s.canGoBack); XCTAssertFalse(s.canGoForward)
        s.goBack()
        XCTAssertEqual(s.currentEntry?.path, "/d/a.md"); XCTAssertTrue(s.canGoForward)
        XCTAssertEqual(model.history.entries.map(\.path), ["/d/b.md", "/d/a.md"], "⌘← is a selecting route")
        s.goForward()
        XCTAssertEqual(s.currentEntry?.path, "/d/b.md"); XCTAssertFalse(s.canGoForward)
        XCTAssertTrue(s.open(u("/d/b.md"), route: .adding))                                   // re-opening the current path
        XCTAssertEqual(s.backCount, 1)
        // same-document jumps push; find does not
        s.selectTOC(blockIndex: 0)
        XCTAssertEqual(s.backCount, 2)
        s.openFind(); s.setFindQuery("the"); s.findNext(); s.closeFind()
        XCTAssertEqual(s.backCount, 2)
        // a bookmark in another file loads it but ⌘← does not return to the pre-bookmark file
        let row = model.bookmarks.add(path: "/d/a.md", document: ParsedDocument(raw: fs.contents["/d/a.md"]!), index: 2)!
        s.openBookmark(row)
        XCTAssertEqual(s.currentEntry?.path, "/d/a.md"); XCTAssertEqual(s.backCount, 2)
        XCTAssertEqual(s.scrollTarget?.block, 2)
        // missing file on ⌘←: beep, snapshot discarded, view unchanged
        fs.contents["/d/b.md"] = nil
        s.goBack()
        XCTAssertEqual(beeps, 1); XCTAssertEqual(s.currentEntry?.path, "/d/a.md"); XCTAssertEqual(s.backCount, 1)
    }

    // MARK: R-19 links (T-22)

    /// T-22, R-19, C-11, E-05, E-06, E-22: resolve-then-classify; fragments decoded once; first slug wins; h4/setext unmatched;
    /// cross-file fragment suppresses restoration and lands on the slug or stays at the top; everything else → opener.
    func testHandleLink() {
        let s = session()
        XCTAssertTrue(s.open(u("/d/c.md"), route: .adding))
        s.handleLink(URL(string: "#example")!)
        XCTAssertEqual(s.scrollTarget?.block, 1); XCTAssertEqual(s.tocSelectedBlock, 1); XCTAssertEqual(s.backCount, 1)
        s.handleLink(URL(string: "#example-1")!)
        XCTAssertEqual(s.scrollTarget?.block, 1); XCTAssertEqual(s.backCount, 1)                  // no-op
        s.handleLink(URL(string: "#a---b")!)
        XCTAssertEqual(s.scrollTarget?.block, 5)
        s.handleLink(URL(string: "#%C3%9Cnicode")!)                                                // Ünicode, decoded once
        XCTAssertEqual(s.scrollTarget?.block, 9)
        s.handleLink(URL(string: "#deep")!)                                                         // h4 is never a target
        XCTAssertEqual(s.scrollTarget?.block, 9)
        s.handleLink(URL(string: "#%E0%A4%A")!)                                                     // invalid percent encoding: no match
        XCTAssertEqual(s.scrollTarget?.block, 9)
        XCTAssertEqual(opened, [])
        // relative sibling and the resolved file: form (F-117)
        s.handleLink(URL(string: "a.md")!)
        XCTAssertEqual(s.currentEntry?.path, "/d/a.md"); XCTAssertEqual(model.history.entries.first?.path, "/d/a.md")
        s.handleLink(URL(fileURLWithPath: "/d/c.md"))
        XCTAssertEqual(s.currentEntry?.path, "/d/c.md")
        // cross-file fragment: loads at the slug, saved position suppressed; missing fragment loads at the top
        model.database.saveScrollPosition(path: "/d/a.md", blockIndex: 3, fingerprint: bookmarkFingerprint("para a3 with the word"), fileMtime: 100)
        s.handleLink(URL(string: "a.md#second-heading")!)
        XCTAssertEqual(s.currentEntry?.path, "/d/a.md"); XCTAssertEqual(s.scrollTarget?.block, 3); XCTAssertEqual(s.tocSelectedBlock, 3)
        s.handleLink(URL(string: "c.md#nope")!)
        XCTAssertEqual(s.currentEntry?.path, "/d/c.md"); XCTAssertEqual(s.scrollTarget?.block, 0)
        // E-05: a local Markdown path that does not exist is handed to the system opener and nothing navigates
        let historyBefore = model.history.entries.map(\.path), backBefore = s.backCount
        s.handleLink(URL(string: "does-not-exist.md")!)
        XCTAssertEqual(opened.last?.path, "/d/does-not-exist.md", "E-05: handed to the opener, resolved against the document")
        XCTAssertEqual(s.currentEntry?.path, "/d/c.md", "E-05: no navigation")
        XCTAssertEqual(model.history.entries.map(\.path), historyBefore, "E-05: no history row")
        XCTAssertEqual(s.backCount, backBefore, "E-05: no back-snapshot")
        // system opener: https, other extension, file: to txt, custom scheme
        for l in ["https://example.com", "notes.txt", "file:///d/notes.txt", "x-custom://thing"] { s.handleLink(URL(string: l)!) }
        XCTAssertEqual(opened.count, 5)
        XCTAssertEqual(s.currentEntry?.path, "/d/c.md")
    }

    // MARK: E-29 TOC selection

    /// R-21, E-29, D-41: the selected row is choice-driven — scrolling keeps it, a reload keeps it while the heading survives at
    /// that index, another document clears it, a cross-file fragment selects.
    func testTOCSelectionLifecycle() {
        let s = session()
        s.open(urls: [u("/d/a.md")])
        s.selectTOC(blockIndex: 3)
        XCTAssertEqual(s.tocSelectedBlock, 3)
        s.topVisibleBlock = 0
        XCTAssertEqual(s.tocSelectedBlock, 3)
        fs.contents["/d/a.md"] = "# A\n\npara a1\n\npara a2\n\n## Second heading\n\nchanged"
        watchers.last!.onChange()
        XCTAssertEqual(s.tocSelectedBlock, 3)
        fs.contents["/d/a.md"] = "# A\n\n## Second heading\n\nmoved"
        watchers.last!.onChange()
        XCTAssertNil(s.tocSelectedBlock)
        s.selectTOC(blockIndex: 1)
        XCTAssertTrue(s.open(u("/d/b.md"), route: .adding))
        XCTAssertNil(s.tocSelectedBlock)
    }

    // MARK: R-22 copy section

    /// R-22, C-12, K-06, T-30: a single click on a heading (the tap handler; ⇧-click takes the same handler since modifiers are
    /// not distinguished) puts the section's Markdown source — from the heading to just before the next heading of the same
    /// or a higher level — on the pasteboard and flashes the section for 0.6 s; a second click flashes it again; a `####`
    /// heading is not a TOC heading, so it is never offered the click-to-copy handler and nothing is copied.
    func testCopySectionFlash() {
        fs.contents["/d/deep.md"] = "# A\n\npara a1\n\n## Second heading\n\npara a3 with the word\n\n#### deep\n\npara d\n\n## Third\n\nend"
        let s = session()
        s.open(urls: [u("/d/deep.md")])
        s.copySection(at: 2)
        XCTAssertEqual(pasteboard, ["## Second heading\n\npara a3 with the word\n\n#### deep\n\npara d"], "ends at the next same-or-higher heading; h4 does not end it")
        XCTAssertEqual(s.flashedRange, 2..<6)
        clock.advance(0.5); XCTAssertEqual(s.flashedRange, 2..<6)
        clock.advance(0.2); XCTAssertNil(s.flashedRange)
        s.copySection(at: 2)
        XCTAssertEqual(s.flashedRange, 2..<6, "clicking again flashes again")
        XCTAssertEqual(pasteboard.count, 2, "and copies again")
        clock.advance(0.3); s.copySection(at: 2); clock.advance(0.4)
        XCTAssertEqual(s.flashedRange, 2..<6, "the flash restarts from the latest click")
        s.copySection(at: 0)
        XCTAssertEqual(pasteboard.last, fs.contents["/d/deep.md"]!)
        XCTAssertEqual(s.flashedRange, 0..<8)
        XCTAssertEqual(DocumentSession.flashDuration, 0.6)
        // the `####` heading is block 4: not a TOC heading, so ArticleBlockView gives it plain selectable text, no copy handler
        XCTAssertEqual(s.document!.blocks[4], "#### deep")
        XCTAssertFalse(s.document!.tocHeadings.contains { $0.blockIndex == 4 })
        XCTAssertEqual(BlockKind(block: s.document!.blocks[4]), .heading(4), "a heading for layout, not for copying")
    }

    // MARK: R-24 find (T-23, T-39)

    /// R-24, D-39, E-18: empty → no matches and stepping disabled; whitespace verbatim; occurrences step and wrap within a
    /// block; a reload recounts and returns to the first; ⌘F routes to global search when the sidebar has focus.
    func testFindModel() {
        let s = session()
        s.open(urls: [u("/d/b.md")])                                                            // "para b with the and the"
        s.openFind()
        XCTAssertEqual(s.findState?.label, "No matches"); XCTAssertFalse(s.findState!.canStep)
        s.setFindQuery(" ")
        XCTAssertEqual(s.findState?.matches.count, 6)                                          // "# B" has one too
        s.setFindQuery("the")
        XCTAssertEqual(s.findState?.matches.count, 2); XCTAssertEqual(s.findState?.label, "1 of 2")
        s.findNext(); XCTAssertEqual(s.findState?.label, "2 of 2")
        s.findNext(); XCTAssertEqual(s.findState?.label, "1 of 2")                                // wraps
        s.findPrevious(); XCTAssertEqual(s.findState?.label, "2 of 2")
        XCTAssertEqual(s.scrollTarget?.block, 1)
        fs.contents["/d/b.md"] = "# B\n\npara b with the and the and the"
        watchers.last!.onChange()
        XCTAssertEqual(s.findState?.matches.count, 3); XCTAssertEqual(s.findState?.label, "1 of 3")
        s.closeFind(); XCTAssertNil(s.findState)
        XCTAssertEqual(s.findCommandTarget(sidebarHasFocus: true), .globalSearch)
        XCTAssertEqual(s.findCommandTarget(sidebarHasFocus: false), .findBar)
    }

    // MARK: R-27 / R-28 (T-26, T-27)

    /// R-27: ⌘D anchors at the hovered block, else the topmost visible; titles by the R-27 rule; slots; E-09 beeps. The new row
    /// is revealed — inspector shown, pane expanded — and marked current (F-008).
    func testBookmarkCurrentSpot() {
        let s = session()
        s.open(urls: [u("/d/a.md")])
        s.topVisibleBlock = 1
        s.hoveredBlockIndex = 4
        model.preferences.inspectorVisible = false; model.preferences.bookmarksExpanded = false
        s.setPlaceholder(); XCTAssertTrue(s.placeholderIsCurrent)
        s.bookmarkCurrentSpot()
        XCTAssertEqual(model.bookmarks.bookmarks.last?.blockIndex, 4); XCTAssertEqual(model.bookmarks.bookmarks.last?.title, "Second heading")
        XCTAssertTrue(model.preferences.inspectorVisible); XCTAssertTrue(model.preferences.bookmarksExpanded)
        XCTAssertEqual(s.currentBookmarkID, model.bookmarks.bookmarks.last?.id); XCTAssertFalse(s.placeholderIsCurrent)
        s.hoveredBlockIndex = nil
        s.bookmarkCurrentSpot()
        XCTAssertEqual(model.bookmarks.bookmarks.last?.blockIndex, 1); XCTAssertEqual(model.bookmarks.bookmarks.last?.title, "A")
        XCTAssertEqual(model.bookmarks.bookmarks.count, 2)
        s.openSlot(1); XCTAssertEqual(s.scrollTarget?.block, 4); XCTAssertEqual(s.currentBookmarkID, model.bookmarks.slot(1)?.id)
        s.openSlot(3); XCTAssertEqual(beeps, 0)                                                   // empty slot: nothing
        fs.contents["/d/a.md"] = nil
        s.openSlot(2); XCTAssertEqual(beeps, 1)                                                   // E-09
        XCTAssertTrue(s.hasBookmarkForCurrentFile)
    }

    /// R-28, E-27, T-27: ⌘⇧0 sets the placeholder (title, current, pane expanded); ⌘0 returns, loads the other file as an
    /// adding route without a snapshot; beeps when unset or the file is gone; *Clear Placeholder* removes it.
    func testPlaceholder() {
        let s = session()
        s.jumpToPlaceholder(); XCTAssertEqual(beeps, 1)
        s.open(urls: [u("/d/a.md")])
        model.preferences.bookmarksExpanded = false
        s.topVisibleBlock = 4
        s.setPlaceholder()
        XCTAssertEqual(model.placeholder.placeholder?.blockIndex, 4); XCTAssertEqual(model.placeholder.placeholder?.title, "Second heading")
        XCTAssertTrue(model.preferences.bookmarksExpanded); XCTAssertTrue(s.placeholderIsCurrent)
        s.topVisibleBlock = 0
        s.jumpToPlaceholder(); XCTAssertEqual(s.scrollTarget?.block, 4)
        s.topVisibleBlock = 1
        s.setPlaceholder(); XCTAssertEqual(model.placeholder.placeholder?.blockIndex, 1)          // replaced, never a second one
        XCTAssertTrue(s.open(u("/d/b.md"), route: .adding))
        XCTAssertFalse(s.placeholderIsCurrent)
        let backBefore = s.backCount
        s.jumpToPlaceholder()
        XCTAssertEqual(s.currentEntry?.path, "/d/a.md"); XCTAssertEqual(s.backCount, backBefore); XCTAssertTrue(s.placeholderIsCurrent)
        XCTAssertEqual(model.history.entries.first?.path, "/d/a.md")                              // adding route
        fs.contents["/d/a.md"] = nil
        s.open(urls: [u("/d/b.md")])
        s.jumpToPlaceholder(); XCTAssertEqual(beeps, 2); XCTAssertEqual(s.currentEntry?.path, "/d/b.md"); XCTAssertNotNil(model.placeholder.placeholder)
        s.clearPlaceholder(); XCTAssertNil(model.placeholder.placeholder)
        s.jumpToPlaceholder(); XCTAssertEqual(beeps, 3)
    }

    // MARK: R-06 scroll (T-28)

    /// T-28, R-06, C-08, E-08: the position is persisted on switch/close and restored when the mtime is within 1 s and the anchor
    /// resolves; a changed mtime starts at the top; the fingerprint follows moved content.
    func testScrollPersistAndRestore() {
        let s = session()
        s.open(urls: [u("/d/a.md")])
        s.topVisibleBlock = 3
        XCTAssertTrue(s.open(u("/d/b.md"), route: .adding))
        XCTAssertEqual(model.database.scrollPosition(path: "/d/a.md")?.blockIndex, 3)
        s.selectHistoryRow(model.history.entries[1])
        XCTAssertEqual(s.scrollTarget?.block, 3)
        fs.contents["/d/a.md"] = "# A\n\ninserted\n\npara a1\n\npara a2\n\n## Second heading\n\npara a3 with the word"
        XCTAssertTrue(s.open(u("/d/b.md"), route: .adding)); s.selectHistoryRow(model.history.entries[1])
        XCTAssertEqual(s.scrollTarget?.block, 4, "fingerprint resolution lands on the moved block")
        XCTAssertTrue(s.open(u("/d/b.md"), route: .adding))
        fs.mtimes["/d/a.md"] = 200                                                              // modified after the position was stored
        s.selectHistoryRow(model.history.entries[1])
        XCTAssertEqual(s.scrollTarget?.block, 0, "mtime differs by more than 1 s: top")
        s.topVisibleBlock = 2
        s.windowWillClose()
        XCTAssertEqual(model.database.scrollPosition(path: "/d/a.md")?.blockIndex, 2); XCTAssertEqual(s.state, .closed)
    }

    // MARK: R-05 reload (T-29, E-21)

    /// R-05, E-19, E-21, D-18: a change swaps the content in place (position kept, find recounted); a failed or undecodable
    /// read is ignored with the watch kept; a zero-byte read is re-read after 500 ms and that read is shown.
    func testReloadRules() {
        let s = session()
        s.open(urls: [u("/d/a.md")])
        s.topVisibleBlock = 2
        fs.contents["/d/a.md"] = "# A\n\nchanged\n\nmore\n\nend"
        watchers.last!.onChange()
        XCTAssertEqual(s.document?.blocks[1], "changed"); XCTAssertEqual(s.topVisibleBlock, 2); XCTAssertEqual(s.state, .viewing)
        XCTAssertEqual(watchers.count, 1, "the watch stays armed")
        fs.contents["/d/a.md"] = nil                                                              // deleted
        watchers.last!.onChange()
        XCTAssertEqual(s.document?.blocks[1], "changed"); XCTAssertFalse(watchers.last!.cancelled)
        fs.contents["/d/a.md"] = ""                                                                // truncate-then-write in progress
        watchers.last!.onChange()
        XCTAssertEqual(s.document?.blocks[1], "changed", "no blank frame")
        fs.contents["/d/a.md"] = "# A\n\nwritten back"
        clock.advance(0.5)
        XCTAssertEqual(s.document?.blocks[1], "written back")
        fs.contents["/d/a.md"] = ""
        watchers.last!.onChange(); clock.advance(0.5)
        XCTAssertEqual(s.document?.blocks, [], "really emptied: empty after 500 ms")
        XCTAssertEqual(DocumentSession.emptyReadRetry, 0.5)
        fs.contents["/d/a.md"] = "# A\n\nclamp me"
        s.topVisibleBlock = 9
        watchers.last!.onChange()
        XCTAssertEqual(s.topVisibleBlock, 1, "position clamped to the new block count")
    }

    /// R-05, K-06, T-29 (real watcher): five writes within 50 ms yield at most two reloads; an atomic rename reloads.
    func testRealFileWatcherCoalesces() throws {
        let file = dir.appendingPathComponent("watched.md")
        try "one".write(to: file, atomically: true, encoding: .utf8)
        var events = 0
        let e = expectation(description: "burst")
        e.assertForOverFulfill = false
        let w = FileWatcher(path: file, onChange: { events += 1; e.fulfill() })
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))                    // let the setup write's event (if FSEvents replays it) land
        events = 0
        let burstStart = Date()
        for i in 0..<5 { try "write \(i)".write(to: file, atomically: false, encoding: .utf8); usleep(1_000) }
        let burst = Date().timeIntervalSince(burstStart)
        wait(for: [e], timeout: 5)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
        // one immediate delivery plus one batch per 50 ms latency window the burst spanned (a loaded host stretches the burst)
        let allowed = 1 + Int((burst / FileWatcher.latency).rounded(.up))
        XCTAssertGreaterThanOrEqual(events, 1); XCTAssertLessThanOrEqual(events, max(2, allowed), "burst took \(burst) s")
        events = 0
        let tmp = dir.appendingPathComponent("tmp.md")
        try "renamed".write(to: tmp, atomically: false, encoding: .utf8)
        _ = try FileManager.default.replaceItemAt(file, withItemAt: tmp)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.8))
        XCTAssertGreaterThanOrEqual(events, 1)
        w.cancel()
        XCTAssertEqual(FileWatcher.latency, 0.05)
    }

    /// E-25: every document change (a load, a reload) bumps `renderGeneration`, the key the article's in-flight diagram and
    /// math tasks are bound to, so a stale render is never shown for the new document.
    func testRenderGenerationBumpsOnEveryDocumentChange() {
        let s = session()
        let g0 = s.renderGeneration
        s.open(urls: [u("/d/a.md")])
        XCTAssertEqual(s.renderGeneration, g0 + 1)
        XCTAssertTrue(s.open(u("/d/b.md"), route: .adding))
        XCTAssertEqual(s.renderGeneration, g0 + 2)
        fs.contents["/d/b.md"] = "# B\n\nchanged"
        watchers.last!.onChange()
        XCTAssertEqual(s.renderGeneration, g0 + 3)
        XCTAssertFalse(s.open(u("/d/missing.md"), route: .adding))
        XCTAssertEqual(s.renderGeneration, g0 + 3, "an aborted load changes nothing")
    }

    /// R-29, R-30, R-17: a theme, zoom or typography change republishes through the session, because the article's blocks
    /// observe the session (`ArticleHost`) and derive `theme`/`zoom` from the preferences (F-005: without this a block only
    /// re-rendered on hover, so switching themes recoloured the text one block at a time as the pointer crossed it).
    func testPreferenceChangesRepublishThroughSession() {
        let s = session()
        var published = 0
        let c = s.objectWillChange.sink { published += 1 }
        defer { c.cancel() }
        model.preferences.themeId = "twilight"
        XCTAssertEqual(published, 1)
        XCTAssertEqual(s.theme.id, "twilight")
        model.preferences.fontScale = 1.2
        model.preferences.smartTypography = false
        XCTAssertEqual(published, 3)
    }

    /// E-20, T-35: the same path open in two windows — each window's watcher reloads independently.
    func testTwoWindowsSamePathReloadIndependently() {
        let a = session(), b = session()
        a.open(urls: [u("/d/a.md")]); b.open(urls: [u("/d/a.md")])
        XCTAssertEqual(watchers.filter { !$0.cancelled }.map(\.path), ["/d/a.md", "/d/a.md"])
        fs.contents["/d/a.md"] = "# A\n\nedited on disk"
        for w in watchers where !w.cancelled { w.onChange() }
        XCTAssertEqual(a.document?.blocks[1], "edited on disk"); XCTAssertEqual(b.document?.blocks[1], "edited on disk")
        a.topVisibleBlock = 1; b.topVisibleBlock = 0
        a.persistScrollPosition(); b.persistScrollPosition()
        XCTAssertEqual(model.database.scrollPosition(path: "/d/a.md")?.blockIndex, 0, "per path, last writer wins")
    }

    // MARK: R-40 startup (T-28), E-26 routing (T-40), R-31, R-23 (T-38)

    /// T-28, R-40, D-28, D-29: launch restores exactly the history head (with position); an unreadable head stays and enters
    /// `EMPTY` without trying later rows; empty history → `EMPTY`; a cold-start argument pre-empts with no snapshot.
    func testStartup() {
        var s = session()
        s.open(urls: [u("/d/a.md"), u("/d/b.md")])
        s.topVisibleBlock = 1; s.windowWillClose()
        let s2 = model.startup(arguments: [], session: session())
        XCTAssertEqual(s2.currentEntry?.path, "/d/b.md"); XCTAssertEqual(s2.scrollTarget?.block, 1); XCTAssertFalse(s2.canGoBack)
        fs.contents["/d/b.md"] = nil
        s = model.startup(arguments: [], session: session())
        XCTAssertEqual(s.state, .empty); XCTAssertEqual(model.history.entries.map(\.path), ["/d/b.md", "/d/a.md"])
        fs.contents["/d/b.md"] = "# B"
        s = model.startup(arguments: [u("/d/c.md")], session: session())
        XCTAssertEqual(s.currentEntry?.path, "/d/c.md"); XCTAssertFalse(s.canGoBack)
        model.history.clear()
        s = model.startup(arguments: [], session: session())
        XCTAssertEqual(s.state, .empty)
    }

    /// E-26, T-40: commands and open events reach the key window's session only.
    func testKeyWindowRouting() {
        let a = session(), b = session()
        let wa = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let wb = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        model.register(session: a, window: wa); model.register(session: b, window: wb)
        XCTAssertTrue(model.session(for: wb) === b)
        model.keyWindowProvider = { wb }
        model.handleOpenEvent(urls: [u("/d/a.md")])
        XCTAssertNil(a.currentEntry); XCTAssertEqual(b.currentEntry?.path, "/d/a.md")
        XCTAssertTrue(model.keySession === b)
        model.unregister(window: wb)
        XCTAssertNil(model.session(for: wb))
        model.keyWindowProvider = { nil }
        XCTAssertTrue(model.keySession === a, "with no key window the first registered session acts (cold start)")
    }

    /// T-40, E-26, R-01, R-18: two windows on different files, window 2 key — an open event loads into window 2 only; ⌘D
    /// (`bookmarkCurrentSpot` on the key session) adds exactly one bookmark, window 2's; ⌘← moves window 2 only; ⌘F opens
    /// window 2's find bar only.
    func testCommandsReachTheKeyWindowOnly() {
        let a = session(), b = session()
        let wa = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let wb = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        model.register(session: a, window: wa); model.register(session: b, window: wb)
        a.open(urls: [u("/d/a.md")]); b.open(urls: [u("/d/b.md")])
        model.keyWindowProvider = { wb }
        model.handleOpenEvent(urls: [u("/d/c.md")])                                 // open -a … c.md
        XCTAssertEqual(a.currentEntry?.path, "/d/a.md"); XCTAssertEqual(b.currentEntry?.path, "/d/c.md")
        let before = model.bookmarks.bookmarks.count
        model.keySession?.bookmarkCurrentSpot()                                       // ⌘D
        XCTAssertEqual(model.bookmarks.bookmarks.count, before + 1)
        XCTAssertEqual(model.bookmarks.bookmarks.last?.path, "/d/c.md", "window 2's bookmark")
        XCTAssertNotNil(b.currentBookmarkID); XCTAssertNil(a.currentBookmarkID)
        model.keySession?.goBack()                                                    // ⌘←
        XCTAssertEqual(b.currentEntry?.path, "/d/b.md"); XCTAssertEqual(a.currentEntry?.path, "/d/a.md")
        model.keySession?.openFind()                                                  // ⌘F
        XCTAssertNotNil(b.findState); XCTAssertNil(a.findState)
    }

    /// R-21: the inspector's table of contents is the document's single-line ATX `#`–`###` headings (C-02) with math shown
    /// as Unicode, its rows jump to their block, its filter narrows rows, and its visibility and width persist (C-04).
    func testInspectorContents() {
        fs.contents["/d/toc.md"] = "# Top $\\alpha$\n\n## Two\n\n### Three\n\n#### Four\n\nSetext\n======\n\ntext"
        let s = session()
        s.open(urls: [u("/d/toc.md")])
        let toc = s.document!.tocHeadings
        XCTAssertEqual(toc.map(\.level), [1, 2, 3], "h4 and setext headings are not TOC rows")
        XCTAssertEqual(toc.map(\.text), ["Top α", "Two", "Three"], "math as Unicode, not LaTeX source")
        s.selectTOC(blockIndex: toc[2].blockIndex)
        XCTAssertEqual(s.scrollTarget?.block, toc[2].blockIndex, "a row jumps to its block")
        XCTAssertEqual(s.tocSelectedBlock, toc[2].blockIndex)
        XCTAssertEqual(toc.filter { $0.text.localizedCaseInsensitiveContains("tw") }.map(\.text), ["Two"], "the filter rule the pane applies")
        model.preferences.inspectorVisible = true
        model.preferences.inspectorWidth = 300
        let relaunched = AppModel.bootstrap(supportDir: dir, defaultsSuite: suite, fileSystem: fs)
        XCTAssertTrue(relaunched.preferences.inspectorVisible); XCTAssertEqual(relaunched.preferences.inspectorWidth, 300)
        model.preferences.inspectorWidth = 900
        XCTAssertEqual(AppModel.bootstrap(supportDir: dir, defaultsSuite: suite, fileSystem: fs).preferences.inspectorWidth, 520, "clamped to K-04")
    }

    /// R-31, T-38: ⌘? copies the bundled Help.md over the support-directory copy every time and opens it as an adding route.
    func testHelpOverwrittenEveryTime() {
        let s = DocumentSession(model: AppModel.bootstrap(supportDir: dir, defaultsSuite: suite), clock: clock,
                                watcherFactory: { p, c in FakeWatcher(path: p.path, onChange: c) }, pasteboard: { _ in }, systemOpener: { _ in }, beeper: {})
        HelpManager.openHelp(in: s)
        let help = dir.appendingPathComponent("Help.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: help.path))
        XCTAssertEqual(s.currentEntry?.path, help.path)
        try! "stale".write(to: help, atomically: true, encoding: .utf8)
        HelpManager.openHelp(in: s)
        XCTAssertNotEqual(try! String(contentsOf: help, encoding: .utf8), "stale")
        XCTAssertEqual(s.model.history.entries.filter { $0.path == help.path }.count, 1)
        XCTAssertTrue(s.document!.raw.contains("# mdv6"))
    }

    /// R-23, T-38: ⌘E with no editor asks for one; with an editor it launches; a launch failure is reported (and logged).
    func testEditorOutcomes() {
        let s = session()
        s.open(urls: [u("/d/a.md")])
        XCTAssertEqual(s.openInEditor(), .needsChooser)
        model.preferences.editorAppPath = "/Applications/Definitely Not Here.app"
        var lines: [String] = []
        Diagnostics.sink = { lines.append($0) }
        defer { Diagnostics.sink = nil }
        guard case .failed = s.openInEditor() else { return XCTFail("launch failure expected") }
        XCTAssertTrue(lines.contains { $0.contains("editor") })
    }

    // MARK: I-004 (T-30)

    /// I-004, T-30: the TOC row, a find match and a bookmark for one paragraph all address the same block index.
    func testOneBlockIndexEverywhere() {
        let s = session()
        s.open(urls: [u("/d/a.md")])
        let toc = s.document!.tocHeadings.first { $0.text == "Second heading" }!.blockIndex
        s.openFind(); s.setFindQuery("Second heading")
        XCTAssertEqual(s.findState?.matches.first?.blockIndex, toc)
        s.hoveredBlockIndex = toc; s.bookmarkCurrentSpot()
        XCTAssertEqual(model.bookmarks.bookmarks.last?.blockIndex, toc)
        XCTAssertEqual(s.document!.blocks[toc], "## Second heading")
    }
}
