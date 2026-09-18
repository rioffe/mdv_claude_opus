// DocumentSession — one window's document (§3.1 lifecycle) and every rule that acts on it: the adding/selecting routes
// (R-01), directory and drop (R-02, R-03), decode-before-history (R-04, E-03), the path watcher and reload rules
// (R-05, E-21), scroll persistence and restoration (R-06, C-08, E-08), the back/forward stacks (R-18, E-27), links
// (R-19, C-11, E-05, E-06), the TOC selection (E-29), heading copy (R-22), the find model (R-24, E-17, E-18), bookmarks
// and the placeholder (R-27, R-28, E-09), the editor (R-23) and launch (R-40). Headless: views observe it.
import Foundation
import AppKit
import SwiftUI

public enum DocumentState: Equatable, Sendable { case empty, loading, viewing, reloading, closed }

/// R-01: adding routes add/move the history row and index; selecting routes display an existing row untouched.
public enum OpenRoute: Sendable { case adding, selecting }

/// R-18: `(history entry, top block index)`.
public struct NavSnapshot: Equatable, Sendable {
    public let entry: HistoryEntry
    public let topBlock: Int
}

/// A scroll request: the block index plus a token so an identical target re-fires.
public struct ScrollTarget: Equatable, Sendable {
    public let block: Int
    public let token: Int
}

public enum EditorOutcome: Equatable { case opened, needsChooser, failed(message: String) }

/// E-18 / R-24: where ⌘F goes.
public enum FindCommandTarget: Equatable { case findBar, globalSearch }

@MainActor
public final class DocumentSession: ObservableObject, ArticleHost {
    /// K-06: heading-copy flash 0.6 s.
    public static let flashDuration: TimeInterval = 0.6
    /// K-06 / D-18: a zero-byte read is re-read after 500 ms.
    public static let emptyReadRetry: TimeInterval = 0.5
    /// R-02 / R-19: the Markdown extensions for directory scans and in-app link navigation.
    public static let markdownExtensions: Set<String> = ["md", "markdown", "mdown"]
    /// R-03: the extensions a drop accepts.
    public static let dropExtensions: Set<String> = ["md", "markdown", "txt", "mdown", "mkd"]

    public let model: AppModel
    private let fileSystem: FileSystem
    private let clock: SessionClock
    private let watcherFactory: (URL, @escaping () -> Void) -> FileWatching
    private let pasteboard: (String) -> Void
    private let systemOpener: (URL) -> Void
    private let beeper: () -> Void

    // MARK: observable state

    @Published public private(set) var state: DocumentState = .empty
    @Published public private(set) var document: ParsedDocument?
    @Published public private(set) var currentEntry: HistoryEntry?
    @Published public var topVisibleBlock: Int = 0
    @Published public var hoveredBlockIndex: Int?
    @Published public private(set) var scrollTarget: ScrollTarget?
    @Published public private(set) var tocSelectedBlock: Int?
    @Published public private(set) var flashedRange: Range<Int>?
    @Published public private(set) var findState: FindState?
    @Published public private(set) var currentBookmarkID: Int64?
    @Published public private(set) var placeholderIsCurrent = false
    @Published public private(set) var renderGeneration = 0
    @Published public var backingScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2
    /// R-29: whether macOS is in Dark appearance (the window updates it; the System theme follows it).
    @Published public var isDarkAppearance = false
    /// R-16: turning the preference off cancels in-flight remote-image requests.
    public let remoteLoader: RemoteImageLoader? = RemoteImageLoader()

    private var backStack: [NavSnapshot] = []
    private var forwardStack: [NavSnapshot] = []
    private var watcher: FileWatching?
    private var flashTimer: SessionTimer?
    private var emptyRetryTimer: SessionTimer?
    private var scrollToken = 0

    public init(model: AppModel, clock: SessionClock = LiveClock(),
                watcherFactory: @escaping (URL, @escaping () -> Void) -> FileWatching = { FileWatcher(path: $0, onChange: $1) },
                pasteboard: @escaping (String) -> Void = { Pasteboard.copy($0) },
                systemOpener: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
                beeper: @escaping () -> Void = { NSSound.beep() }) {
        self.model = model
        self.fileSystem = model.fileSystem
        self.clock = clock
        self.watcherFactory = watcherFactory
        self.pasteboard = pasteboard
        self.systemOpener = systemOpener
        self.beeper = beeper
    }

