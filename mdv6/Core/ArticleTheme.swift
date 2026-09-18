// ArticleTheme — R-07 / C-09: the MarkdownUI theme built from an `MDVTheme` at a zoom factor (R-30), carrying the
// `TYPOGRAPHY.md` spacings as MarkdownUI margins so a single `Markdown` view is the I-014 rhythm oracle.
import SwiftUI
import MarkdownUI

public enum ArticleTheme {
    public static func font(for family: FontFamily, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch family {
        case .system: return .system(size: size, weight: weight)
        case .custom(let name): return .custom(name, size: size).weight(weight)
        }
    }

    /// C-09 → MarkdownUI: body at `baseFontSize × zoom`, headings by `headingSizeEms`, the theme's colours, the
    /// `TYPOGRAPHY.md` per-element spacing as margins, H1/H2 rules, monospace code on the secondary background.
    public static func markdownTheme(for t: MDVTheme, zoom: CGFloat) -> Theme {
        let base = t.baseFontSize * zoom
        func heading(_ level: Int, _ c: BlockConfiguration) -> AnyView {
            let em = t.headingSizeEms[level - 1]
            let (top, bottom): (CGFloat, CGFloat) = {
                switch level {
                case 1: return (t.h1TopSpacing, t.h1BottomSpacing)
                case 2: return (t.h2TopSpacing, t.h2BottomSpacing)
                case 3: return (t.h3TopSpacing, t.h3BottomSpacing)
                default: return (t.h3TopSpacing, t.h3BottomSpacing)
                }
            }()
            let rule = (level == 1 && t.showH1Rule) || (level == 2 && t.showH2Rule)
            let label = c.label
                .relativeLineSpacing(.em(0.125))
                .markdownTextStyle {
                    FontWeight(t.headingFontWeight)
                    FontSize(.em(em))
                    ForegroundColor(level == 6 ? t.tertiaryText : t.heading)
                }
            if rule {
                return AnyView(VStack(alignment: .leading, spacing: 0) {
                    label.relativePadding(.bottom, length: .em(0.3))
                    Divider().overlay(t.divider)                        // C-18.7: a full-column rule in the divider colour
                }.markdownMargin(top: top, bottom: bottom))
            }
            return AnyView(label.markdownMargin(top: top, bottom: bottom))
        }
        var theme = Theme()
            .text {
                ForegroundColor(t.text)
                FontSize(base)
                if case .custom(let name) = t.bodyFontFamily { MarkdownUI.FontFamily(.custom(name)) }
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
                BackgroundColor(t.secondaryBackground)
            }
            .strong { FontWeight(t.strongFontWeight); ForegroundColor(t.strong) }
            .link { ForegroundColor(t.link) }
            .paragraph { c in
                c.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(t.paragraphLineSpacingEm))
                    .markdownMargin(top: 0, bottom: t.paragraphBottomSpacing)
            }
            .blockquote { c in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2).fill(t.blockquoteBar).relativeFrame(width: .em(0.2))
                    c.label.markdownTextStyle { ForegroundColor(t.secondaryText) }.relativePadding(.horizontal, length: .em(1))
                }
                .fixedSize(horizontal: false, vertical: true)
                .markdownMargin(top: 0, bottom: t.paragraphBottomSpacing)
            }
            .codeBlock { c in
                ScrollView(.horizontal) {
                    c.label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.225))
                        .markdownTextStyle { FontFamilyVariant(.monospaced); FontSize(.em(0.85)) }
                        .padding(16)
                }
                .background(t.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .markdownMargin(top: 0, bottom: t.paragraphBottomSpacing)
            }
            .image { c in
                c.label.markdownMargin(top: 0, bottom: t.paragraphBottomSpacing)
            }
            .listItem { c in c.label.markdownMargin(top: .em(0.25)) }
            .taskListMarker { c in
                Image(systemName: c.isCompleted ? "checkmark.square.fill" : "square")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(t.secondaryText, t.secondaryBackground)
                    .imageScale(.small)
                    .relativeFrame(minWidth: .em(1.5), alignment: .trailing)
            }
            .table { c in
                c.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: t.border))
                    .markdownTableBackgroundStyle(.alternatingRows(t.background, t.secondaryBackground))
                    .markdownMargin(top: 0, bottom: t.paragraphBottomSpacing)
            }
            .tableCell { c in
                c.label
                    .markdownTextStyle { if c.row == 0 { FontWeight(.semibold) }; BackgroundColor(nil) }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 6).padding(.horizontal, 13)
                    .relativeLineSpacing(.em(0.25))
            }
            .thematicBreak {
                Divider().relativeFrame(height: .em(0.25)).overlay(t.border).markdownMargin(top: 24, bottom: 24)
            }
        theme = theme.heading1 { heading(1, $0) }.heading2 { heading(2, $0) }.heading3 { heading(3, $0) }
            .heading4 { heading(4, $0) }.heading5 { heading(5, $0) }.heading6 { heading(6, $0) }
        return theme
    }
}
