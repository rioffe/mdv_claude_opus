// Database — the one `mdv6.db` connection (§3.3, I-006): C-03 full-text index and search, C-08 bookmarks and scroll
// positions, forward migrations each in one transaction, whole-row writes (I-007), and E-12 degradation.
import Foundation
import SQLite3

private let SQLITE_TRANSIENT_PTR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class Database {
    /// §3.3: `meta.schema_version` is currently 4.
    public static let schemaVersion = 4
    /// Test hook (§3.3 atomic migrations): the 0-based migration at which a failing statement is injected after its first statement.
    nonisolated(unsafe) public static var migrationFaultInjection: Int? = nil

    public let url: URL
    public private(set) var isAvailable = false
    public private(set) var openFlagsIncludeFullMutex = false
    private var handle: OpaquePointer?
    private var failureLogged = false

    // MARK: open (§3.3, I-006, E-12)

    public init(url: URL) {
        self.url = url
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var db: OpaquePointer? = nil
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        openFlagsIncludeFullMutex = (flags & SQLITE_OPEN_FULLMUTEX) != 0
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            if let db { sqlite3_close(db) }
            fail("cannot open \(url.path): \(msg)")
            return
        }
        handle = db
        isAvailable = true
        sqlite3_busy_timeout(db, 2000)
        guard exec("PRAGMA journal_mode = WAL") != nil, exec("PRAGMA synchronous = NORMAL") != nil else { return }
        guard exec("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)") != nil else { return }
        migrate()
    }

    deinit { close() }

    public func close() {
        if let h = handle { sqlite3_close(h); handle = nil }
        isAvailable = false
    }

    /// E-12: log once (`[mdv6] …`, never a query string or content), then degrade.
    private func fail(_ detail: String) {
        isAvailable = false
        if !failureLogged {
            failureLogged = true
            Diagnostics.log(.storeFailure(detail))
        }
    }

    // MARK: migrations (§3.3, D-22)

    /// Forward migrations, each applied as `BEGIN IMMEDIATE … statements … version bump … COMMIT`.
    static let migrations: [[String]] = [
        // 0 → 1: C-03 index
        [
            """
            CREATE TABLE IF NOT EXISTS articles (id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE, filename TEXT NOT NULL,
                content TEXT NOT NULL DEFAULT '', indexed_at INTEGER NOT NULL,
                file_mtime INTEGER NOT NULL DEFAULT 0, file_size INTEGER NOT NULL DEFAULT 0)
            """,
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(filename, content, path UNINDEXED,
                content='articles', content_rowid='id', tokenize='\(FTSQuery.tokenizer)')
            """,
            """
            CREATE TRIGGER IF NOT EXISTS articles_ai AFTER INSERT ON articles BEGIN
                INSERT INTO articles_fts(rowid, filename, content, path) VALUES (new.id, new.filename, new.content, new.path);
            END
            """,
            """
            CREATE TRIGGER IF NOT EXISTS articles_ad AFTER DELETE ON articles BEGIN
                INSERT INTO articles_fts(articles_fts, rowid, filename, content, path) VALUES ('delete', old.id, old.filename, old.content, old.path);
            END
            """,
            """
            CREATE TRIGGER IF NOT EXISTS articles_au AFTER UPDATE ON articles BEGIN
                INSERT INTO articles_fts(articles_fts, rowid, filename, content, path) VALUES ('delete', old.id, old.filename, old.content, old.path);
                INSERT INTO articles_fts(rowid, filename, content, path) VALUES (new.id, new.filename, new.content, new.path);
            END
            """,
        ],
        // 1 → 2: bookmarks
        [
            """
            CREATE TABLE IF NOT EXISTS bookmarks (id INTEGER PRIMARY KEY, path TEXT NOT NULL, title TEXT NOT NULL,
                sort_order INTEGER NOT NULL, created_at INTEGER NOT NULL)
            """,
        ],
        // 2 → 3: scroll positions; bookmark anchors (C-08)
        [
            """
            CREATE TABLE IF NOT EXISTS scroll_positions (path TEXT PRIMARY KEY, block_index INTEGER NOT NULL,
                block_fingerprint TEXT NOT NULL, updated_at INTEGER NOT NULL)
            """,
            "ALTER TABLE bookmarks ADD COLUMN block_index INTEGER NOT NULL DEFAULT 0",
            "ALTER TABLE bookmarks ADD COLUMN block_fingerprint TEXT NOT NULL DEFAULT ''",
        ],
        // 3 → 4: scroll-position mtime gate (E-08)
        [
            "ALTER TABLE scroll_positions ADD COLUMN file_mtime INTEGER NOT NULL DEFAULT 0",
        ],
    ]

    private func migrate() {
        var version = schemaVersion
        while version < Database.schemaVersion {
            let index = version
            guard exec("BEGIN IMMEDIATE") != nil else { return }
            var error: String? = nil
            for (i, statement) in Database.migrations[index].enumerated() {
                if let e = tryExec(statement) { error = e; break }
                if i == 0, Database.migrationFaultInjection == index, let e = tryExec("INSERT INTO no_such_table_for_fault VALUES (1)") { error = e; break }
            }
            if error == nil, let e = tryExec("INSERT INTO meta(key, value) VALUES ('schema_version', '\(index + 1)') ON CONFLICT(key) DO UPDATE SET value = excluded.value") { error = e }
            if error == nil, let e = tryExec("COMMIT") { error = e }
            if let error {
                // §3.3: rolled back — the previous schema and version stay intact; logged (E-12); the next launch retries.
                _ = tryExec("ROLLBACK")
                Diagnostics.log(.storeFailure("migration to schema \(index + 1) failed and was rolled back: \(error)"))
                failureLogged = true
                isAvailable = version >= 1            // a pre-migration schema (if any) stays usable
                return
            }
            version = index + 1
        }
    }

    /// Runs one statement and returns the SQLite message on failure (no logging, no state change).
    private func tryExec(_ sql: String) -> String? {
        guard let h = handle else { return "closed" }
        var err: UnsafeMutablePointer<CChar>? = nil
        if sqlite3_exec(h, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(err)
            return msg
        }
        return nil
    }

    /// The stored `meta.schema_version` (0 when absent).
    public var schemaVersion: Int {
        guard let s = scalarString("SELECT value FROM meta WHERE key = 'schema_version'") else { return 0 }
        return Int(s) ?? 0
    }

    // MARK: C-03 index and search

    /// I-007: whole-row upsert.
    public func indexFile(path: String, content: String, mtime: Int, size: Int) {
        let filename = (path as NSString).lastPathComponent
        let now = Int(Date().timeIntervalSince1970)
        run("""
            INSERT INTO articles(path, filename, content, indexed_at, file_mtime, file_size) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET filename = excluded.filename, content = excluded.content,
                indexed_at = excluded.indexed_at, file_mtime = excluded.file_mtime, file_size = excluded.file_size
            """, [.text(path), .text(filename), .text(content), .int(now), .int(mtime), .int(size)])
    }

    public func indexedMtime(path: String) -> Int? {
        query("SELECT file_mtime FROM articles WHERE path = ?", [.text(path)]) { Int(sqlite3_column_int64($0, 0)) }.first
    }

    public func indexedPaths() -> [String] {
        query("SELECT path FROM articles ORDER BY path", []) { String(cString: sqlite3_column_text($0, 0)) }
    }

    /// R-26: the index row and the C-08 scroll position go; bookmarks are kept.
    public func removeFile(path: String) {
        run("DELETE FROM articles WHERE path = ?", [.text(path)])
        run("DELETE FROM scroll_positions WHERE path = ?", [.text(path)])
    }

    /// R-26 (launch): drop every index row whose path is not in history.
    public func prune(keeping paths: Set<String>) {
        for p in indexedPaths() where !paths.contains(p) {
            run("DELETE FROM articles WHERE path = ?", [.text(p)])
        }
    }

    public struct SearchHit: Equatable {
        public let path: String
        public let filename: String
        /// U+0002/U+0003 bracket the matched terms (C-03).
        public let snippet: String
    }

    /// C-03: `FTSQuery.make` → nil performs no search (E-24); `ORDER BY rank ASC, path COLLATE NOCASE ASC, path ASC LIMIT 80`;
    /// `snippet(articles_fts, 1, char(2), char(3), '…', 14)`.
    public func search(_ input: String) -> [SearchHit] {
        guard let match = FTSQuery.make(input) else { return [] }
        let sql = """
            SELECT path, filename, snippet(articles_fts, 1, char(2), char(3), '…', \(FTSQuery.snippetTokens))
            FROM articles_fts WHERE articles_fts MATCH ? \(FTSQuery.orderBy) LIMIT \(FTSQuery.limit)
            """
        return query(sql, [.text(match)]) {
            SearchHit(path: String(cString: sqlite3_column_text($0, 0)),
                      filename: String(cString: sqlite3_column_text($0, 1)),
                      snippet: String(cString: sqlite3_column_text($0, 2)))
        }
    }

    // MARK: C-08 bookmarks

    public struct BookmarkRow: Equatable, Identifiable, Sendable {
        public let id: Int64
        public let path: String
        public let title: String
        public let sortOrder: Int
        public let createdAt: Int
        public let blockIndex: Int
        public let fingerprint: String
    }

    public func bookmarks() -> [BookmarkRow] {
        query("SELECT id, path, title, sort_order, created_at, block_index, block_fingerprint FROM bookmarks ORDER BY sort_order, id", []) {
            BookmarkRow(id: sqlite3_column_int64($0, 0), path: String(cString: sqlite3_column_text($0, 1)),
                        title: String(cString: sqlite3_column_text($0, 2)), sortOrder: Int(sqlite3_column_int64($0, 3)),
                        createdAt: Int(sqlite3_column_int64($0, 4)), blockIndex: Int(sqlite3_column_int64($0, 5)),
                        fingerprint: String(cString: sqlite3_column_text($0, 6)))
        }
    }

    /// I-007: one INSERT carrying every column; the new row's sort_order is one past the current maximum.
    public func addBookmark(path: String, title: String, blockIndex: Int, fingerprint: String) -> BookmarkRow? {
        guard isAvailable else { return nil }
        let now = Int(Date().timeIntervalSince1970)
        guard run("""
            INSERT INTO bookmarks(path, title, sort_order, created_at, block_index, block_fingerprint)
            VALUES (?, ?, (SELECT COALESCE(MAX(sort_order) + 1, 0) FROM bookmarks), ?, ?, ?)
            """, [.text(path), .text(title), .int(now), .int(blockIndex), .text(fingerprint)]) else { return nil }
        let id = sqlite3_last_insert_rowid(handle)
        return bookmarks().first { $0.id == id }
    }

    public func removeBookmark(id: Int64) {
        run("DELETE FROM bookmarks WHERE id = ?", [.int64(id)])
    }

    /// R-27: the persisted order becomes `ids` (position = sort_order), in one transaction.
    public func reorderBookmarks(ids: [Int64]) {
        guard isAvailable, exec("BEGIN IMMEDIATE") != nil else { return }
        for (i, id) in ids.enumerated() {
            if !run("UPDATE bookmarks SET sort_order = ? WHERE id = ?", [.int(i), .int64(id)]) { _ = execQuietly("ROLLBACK"); return }
        }
        _ = exec("COMMIT")
    }

    // MARK: C-08 scroll positions

    public struct ScrollRow: Equatable, Sendable {
        public let blockIndex: Int
        public let fingerprint: String
        public let fileMtime: Int
    }

    public func scrollPosition(path: String) -> ScrollRow? {
        query("SELECT block_index, block_fingerprint, file_mtime FROM scroll_positions WHERE path = ?", [.text(path)]) {
            ScrollRow(blockIndex: Int(sqlite3_column_int64($0, 0)), fingerprint: String(cString: sqlite3_column_text($0, 1)),
                      fileMtime: Int(sqlite3_column_int64($0, 2)))
        }.first
    }

    /// I-007: whole-row upsert.
    public func saveScrollPosition(path: String, blockIndex: Int, fingerprint: String, fileMtime: Int) {
        let now = Int(Date().timeIntervalSince1970)
        run("""
            INSERT INTO scroll_positions(path, block_index, block_fingerprint, updated_at, file_mtime) VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET block_index = excluded.block_index, block_fingerprint = excluded.block_fingerprint,
                updated_at = excluded.updated_at, file_mtime = excluded.file_mtime
            """, [.text(path), .int(blockIndex), .text(fingerprint), .int(now), .int(fileMtime)])
    }

    public func removeScrollPosition(path: String) {
        run("DELETE FROM scroll_positions WHERE path = ?", [.text(path)])
    }

    public func scrollRowCount() -> Int {
        query("SELECT COUNT(*) FROM scroll_positions", []) { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
    }

    // MARK: introspection

    public func pragma(_ name: String) -> String? { scalarString("PRAGMA \(name)") }

    public func tableNames() -> [String] {
        query("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name", []) { String(cString: sqlite3_column_text($0, 0)) }
    }

    // MARK: SQLite plumbing

    enum Value { case text(String), int(Int), int64(Int64) }

    private func scalarString(_ sql: String) -> String? {
        query(sql, []) { sqlite3_column_text($0, 0).map { String(cString: $0) } ?? "" }.first
    }

    /// Runs a statement without bindings; nil on failure (logged once, E-12).
    @discardableResult
    private func exec(_ sql: String) -> Bool? {
        guard isAvailable, let h = handle else { return nil }
        var err: UnsafeMutablePointer<CChar>? = nil
        if sqlite3_exec(h, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(err)
            fail("statement failed: \(msg)")
            return nil
        }
        return true
    }

    private func execQuietly(_ sql: String) -> Bool { tryExec(sql) == nil }

    @discardableResult
    private func run(_ sql: String, _ values: [Value]) -> Bool {
        guard isAvailable, let h = handle else { return false }
        var stmt: OpaquePointer? = nil
        guard sqlite3_prepare_v2(h, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            fail("statement failed: \(String(cString: sqlite3_errmsg(h)))"); return false
        }
        defer { sqlite3_finalize(stmt) }
        bind(values, to: stmt)
        let rc = sqlite3_step(stmt)
        if rc != SQLITE_DONE && rc != SQLITE_ROW {
            fail("statement failed: \(String(cString: sqlite3_errmsg(h)))"); return false
        }
        return true
    }

    private func query<T>(_ sql: String, _ values: [Value], _ row: (OpaquePointer) -> T) -> [T] {
        guard isAvailable, let h = handle else { return [] }
        var stmt: OpaquePointer? = nil
        guard sqlite3_prepare_v2(h, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            fail("statement failed: \(String(cString: sqlite3_errmsg(h)))"); return []
        }
        defer { sqlite3_finalize(stmt) }
        bind(values, to: stmt)
        var out: [T] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW { out.append(row(stmt)); continue }
            if rc != SQLITE_DONE { fail("statement failed: \(String(cString: sqlite3_errmsg(h)))") }
            break
        }
        return out
    }

    private func bind(_ values: [Value], to stmt: OpaquePointer) {
        for (i, v) in values.enumerated() {
            let idx = Int32(i + 1)
            switch v {
            case .text(let s): sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT_PTR)
            case .int(let n): sqlite3_bind_int64(stmt, idx, Int64(n))
            case .int64(let n): sqlite3_bind_int64(stmt, idx, n)
            }
        }
    }
}
