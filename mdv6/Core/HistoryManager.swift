// HistoryManager — C-15 history entries and their JSON codec (W1); the manager itself lands in W2 (R-20, R-26, I-013).
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
