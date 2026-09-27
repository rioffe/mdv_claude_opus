// ScrollKeys — K-18 keyboard-scroll steps (R-49) and the R-48 history step, as pure functions. The event monitors
// that use them are added by W12.
import CoreGraphics

public enum ScrollKey: Equatable, Sendable { case down, up, pageDown, pageUp, space, home, end }

public enum ScrollKeys {
    /// K-18: arrow step in points.
    public static let lineStep: CGFloat = 40
    /// K-18: fraction of the usable height a page key moves.
    public static let pageFraction: CGFloat = 0.875
    /// K-18: *End* re-aims at the bottom every 1/60 s at most this many times.
    public static let endRetries = 10

    /// R-49: ↓ 125, ↑ 126, PgDn 121, PgUp 116, Space 49 (⇧Space = page up), Home 115, End 119; others pass through.
    public static func key(keyCode: UInt16, shift: Bool) -> ScrollKey? {
        switch (keyCode, shift) {
        case (125, false): return .down
        case (126, false): return .up
        case (121, false): return .pageDown
        case (116, false): return .pageUp
        case (49, false): return .space
        case (49, true): return .pageUp
        case (115, false): return .home
        case (119, false): return .end
        default: return nil
        }
    }

    /// K-18: the proposed clip origin; the scroll view clamps it (Home/End aim past the ends so the clamp lands on them).
    public static func target(_ key: ScrollKey, y: CGFloat, usable: CGFloat, documentHeight: CGFloat) -> CGFloat {
        let page = max(usable * pageFraction, lineStep)
        let beyond = documentHeight + max(usable, 0) + 1
        switch key {
        case .down: return y + lineStep
        case .up: return y - lineStep
        case .pageDown, .space: return y + page
        case .pageUp: return y - page
        case .home: return -beyond
        case .end: return beyond
        }
    }
}

public enum HistoryStep {
    /// R-48: the row `offset` away from `current`, or nil at the ends (no wrap) or with nothing displayed.
    public static func target(current: Int?, offset: Int, count: Int) -> Int? {
        guard let current else { return nil }
        let t = current + offset
        return (0 ..< count).contains(t) ? t : nil
    }
}
