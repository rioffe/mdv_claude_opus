// FindBlockStyle — C-09.1: the typography of a block on the find inline-highlight path (R-24).
import CoreGraphics

public struct FindBlockStyle: Equatable, Sendable {
    public enum ColorRole: Equatable, Sendable { case text, heading, tertiaryText }
    public enum WeightRole: Equatable, Sendable { case regular, heading }

    public let level: Int?                // ATX level 1…6, nil for body text
    public let size: CGFloat              // round(baseFontSize × zoom × e)
    public let colorRole: ColorRole
    public let weight: WeightRole
    public let lineSpacing: CGFloat       // 0.125 em for headings, paragraphLineSpacingEm for body
    public let bottomPadding: CGFloat     // 0.3 × size under h1/h2
    public let rule: Bool                 // the h1/h2 divider when the theme shows it
    public let codeSize: CGFloat          // inline code: round(0.90 × size)

    /// C-09.1: ℓ = the count of leading `#` (1–6) when followed by a space after trimming; else body text.
    public static func level(of block: String) -> Int? {
        let t = block.drop(while: { $0 == " " || $0 == "\t" })
        let hashes = t.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), t.dropFirst(hashes).first == " " else { return nil }
        return hashes
    }

    public static func style(forBlock block: String, theme: MDVTheme, zoom: CGFloat) -> FindBlockStyle {
        let l = level(of: block)
        let e: CGFloat = l.map { theme.headingSizeEms[$0 - 1] } ?? 1
        let size = (theme.baseFontSize * zoom * e).rounded()
        let isHeading = l != nil
        return FindBlockStyle(
            level: l,
            size: size,
            colorRole: l == 6 ? .tertiaryText : (isHeading ? .heading : .text),
            weight: isHeading ? .heading : .regular,
            lineSpacing: size * (isHeading ? 0.125 : theme.paragraphLineSpacingEm),
            bottomPadding: (l == 1 || l == 2) ? size * 0.3 : 0,
            rule: l == 1 ? theme.showH1Rule : (l == 2 ? theme.showH2Rule : false),
            codeSize: (size * 0.90).rounded())
    }
}
