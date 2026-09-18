// BookmarksManager — R-27: persisted, ordered bookmarks with five hotkey slots, reorder (C-18.9 moves) and removal (E-09).
import Foundation

public final class BookmarksManager: ObservableObject {
    /// K-03: five hotkey slots (⌘1…⌘5).
    public static let slotCount = 5

    @Published public private(set) var bookmarks: [Database.BookmarkRow] = []
    private let database: Database
    private let fileSystem: FileSystem

    public init(database: Database, fileSystem: FileSystem = .live) {
        self.database = database
        self.fileSystem = fileSystem
        reload()
    }

    public func reload() { bookmarks = database.bookmarks() }

    /// R-27: title by the R-27 rule, anchor = block index + C-08 fingerprint; the same block twice creates two rows.
    @discardableResult
    public func add(path: String, document: ParsedDocument, index: Int) -> Database.BookmarkRow? {
        let i = document.blocks.isEmpty ? 0 : min(max(index, 0), document.blocks.count - 1)
        let title = BookmarkTitle.title(blocks: document.blocks, toc: document.tocHeadings, index: i)
        let fingerprint = document.blocks.isEmpty ? "" : bookmarkFingerprint(document.blocks[i])
        let row = database.addBookmark(path: path, title: title, blockIndex: i, fingerprint: fingerprint)
        reload()
        return row
    }

    public func remove(id: Int64) {
        database.removeBookmark(id: id)
        reload()
    }

    /// R-27: slot n (1…5) is the n-th bookmark in persisted order.
    public func slot(_ n: Int) -> Database.BookmarkRow? {
        guard n >= 1, n <= BookmarksManager.slotCount, n <= bookmarks.count else { return nil }
        return bookmarks[n - 1]
    }

    public func index(of id: Int64) -> Int? { bookmarks.firstIndex { $0.id == id } }

    /// Moves the row to `position` (clamped) and persists the whole order; the slots follow (C-18.9).
    public func move(id: Int64, to position: Int) {
        guard let from = index(of: id) else { return }
        var ids = bookmarks.map(\.id)
        ids.remove(at: from)
        ids.insert(id, at: min(max(position, 0), ids.count))
        database.reorderBookmarks(ids: ids)
        reload()
    }

    public func moveUp(id: Int64) { if let i = index(of: id), i > 0 { move(id: id, to: i - 1) } }
    public func moveDown(id: Int64) { if let i = index(of: id), i < bookmarks.count - 1 { move(id: id, to: i + 1) } }
    public func moveToTop(id: Int64) { move(id: id, to: 0) }
    public func moveToBottom(id: Int64) { move(id: id, to: bookmarks.count - 1) }

    /// Drag reorder (SwiftUI `onMove` semantics).
    public func move(fromOffsets: IndexSet, toOffset: Int) {
        var ids = bookmarks.map(\.id)
        ids.move(fromOffsets: fromOffsets, toOffset: toOffset)
        database.reorderBookmarks(ids: ids)
        reload()
    }

    /// Toolbar `bookmark.fill` state (§5.1).
    public func hasBookmark(path: String) -> Bool { bookmarks.contains { $0.path == path } }

    /// E-09: the file no longer exists.
    public func isMissing(_ row: Database.BookmarkRow) -> Bool { !fileSystem.exists(row.path) }
}
