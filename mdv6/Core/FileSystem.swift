// FileSystem — the file operations the services and the session need, injectable so tests never touch the disk
// (R-04 read/decode, R-26 mtime gate, E-09 existence).
import Foundation

public final class FileSystem {
    public enum ReadError: Error, Equatable { case missing, unreadable, notUTF8, tooLarge }

    public var exists: (String) -> Bool
    public var isDirectory: (String) -> Bool
    /// Whole seconds (K-06), nil when the file is missing.
    public var mtimeSeconds: (String) -> Int?
    public var byteCount: (String) -> Int?
    /// R-04: the bytes as UTF-8, strictly decoded; `tooLarge` when over the K-14 document ceiling (checked before decoding, R-41).
    public var readUTF8: (String) throws -> String
    public var directoryContents: (String) -> [String]

    public init(exists: @escaping (String) -> Bool, isDirectory: @escaping (String) -> Bool, mtimeSeconds: @escaping (String) -> Int?,
                byteCount: @escaping (String) -> Int?, readUTF8: @escaping (String) throws -> String,
                directoryContents: @escaping (String) -> [String]) {
        self.exists = exists; self.isDirectory = isDirectory; self.mtimeSeconds = mtimeSeconds
        self.byteCount = byteCount; self.readUTF8 = readUTF8; self.directoryContents = directoryContents
    }

    /// The real disk.
    public static let live = FileSystem(
        exists: { FileManager.default.fileExists(atPath: $0) },
        isDirectory: { var d: ObjCBool = false; return FileManager.default.fileExists(atPath: $0, isDirectory: &d) && d.boolValue },
        mtimeSeconds: { path in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path), let date = attrs[.modificationDate] as? Date else { return nil }
            return Int(date.timeIntervalSince1970.rounded(.down))
        },
        byteCount: { path in (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int },
        readUTF8: { path in
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { throw ReadError.missing }
            if let size = attrs[.size] as? Int, !ContentLimits.admits(size, kind: .document) { throw ReadError.tooLarge }
            guard let data = FileManager.default.contents(atPath: path) else { throw ReadError.unreadable }
            if !ContentLimits.admits(data.count, kind: .document) { throw ReadError.tooLarge }
            guard let text = String(data: data, encoding: .utf8) else { throw ReadError.notUTF8 }
            return text
        },
        directoryContents: { (try? FileManager.default.contentsOfDirectory(atPath: $0)) ?? [] }
    )

    // MARK: fake (tests)

    /// A fake keyed by absolute path; edit `contents`/`mtimes` between calls.
    public final class Fake {
        public var contents: [String: String]
        public var mtimes: [String: Int]
        public var directories: Set<String> = []
        public init(contents: [String: String], mtime: Int) {
            self.contents = contents
            self.mtimes = contents.mapValues { _ in mtime }
        }
    }

    public var contents: [String: String] {
        get { fake?.contents ?? [:] }
        set { fake?.contents = newValue }
    }
    public var mtimes: [String: Int] {
        get { fake?.mtimes ?? [:] }
        set { fake?.mtimes = newValue }
    }
    private var fake: Fake?

    public static func fake(files: [String: String], mtime: Int) -> FileSystem {
        let f = Fake(contents: files, mtime: mtime)
        let fs = FileSystem(
            exists: { f.contents[$0] != nil || f.directories.contains($0) },
            isDirectory: { f.directories.contains($0) },
            mtimeSeconds: { f.contents[$0] == nil ? nil : (f.mtimes[$0] ?? 0) },
            byteCount: { f.contents[$0]?.utf8.count },
            readUTF8: { path in
                guard let s = f.contents[path] else { throw ReadError.missing }
                if !ContentLimits.admits(s.utf8.count, kind: .document) { throw ReadError.tooLarge }
                return s
            },
            directoryContents: { dir in
                let prefix = dir.hasSuffix("/") ? dir : dir + "/"
                return f.contents.keys.filter { $0.hasPrefix(prefix) && !$0.dropFirst(prefix.count).contains("/") }
                    .map { String($0.dropFirst(prefix.count)) }
            })
        fs.fake = f
        return fs
    }
}
