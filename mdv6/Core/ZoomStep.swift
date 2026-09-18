// ZoomStep — the R-30 zoom formula (K-04, D-37): s' = clamp(roundHalfAway(10s)/10 + d, 0.60, 2.50).
import Foundation

public enum ZoomStep {
    public static let step = 0.10
    public static let minimum = 0.60
    public static let maximum = 2.50
    public static let `default` = 1.0
    /// K-06: the zoom HUD stays for 0.9 s.
    public static let hudDuration: TimeInterval = 0.9

    /// R-30: `roundHalfAway` rounds a half-integer away from zero (`Foundation.round` does).
    public static func apply(stored s: Double, delta d: Double) -> Double {
        let rounded = (10 * s).rounded(.toNearestOrAwayFromZero) / 10
        return clampOnRead(rounded + d)
    }

    /// C-04: `mdv6_font_scale` is clamped on read.
    public static func clampOnRead(_ s: Double) -> Double {
        guard s.isFinite else { return `default` }
        return min(max(s, minimum), maximum)
    }

    /// R-30: the HUD shows ⌊100 s' + 0.5⌋ %.
    public static func hudPercent(_ s: Double) -> Int { Int((100 * s + 0.5).rounded(.down)) }
}