    // MARK: ArticleHost

    public var theme: MDVTheme { ThemeCatalog.resolve(id: model.preferences.themeId, isDarkAppearance: isDarkAppearance) }
    public var zoom: CGFloat { CGFloat(model.preferences.fontScale) }
    public var smartTypography: Bool { model.preferences.smartTypography }
    public var loadRemoteImages: Bool { model.preferences.loadRemoteImages }
    public var mermaidStyle: MermaidStyle { MermaidStyle(storedValue: model.preferences.mermaidStyle) }
    public var baseURL: URL? { currentEntry.map { URL(fileURLWithPath: $0.path).deletingLastPathComponent() } }
    public func hoverChanged(_ index: Int?) { hoveredBlockIndex = index }
    public func linkClicked(_ url: URL) { handleLink(url) }
    public func revealRemoteImageSetting() { NotificationCenter.default.post(name: .mdv6RevealRemoteImageSetting, object: nil) }
    public func setMermaidStyle(_ style: MermaidStyle) { model.preferences.mermaidStyle = style.rawValue }

    // MARK: derived

    /// C-18.1: the file's last path component, or the product name when `EMPTY`.
    public var windowTitle: String { currentEntry?.filename ?? "mdv6" }
    public var currentPath: String? { currentEntry?.path }
    public var canGoBack: Bool { !backStack.isEmpty }
    public var canGoForward: Bool { !forwardStack.isEmpty }
    public var backCount: Int { backStack.count }
    public var hasBookmarkForCurrentFile: Bool { currentPath.map { model.bookmarks.hasBookmark(path: $0) } ?? false }

    private func requestScroll(to block: Int) {
        scrollToken += 1
        scrollTarget = ScrollTarget(block: block, token: scrollToken)
    }

    // MARK: reading (R-04, R-41)

    /// R-04: read and decode strictly as UTF-8 (the K-14 ceiling first, R-41) **before** any history change.
    private func readDocument(_ path: String) -> String? {
        try? fileSystem.readUTF8(path)
    }

    // MARK: routes (R-01, §3.1)

    /// Loads one file. Returns `false` (E-03: nothing changed) when unreadable. `pushSnapshot` is false for bookmark,
    /// placeholder, cold-start and delete-current loads (R-18); `suppressRestore` for cross-file fragments (R-19).
    @discardableResult
    public func open(_ url: URL, route: OpenRoute, suppressRestore: Bool = false, pushSnapshot: Bool = true) -> Bool {
        let path = url.standardizedFileURL.path
        if fileSystem.isDirectory(path) { return loadDirectory(url) }
        guard let text = readDocument(path) else { return false }          // E-03: previous state kept
        state = .loading
        if document != nil { persistScrollPosition() }
        if pushSnapshot, let entry = currentEntry, entry.path != path {
            backStack.append(NavSnapshot(entry: entry, topBlock: topVisibleBlock))
            forwardStack.removeAll()
        }
        let entry: HistoryEntry
        switch route {
        case .adding: entry = model.history.add(path: path)
        case .selecting: entry = model.history.select(path: path) ?? model.history.add(path: path)
        }
        install(document: ParsedDocument(raw: text), entry: entry)
        if !suppressRestore { restoreScroll(path: path) } else { topVisibleBlock = 0; requestScroll(to: 0) }
        return true
    }

    /// R-01: each URL is added in the order received and the last is displayed.
    public func open(urls: [URL], pushSnapshot: Bool = true) {
        guard let last = urls.last else { return }
        for url in urls.dropLast() {
            let path = url.standardizedFileURL.path
            if fileSystem.isDirectory(path) { continue }
            guard readDocument(path) != nil else { continue }                // R-04: decode before the history change
            model.history.add(path: path)
        }
        open(last, route: .adding, pushSnapshot: pushSnapshot)
    }

