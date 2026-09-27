// FrontmatterTableView — C-20.3: a document's metadata header as a two-column properties table (R-44).
import SwiftUI

public struct FrontmatterTableView: View {
    public let rows: [FrontmatterRow]
    public let theme: MDVTheme
    public let zoom: CGFloat
    /// C-21.6: print scales the paddings by s_p; the screen leaves it at 1.
    public var paddingScale: CGFloat = 1

    @State private var keyColumnWidth: CGFloat? = nil

    public init(rows: [FrontmatterRow], theme: MDVTheme, zoom: CGFloat, paddingScale: CGFloat = 1) {
        self.rows = rows; self.theme = theme; self.zoom = zoom; self.paddingScale = paddingScale
    }

    /// C-20.3: the body face at round(baseFontSize × zoom); line spacing round(0.25 × size).
    private var size: CGFloat { (theme.baseFontSize * zoom).rounded() }
    private var vPad: CGFloat { 6 * paddingScale }
    private var hPad: CGFloat { 13 * paddingScale }

    public var body: some View {
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(alignment: .top, spacing: 0) {
                        if let key = row.key {
                            Text(key)
                                .font(ArticleTheme.font(for: theme.bodyFontFamily, size: size, weight: .semibold))
                                .lineSpacing((0.25 * size).rounded())
                                .padding(.horizontal, hPad)
                                .fixedSize()
                                .background(GeometryReader { g in Color.clear.preference(key: KeyColumnWidth.self, value: g.size.width) })
                                .frame(width: keyColumnWidth, alignment: .topLeading)
                                .padding(.vertical, vPad)
                                .modifier(CellBand(fill: fill(i), border: theme.border))
                        }
                        Text(row.value)                                   // plain Text: metadata is data, not Markdown
                            .font(ArticleTheme.font(for: theme.bodyFontFamily, size: size))
                            .lineSpacing((0.25 * size).rounded())
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, vPad).padding(.horizontal, hPad)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .modifier(CellBand(fill: fill(i), border: theme.border))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(theme.text)
            .textSelection(.enabled)                                   // F-158: values selectable as prose
            .onPreferenceChange(KeyColumnWidth.self) { keyColumnWidth = $0 > 0 ? $0 : nil }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// C-20.3: fills alternate background (row 0, 2, …) and secondaryBackground.
    private func fill(_ row: Int) -> Color { row.isMultiple(of: 2) ? theme.background : theme.secondaryBackground }
}

/// The widest key at its natural, unwrapped, padded width (C-20.3).
private struct KeyColumnWidth: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// A cell's fill and 1 pt border stretched to its row's height, so a wrapped value never leaves its key a short band.
private struct CellBand: ViewModifier {
    let fill: Color
    let border: Color
    func body(content: Content) -> some View {
        content.frame(maxHeight: .infinity, alignment: .topLeading).background(fill).overlay(Rectangle().strokeBorder(border, lineWidth: 1))
    }
}
