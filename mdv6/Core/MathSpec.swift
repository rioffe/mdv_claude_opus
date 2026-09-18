// MathSpec — the typesetting request decoded from an `mdv6-math://` URL (C-07.1, C-07.2).
import Foundation

/// An 8-bit RGBA colour carried through the math URL (`c=RRGGBBAA`).
public struct RGBA: Hashable, Sendable {
    public let r: UInt8, g: UInt8, b: UInt8, a: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    /// `RRGGBBAA`, upper-case hex.
    public var hex: String { String(format: "%02X%02X%02X%02X", r, g, b, a) }

    /// Parses `RRGGBBAA` or `RRGGBB` (alpha 255); nil on anything else.
    public init?(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard h.count == 6 || h.count == 8, let v = UInt64(h, radix: 16) else { return nil }
        if h.count == 6 {
            self.init(r: UInt8((v >> 16) & 0xFF), g: UInt8((v >> 8) & 0xFF), b: UInt8(v & 0xFF), a: 255)
        } else {
            self.init(r: UInt8((v >> 24) & 0xFF), g: UInt8((v >> 16) & 0xFF), b: UInt8((v >> 8) & 0xFF), a: UInt8(v & 0xFF))
        }
    }

    public static let black = RGBA(r: 0, g: 0, b: 0)
}

/// C-07.1/C-07.2: what `MathImageCache` typesets. `display` selects `.display` vs `.text` (K-08).
public struct MathSpec: Hashable, Sendable {
    public let latex: String
    public let fontSize: CGFloat
    public let color: RGBA
    public let display: Bool

    public init(latex: String, fontSize: CGFloat, color: RGBA, display: Bool) {
        self.latex = latex
        self.fontSize = fontSize
        self.color = color
        self.display = display
    }
}