    /// R-02: `README.md` (case-insensitive stem) else the first Markdown file by localized case-insensitive order; every
    /// other such file becomes a history row (primary first, then the rest in that order). E-04: nothing on an empty directory.
    @discardableResult
    public func loadDirectory(_ url: URL) -> Bool {
        let dir = url.standardizedFileURL.path
        let names = fileSystem.directoryContents(dir)
            .filter { !$0.hasPrefix(".") && DocumentSession.markdownExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .filter { readDocument((dir as NSString).appendingPathComponent($0)) != nil }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        guard !names.isEmpty else { return false }
        let primary = names.first { ($0 as NSString).deletingPathExtension.lowercased() == "readme" } ?? names[0]
        let others = names.filter { $0 != primary }
        for name in others.reversed() { model.history.add(path: (dir as NSString).appendingPathComponent(name)) }
        return open(URL(fileURLWithPath: (dir as NSString).appendingPathComponent(primary)), route: .adding)
    }

    /// R-03: only the first item; accepted extensions only; anything else ignored without error.
    @discardableResult
    public func handleDrop(_ urls: [URL]) -> Bool {
        guard let first = urls.first, DocumentSession.dropExtensions.contains(first.pathExtension.lowercased()) else { return false }
        return open(first, route: .adding)
    }

    /// R-01 selecting route: a history row.
    public func selectHistoryRow(_ entry: HistoryEntry) { open(URL(fileURLWithPath: entry.path), route: .selecting) }

    /// R-25: a hit already in history is selecting; otherwise adding.
    public func openHit(path: String) {
        let route: OpenRoute = model.history.entries.contains { $0.path == path } ? .selecting : .adding
        open(URL(fileURLWithPath: path), route: route)
    }

    /// R-20 swipe-delete (§3.1): the deleted entry's snapshots are dropped; the displayed row's removal loads the new head
    /// as a selecting route without a snapshot, or enters `EMPTY` when no rows remain.
    public func deleteHistoryRow(_ entry: HistoryEntry) {
        let wasDisplayed = currentEntry?.id == entry.id
        let newHead = model.history.remove(entry)
        backStack.removeAll { $0.entry.id == entry.id }
        forwardStack.removeAll { $0.entry.id == entry.id }
        guard wasDisplayed else { return }
        if let newHead, open(URL(fileURLWithPath: newHead.path), route: .selecting, pushSnapshot: false) { return }
        enterEmpty()
    }

    private func enterEmpty() {
        watcher?.cancel(); watcher = nil
        document = nil
        currentEntry = nil
        tocSelectedBlock = nil
        findState = findState.map { FindState(query: $0.query, matches: [], current: 0) }
        currentBookmarkID = nil
        placeholderIsCurrent = false
        renderGeneration += 1
        state = .empty
    }

    private func install(document doc: ParsedDocument, entry: HistoryEntry) {
        let sameDocument = currentEntry?.path == entry.path
        document = doc
        currentEntry = entry
        renderGeneration += 1                                                  // E-25
        if !sameDocument {
            tocSelectedBlock = nil                                             // E-29
            currentBookmarkID = nil
            placeholderIsCurrent = false
        }
        flashedRange = nil
        recountFind(resetToFirst: true)
        armWatcher(path: entry.path)
        state = .viewing
    }

    private func armWatcher(path: String) {
        watcher?.cancel()
        watcher = watcherFactory(URL(fileURLWithPath: path)) { [weak self] in self?.reloadFromDisk() }
    }

    // MARK: R-05 / E-21 reload

    /// The watcher callback: a readable change replaces the content in place (position kept, clamped; selection not
    /// preserved); a failed/undecodable read is ignored; a zero-byte read while content is displayed is re-read after
    /// 500 ms and that read is shown (D-18).
    public func reloadFromDisk() {
        guard let path = currentPath, state == .viewing || state == .reloading else { return }
        guard let text = readDocument(path) else { return }                    // E-21: deleted / mid-save: ignored
        if text.isEmpty && !(document?.raw.isEmpty ?? true) {
            emptyRetryTimer?.cancel()
            emptyRetryTimer = clock.schedule(after: DocumentSession.emptyReadRetry) { [weak self] in
                guard let self, self.currentPath == path, let again = self.readDocument(path) else { return }
                self.swap(text: again)
            }
            return
        }
        emptyRetryTimer?.cancel(); emptyRetryTimer = nil
        swap(text: text)
    }

    private func swap(text: String) {
        state = .reloading
        let doc = ParsedDocument(raw: text)
        let keptHeading = tocSelectedBlock.flatMap { i -> Int? in
            guard let old = document, i < old.blocks.count, i < doc.blocks.count else { return nil }
            return doc.blocks[i].split(separator: "\n").first == old.blocks[i].split(separator: "\n").first ? i : nil
        }
        document = doc
        renderGeneration += 1
        tocSelectedBlock = keptHeading                                          // E-29
        topVisibleBlock = doc.blocks.isEmpty ? 0 : min(topVisibleBlock, doc.blocks.count - 1)
        recountFind(resetToFirst: true)                                          // R-24
        state = .viewing
    }

    // MARK: R-06 scroll positions

    public func persistScrollPosition() {
        guard let path = currentPath, let doc = document else { return }
        let index = doc.blocks.isEmpty ? 0 : min(max(topVisibleBlock, 0), doc.blocks.count - 1)
        let fingerprint = doc.blocks.isEmpty ? "" : bookmarkFingerprint(doc.blocks[index])
        model.database.saveScrollPosition(path: path, blockIndex: index, fingerprint: fingerprint, fileMtime: fileSystem.mtimeSeconds(path) ?? 0)
    }

    private func restoreScroll(path: String) {
        guard let doc = document, let row = model.database.scrollPosition(path: path),
              AnchorValidity.scrollRestorable(storedMtime: row.fileMtime, fileMtime: fileSystem.mtimeSeconds(path) ?? -100, index: row.blockIndex, count: doc.blocks.count) else {
            topVisibleBlock = 0; requestScroll(to: 0); return
        }
        let target = resolveBookmarkAnchor(blocks: doc.blocks, storedIndex: row.blockIndex, fingerprint: row.fingerprint)
        topVisibleBlock = target
        requestScroll(to: target)
    }

    /// §3.1 `CLOSED`: position persisted, watcher cancelled.
    public func windowWillClose() {
        persistScrollPosition()
        watcher?.cancel(); watcher = nil
        remoteLoader?.cancelAll()
        state = .closed
    }

    // MARK: R-18 navigation

    public func goBack() { step(from: &backStack, to: &forwardStack) }
    public func goForward() { step(from: &forwardStack, to: &backStack) }

    private func step(from: inout [NavSnapshot], to: inout [NavSnapshot]) {
        while let snapshot = from.popLast() {
            guard model.history.entries.contains(where: { $0.id == snapshot.entry.id }) else { continue }   // removed row: skipped
            guard fileSystem.exists(snapshot.entry.path) else { beeper(); return }                          // E-27: discarded
            if let entry = currentEntry { to.append(NavSnapshot(entry: entry, topBlock: topVisibleBlock)) }
            let ok = open(URL(fileURLWithPath: snapshot.entry.path), route: .selecting, suppressRestore: true, pushSnapshot: false)
            if !ok { to.removeLast(); beeper(); return }
            let target = document.map { $0.blocks.isEmpty ? 0 : min(snapshot.topBlock, $0.blocks.count - 1) } ?? 0
            topVisibleBlock = target
            requestScroll(to: target)
            return
        }
    }

    /// R-18: a same-document jump pushes a snapshot and clears the forward stack.
    private func pushSameDocumentSnapshot() {
        guard let entry = currentEntry else { return }
        backStack.append(NavSnapshot(entry: entry, topBlock: topVisibleBlock))
        forwardStack.removeAll()
    }

    /// C-18.8 / R-21: a TOC row pushes a snapshot, scrolls to the block and becomes the selected row (E-29).
    public func selectTOC(blockIndex: Int) {
        pushSameDocumentSnapshot()
        tocSelectedBlock = blockIndex
        topVisibleBlock = blockIndex
        requestScroll(to: blockIndex)
    }

    // MARK: R-19 links

    public func handleLink(_ url: URL) {
        let fragment = url.fragment(percentEncoded: true)
        let decodedFragment = fragment?.removingPercentEncoding                       // decoded exactly once; invalid → nil
        let scheme = url.scheme?.lowercased()
        let pathPart: String?
        if scheme == nil {
            let raw = url.path
            if raw.isEmpty { pathPart = nil }
            else if raw.hasPrefix("/") { pathPart = raw }
            else { pathPart = ((baseURL?.path ?? "/") as NSString).appendingPathComponent(raw) }
        } else if scheme == "file" {
            pathPart = url.path
        } else {
            systemOpener(url); return                                               // any other scheme is not a path
        }
        let resolved = pathPart.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        // same-document fragment
        if resolved == nil || resolved == currentPath {
            if fragment != nil, let doc = document {
                if let block = slugTarget(decodedFragment, in: doc) {
                    pushSameDocumentSnapshot()
                    tocSelectedBlock = block
                    topVisibleBlock = block
                    requestScroll(to: block)
                }
                return                                                              // E-06: no match → no-op
            }
            if resolved == currentPath, resolved != nil { return }                 // re-opening the current path pushes nothing
            return
        }
        guard let target = resolved, fileSystem.exists(target), !fileSystem.isDirectory(target),
              DocumentSession.markdownExtensions.contains((target as NSString).pathExtension.lowercased()) else {
            systemOpener(url); return                                               // E-05: missing / other extension → opener
        }
        guard open(URL(fileURLWithPath: target), route: .adding, suppressRestore: fragment != nil) else { systemOpener(url); return }
        if fragment != nil, let doc = document {
            if let block = slugTarget(decodedFragment, in: doc) {
                tocSelectedBlock = block                                            // E-29: a cross-file fragment selects
                topVisibleBlock = block
                requestScroll(to: block)
            }                                                                       // E-06: no match → stays at the top
        }
    }

    /// C-11: the first TOC heading whose slug equals the fragment's slug (D-17: first in document order).
    private func slugTarget(_ fragment: String?, in doc: ParsedDocument) -> Int? {
        guard let fragment, !fragment.isEmpty else { return nil }
        let wanted = headingSlug(fragment)
        guard !wanted.isEmpty else { return nil }
        return doc.tocHeadings.first { headingSlug($0.slugText) == wanted }?.blockIndex
    }

    // MARK: R-22 heading copy

    public func copySection(at index: Int) {
        guard let doc = document, index < doc.blocks.count else { return }
        let range = sectionRange(blocks: doc.blocks, tocHeadings: doc.tocHeadings, headingAt: index)
        pasteboard(doc.blocks[range].joined(separator: "\n\n"))
        flashedRange = nil
        flashedRange = range
        flashTimer?.cancel()
        flashTimer = clock.schedule(after: DocumentSession.flashDuration) { [weak self] in self?.flashedRange = nil }
    }

    // MARK: R-24 find

    public func openFind() {
        if findState == nil { findState = FindState() }
        recountFind(resetToFirst: true)
    }

    public func closeFind() { findState = nil }

    public func setFindQuery(_ query: String) {
        if findState == nil { findState = FindState() }
        findState?.query = query
        recountFind(resetToFirst: true)
        scrollToCurrentMatch()
    }

    public func findNext() { stepFind(1) }
    public func findPrevious() { stepFind(-1) }

    private func stepFind(_ delta: Int) {
        guard var f = findState, !f.matches.isEmpty else { return }
        f.current = (f.current + delta + f.matches.count) % f.matches.count
        findState = f
        scrollToCurrentMatch()
    }

    private func recountFind(resetToFirst: Bool) {
        guard var f = findState else { return }
        f.matches = FindHighlight.matches(query: f.query, blocks: document?.blocks ?? [])
        if resetToFirst || f.current >= f.matches.count { f.current = 0 }
        findState = f
    }

    private func scrollToCurrentMatch() {
        guard let block = findState?.currentBlock else { return }
        topVisibleBlock = block
        requestScroll(to: block)
    }

    /// E-18: ⌘F routes to global search while the sidebar has focus (R-24's definition).
    public func findCommandTarget(sidebarHasFocus: Bool) -> FindCommandTarget { sidebarHasFocus ? .globalSearch : .findBar }

    // MARK: R-27 bookmarks

    /// R-27: the hovered block, else the topmost block in the viewport.
    private var anchorBlock: Int? {
        guard let doc = document, !doc.blocks.isEmpty else { return nil }
        return min(max(hoveredBlockIndex ?? topVisibleBlock, 0), doc.blocks.count - 1)
    }

    public func bookmarkCurrentSpot() {
        guard let path = currentPath, let doc = document else { return }
        model.bookmarks.add(path: path, document: doc, index: anchorBlock ?? 0)
    }

    /// R-27 / E-09: loads the file if needed (no snapshot), scrolls to the resolved anchor, marks the row current; beeps when missing.
    public func openBookmark(_ row: Database.BookmarkRow) {
        guard fileSystem.exists(row.path) else { beeper(); return }
        if row.path != currentPath {
            guard open(URL(fileURLWithPath: row.path), route: .adding, suppressRestore: true, pushSnapshot: false) else { beeper(); return }
        }
        guard let doc = document else { return }
        let target = resolveBookmarkAnchor(blocks: doc.blocks, storedIndex: row.blockIndex, fingerprint: row.fingerprint)
        currentBookmarkID = row.id
        placeholderIsCurrent = false
        if doc.tocHeadings.contains(where: { $0.blockIndex == target }) { tocSelectedBlock = target }
        topVisibleBlock = target
        requestScroll(to: target)
    }

    public func openSlot(_ n: Int) {
        guard let row = model.bookmarks.slot(n) else { return }
        openBookmark(row)
    }

    // MARK: R-28 placeholder

    public func setPlaceholder() {
        guard let path = currentPath, let doc = document else { return }
        let index = anchorBlock ?? 0
        let title = BookmarkTitle.title(blocks: doc.blocks, toc: doc.tocHeadings, index: index)
        let fingerprint = doc.blocks.isEmpty ? "" : bookmarkFingerprint(doc.blocks[index])
        model.placeholder.set(Placeholder(path: path, blockIndex: index, fingerprint: fingerprint, title: title))
        model.preferences.bookmarksExpanded = true
        placeholderIsCurrent = true
        currentBookmarkID = nil
    }

    /// ⌘0: beeps with no placeholder or a missing file (E-27); loads the file first (adding, no snapshot) when needed.
    public func jumpToPlaceholder() {
        guard let p = model.placeholder.placeholder else { beeper(); return }
        guard fileSystem.exists(p.path) else { beeper(); return }
        if p.path != currentPath {
            guard open(URL(fileURLWithPath: p.path), route: .adding, suppressRestore: true, pushSnapshot: false) else { beeper(); return }
        }
        guard let doc = document else { return }
        let target = resolveBookmarkAnchor(blocks: doc.blocks, storedIndex: p.blockIndex, fingerprint: p.fingerprint)
        placeholderIsCurrent = true
        currentBookmarkID = nil
        topVisibleBlock = target
        requestScroll(to: target)
    }

    public func clearPlaceholder() {
        model.placeholder.clear()
        placeholderIsCurrent = false
    }

    // MARK: R-23 editor

    public func openInEditor() -> EditorOutcome {
        guard let path = currentPath else { return .needsChooser }
        let editor = model.preferences.editorAppPath
        guard !editor.isEmpty else { return .needsChooser }
        switch EditorLauncher.open(file: URL(fileURLWithPath: path), editorAppPath: editor) {
        case .success: return .opened
        case .failure(let error): return .failed(message: error.localizedDescription)
        }
    }

    // MARK: R-40 launch

    /// Exactly the history head, as a selecting route with its position (D-28); unreadable → `EMPTY`, row kept.
    public func restoreOnLaunch() {
        guard let head = model.history.entries.first else { state = .empty; return }
        if !open(URL(fileURLWithPath: head.path), route: .selecting, pushSnapshot: false) { state = .empty }
    }

    /// A cold-start argument pre-empts restoration; no snapshot for the unseen head (D-29).
    public func coldStart(_ urls: [URL]) {
        open(urls: urls, pushSnapshot: false)
        backStack.removeAll()
        forwardStack.removeAll()
    }
}

extension Notification.Name {
    /// R-16: the "Remote image blocked" placeholder reveals the View menu item.
    public static let mdv6RevealRemoteImageSetting = Notification.Name("mdv6.revealRemoteImageSetting")
}
