// PlaceholderStore — R-28: the transient, in-memory placeholder (never persisted, never survives relaunch).
import Foundation

public struct Placeholder: Equatable, Sendable {
    public let path: String
    public let blockIndex: Int
    public let fingerprint: String
    public let title: String

    public init(path: String, blockIndex: Int, fingerprint: String, title: String) {
        self.path = path; self.blockIndex = blockIndex; self.fingerprint = fingerprint; self.title = title
    }
}

public final class PlaceholderStore: ObservableObject {
    @Published public private(set) var placeholder: Placeholder?

    public init() {}

    /// ⌘⇧0 (R-28): replaces any earlier placeholder.
    public func set(_ p: Placeholder) { placeholder = p }
    /// *Clear Placeholder* (R-28, C-18.9).
    public func clear() { placeholder = nil }
}
