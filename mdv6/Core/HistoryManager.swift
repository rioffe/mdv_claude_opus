// HistoryManager — C-15 history entries and their JSON codec, and the R-20/R-26 history list (I-013, K-03).
import Foundation

/// C-15: one history row. `filename` is derived, not stored.
public struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let path: String
    public let addedAt: Date

    public init(id: UUID = UUID(), path: String, addedAt: Date = Date()) {
        self.id = id
        self.path = path
        self.addedAt = addedAt
    }

    public var filename: String { (path as NSString).lastPathComponent }

    private enum CodingKeys: String, CodingKey { case id, path, addedAt }   // unknown keys are ignored by Codable
}

public enum HistoryCodec {
    /// C-15: default `JSONEncoder` date strategy (seconds since 2001-01-01 as Double).
    public static func encode(_ entries: [HistoryEntry]) -> Data {
        (try? JSONEncoder().encode(entries)) ?? Data("[]".utf8)
    }

    /// C-15: a value that fails to decode yields an empty history, never a crash.
    public static func decode(_ data: Data?) -> [HistoryEntry] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
    }
}

/// R-20, R-26, I-013: the history list — most recently *added* first, ≤ 100 entries, no duplicate paths, persisted
/// under `mdv6_history` (C-15); adding routes index the file (mtime-gated), selecting routes touch nothing.
public final class HistoryManager: ObservableObject {
    /// K-03.
    public static let cap = 100

    @Published public private(set) var entries: [HistoryEntry]
    private let defaults: UserDefaults
    private let database: Database
    private let fileSystem: FileSystem
    private let indexQueue = DispatchQueue(label: "com.mdv6.history.reindex", qos: .utility)

    public init(defaults: UserDefaults, database: Database, fileSystem: FileSystem = .live) {
        self.defaults = defaults
        self.database = database
        self.fileSystem = fileSystem
        self.entries = HistoryCodec.decode(defaults.data(forKey: Preferences.Key.history))
    }

    /// R-01 adding route: the row moves to (or is inserted at) the top, the file is indexed unless its mtime is unchanged
    /// (R-26, K-06), and the oldest row past 100 is evicted with its index row and scroll position.
    @discardableResult
    public func add(path: String) -> HistoryEntry {
        var list = entries
        let entry: HistoryEntry
        if let i = list.firstIndex(where: { $0.path == path }) {
            entry = HistoryEntry(id: list[i].id, path: path, addedAt: Date())
            list.remove(at: i)
        } else {
            entry = HistoryEntry(path: path)
        }
        list.insert(entry, at: 0)
        while list.count > HistoryManager.cap {
            let evicted = list.removeLast()
            database.removeFile(path: evicted.path)
        }
        entries = list
        save()
        index(path: path)
        return entry
    }

    /// R-01 selecting route: the entry the list already holds; order and index untouched.
    public func select(path: String) -> HistoryEntry? { entries.first { $0.path == path } }

    /// R-20 swipe-delete: removes the row, its index row and scroll position (R-26); returns the new head (§3.1).
    @discardableResult
    public func remove(_ entry: HistoryEntry) -> HistoryEntry? {
        entries.removeAll { $0.id == entry.id }
        database.removeFile(path: entry.path)
        save()
        return entries.first
    }

    /// R-26 (exists, unreachable from the UI).
    public func clear() {
        for e in entries { database.removeFile(path: e.path) }
        entries = []
        save()
    }

    /// R-26 launch: drop index rows whose path is not in history, then re-index every history file whose mtime changed.
    public func reindexOnLaunch(completion: (() -> Void)? = nil) {
        let paths = entries.map(\.path)
        indexQueue.async { [self] in
            database.prune(keeping: Set(paths))
            for p in paths { index(path: p) }
            if let completion { DispatchQueue.main.async(execute: completion) }
        }
    }

    private func index(path: String) {
        guard let mtime = fileSystem.mtimeSeconds(path) else { return }
        if let stored = database.indexedMtime(path: path), stored == mtime { return }     // K-06: whole seconds, equality
        guard let content = try? fileSystem.readUTF8(path) else { return }
        database.indexFile(path: path, content: content, mtime: mtime, size: content.utf8.count)
    }

    private func save() { defaults.set(HistoryCodec.encode(entries), forKey: Preferences.Key.history) }
}
