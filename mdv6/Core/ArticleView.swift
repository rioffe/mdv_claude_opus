// ArticleView — the article pane: one `ArticleBlockView` per C-02 block along the §3.2 pipeline (math rewrite →
// smart typography → MarkdownUI; fences → code/Mermaid chrome), with the I-014 / C-18.10 rhythm re-applied at block
// boundaries, the R-24 find tint / inline highlight, the R-22 heading-click affordance, the C-18.7 hovered-block stripe
// and the section flash. `ArticleHost` is what the view reads (the session in the app, a static host in the harness).
import SwiftUI
import AppKit
import MarkdownUI

/// What the article reads from its owner (R-42 rhythm inputs, R-24 find, R-22 copy, R-27/R-28 hover anchor).
@MainActor
public protocol ArticleHost: ObservableObject {
    var document: ParsedDocument? { get }
    var theme: MDVTheme { get }
    var zoom: CGFloat { get }
    var smartTypography: Bool { get }
    var loadRemoteImages: Bool { get }
    var mermaidStyle: MermaidStyle { get }
    var findState: FindState? { get }
    var flashedRange: Range<Int>? { get }
    var hoveredBlockIndex: Int? { get }
    var baseURL: URL? { get }
    /// E-25: bumped on every document change so in-flight renders are cancelled.
    var renderGeneration: Int { get }
    var backingScale: CGFloat { get }
    var remoteLoader: RemoteImageLoader? { get }
    /// R-44 / C-04 `mdv6_show_frontmatter`: whether block 0's header draws its table.
    var showFrontmatter: Bool { get }
    /// Inline images resolved up front for renderers that run no `.task` (the offscreen harness, print — I-016); the
    /// window returns none and loads through the inline provider.
    var resolvesInlineImagesUpFront: Bool { get }
    func copySection(at index: Int)
    func hoverChanged(_ index: Int?)
    func linkClicked(_ url: URL)
    func revealRemoteImageSetting()
    func setMermaidStyle(_ style: MermaidStyle)
}

/// The kind of a C-02 block as the rhythm rule sees it.
public enum BlockKind: Equatable {
    case heading(Int)
    case codeFence
    case mermaidFence
    case thematicBreak
    case other

    public init(block: String) {
        if ParsedDocument.isFence(block) {
            let info = FenceParts(block: block).infoString?.lowercased().split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
            self = info == "mermaid" ? .mermaidFence : .codeFence
        } else if let level = MathMarkdown.headingLevel(of: block) {
            self = .heading(level)
        } else if isThematicBreak(block) {
            self = .thematicBreak
        } else {
            self = .other
        }
    }
}

public struct ArticleBlockView<H: ArticleHost>: View {
    public let index: Int
    public let block: String
    @ObservedObject public var host: H
    public let columnWidth: CGFloat
    public let previous: String?

    public init(index: Int, block: String, host: H, columnWidth: CGFloat, previous: String?) {
        self.index = index; self.block = block; self.host = host; self.columnWidth = columnWidth; self.previous = previous
    }

    // MARK: I-014 / C-18.10

    /// The `TYPOGRAPHY.md` margins MarkdownUI would apply between siblings: (top, bottom) for a block kind.
    public static func margins(theme t: MDVTheme, kind: BlockKind) -> (top: CGFloat, bottom: CGFloat) {
        switch kind {
        case .heading(1): return (t.h1TopSpacing, t.h1BottomSpacing)
        case .heading(2): return (t.h2TopSpacing, t.h2BottomSpacing)
        case .heading: return (t.h3TopSpacing, t.h3BottomSpacing)
        case .thematicBreak: return (24, 24)
        case .codeFence, .mermaidFence, .other: return (0, t.paragraphBottomSpacing)
        }
    }

    /// C-18.10: the inset applied above `current` when it follows `previous` — `max(bottom_prev, top_current)` as
    /// MarkdownUI combines sibling margins; 0 for the first block.
    public static func blockInset(theme: MDVTheme, previous: String?, current: String) -> CGFloat {
        guard let previous else { return 0 }
        let prev = margins(theme: theme, kind: BlockKind(block: previous))
        let cur = margins(theme: theme, kind: BlockKind(block: current))
        return max(prev.bottom, cur.top)
    }

    // MARK: body

    private var theme: MDVTheme { host.theme }
    private var kind: BlockKind { BlockKind(block: block) }
    private var isTOCHeading: Bool { host.document?.tocHeadings.contains { $0.blockIndex == index } ?? false }
    private var tint: FindTint { host.findState?.tint(for: index) ?? .none }
    private var flashed: Bool { host.flashedRange?.contains(index) ?? false }
    private var striped: Bool { host.hoveredBlockIndex == index && kind != .codeFence && kind != .mermaidFence }
    /// C-02 rule 9: block 0 is a frontmatter header.
    private var isHeader: Bool { index == 0 && host.document?.frontmatter != nil }
    /// R-44: a hidden header draws nothing and takes no height, padding or spacing — unless find shows it (R-24).
    private var hiddenHeader: Bool { isHeader && !host.showFrontmatter && tint == .none }

    public var body: some View {
        if hiddenHeader { EmptyView() } else { styled }
    }

    private var styled: some View {
        content
            .padding(.horizontal, ColumnWidth.blockPadding)
            .padding(.top, Self.blockInset(theme: theme, previous: previous, current: block))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .leading) {                                           // C-18.7 precedence: tint beneath
                if tint != .none { theme.accent.opacity(tint == .strong ? 0.25 : 0.12) }
            }
            .overlay(alignment: .leading) {                                              // stripe in the padding beside the block
                if striped { Rectangle().fill(theme.accent).frame(width: ChromeMetrics.stripeWidth) }
            }
            .overlay { if flashed { theme.accent.opacity(0.18).allowsHitTesting(false) } }   // flash above
            .onHover { inside in host.hoverChanged(inside ? index : (host.hoveredBlockIndex == index ? nil : host.hoveredBlockIndex)) }
    }

    @ViewBuilder private var content: some View {
        if isHeader, tint == .none, let rows = host.document?.frontmatter {
            FrontmatterTableView(rows: rows, theme: theme, zoom: host.zoom)            // C-20.3
        } else {
            nonHeaderContent
        }
    }

    @ViewBuilder private var nonHeaderContent: some View {
        switch kind {
        case .codeFence:
            CodeBlockChrome(parts: FenceParts(block: block), theme: theme, zoom: host.zoom)
        case .mermaidFence:
            MermaidCodeBlockChrome(source: FenceParts(block: block).code, documentTheme: theme, style: host.mermaidStyle,
                                   columnWidth: columnWidth, backingScale: host.backingScale, generation: host.renderGeneration) { host.setMermaidStyle($0) }
        default:
            prose
        }
    }

    @ViewBuilder private var prose: some View {
        if let find = host.findState, tint != .none, FindHighlight.mode(block: block, isHeader: isHeader) != .tint {
            // R-24: the matching block as inline text with every occurrence marked (E-17), in the block's own
            // typography (C-09.1); a header verbatim, fence lines included (F-159, F-179)
            let style = FindBlockStyle.style(forBlock: isHeader ? "" : block, theme: theme, zoom: host.zoom)
            let text = isHeader
                ? FindHighlight.verbatimAttributedString(block: block, query: find.query, theme: theme)
                : FindHighlight.styled(FindHighlight.highlightedAttributedString(block: block, query: find.query, theme: theme), style: style, theme: theme)
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .font(ArticleTheme.font(for: theme.bodyFontFamily, size: style.size, weight: style.weight == .heading ? theme.headingFontWeight : .regular))
                    .foregroundStyle(FindHighlight.color(style.colorRole, theme))
                    .lineSpacing(style.lineSpacing)
                    .padding(.bottom, style.bottomPadding)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if style.rule { Divider().overlay(theme.divider) }
            }
        } else {
            let markdown = Markdown(rendered, baseURL: host.baseURL)
                .markdownTheme(ArticleTheme.markdownTheme(for: theme, zoom: host.zoom))
                .markdownImageProvider(ArticleImageProvider(theme: theme, scale: host.backingScale, baseURL: host.baseURL,
                                                            loadRemote: host.loadRemoteImages, remoteLoader: host.remoteLoader,
                                                            onRevealRemoteSetting: { host.revealRemoteImageSetting() }))
                .markdownInlineImageProvider(inlineProvider)
                .markdownCodeSyntaxHighlighter(ArticleCodeHighlighter(theme: theme, zoom: host.zoom))
                .markdownResolvedInlineImages(host.resolvesInlineImagesUpFront ? inlineProvider.resolvedImages(markdown: rendered) : [:])
                .environment(\.openURL, OpenURLAction { url in host.linkClicked(url); return .handled })
            if isTOCHeading {
                // R-22: not text-selectable, pointing hand, a click copies the section (modifier keys not distinguished)
                Button { host.copySection(at: index) } label: {                      // F-007: a Button takes the activating click too
                    markdown.textSelection(.disabled).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            } else {
                markdown.textSelection(.enabled)
            }
        }
    }

    private var inlineProvider: ArticleInlineImageProvider {
        ArticleInlineImageProvider(theme: theme, scale: host.backingScale, baseURL: host.baseURL,
                                   loadRemote: host.loadRemoteImages, remoteLoader: host.remoteLoader)
    }

    /// §3.2: `<img>` rewriting (C-22) precedes math rewriting, which precedes smart typography (R-17).
    private var rendered: String {
        let size = theme.baseFontSize * host.zoom
        var text = MathMarkdown.rewrite(RawHTMLImages.rewrite(block), fontSize: size, headingSizeEms: theme.headingSizeEms, color: theme.rgba.text)
        if host.smartTypography && theme.smartTypographyAllowed { text = smartenMarkdown(text) }
        return text
    }
}

/// MarkdownUI's code highlighter for fences that reach a `Markdown` view (single-view rendering, blockquoted fences).
public struct ArticleCodeHighlighter: CodeSyntaxHighlighter {
    public let theme: MDVTheme
    public let zoom: CGFloat
    public func highlightCode(_ code: String, language: String?) -> Text {
        Text(CodeRenderer.shared.render(code: code, languageHint: language, theme: theme, zoom: zoom))
    }
}

/// The column of blocks. `lazy` is the window's `LazyVStack`; the harness renders every block (`lazy == false`).
public struct ArticleBlocksView<H: ArticleHost>: View {
    @ObservedObject public var host: H
    public let columnWidth: CGFloat
    public let lazy: Bool

    public init(host: H, columnWidth: CGFloat, lazy: Bool) { self.host = host; self.columnWidth = columnWidth; self.lazy = lazy }

    public var body: some View {
        let blocks = host.document?.blocks ?? []
        if lazy {
            LazyVStack(alignment: .leading, spacing: 0) { rows(blocks) }
        } else {
            VStack(alignment: .leading, spacing: 0) { rows(blocks) }
        }
    }

    /// C-18.10's previous block, except that a hidden header counts as absent (R-44, I-018: the body starts where it would
    /// without one).
    private func previous(_ i: Int, _ blocks: [String]) -> String? {
        guard i > 0 else { return nil }
        if i == 1, host.document?.frontmatter != nil, !host.showFrontmatter { return nil }
        return blocks[i - 1]
    }

    @ViewBuilder private func rows(_ blocks: [String]) -> some View {
        ForEach(Array(blocks.enumerated()), id: \.offset) { i, block in
            ArticleBlockView(index: i, block: block, host: host, columnWidth: columnWidth, previous: previous(i, blocks))
                .id(i)
                .background(GeometryReader { g in                       // R-27 / R-06: which block is topmost in the viewport
                    Color.clear.preference(key: ArticleScroller.BlockFramesKey.self, value: [ArticleScroller.BlockFrame(index: i, minY: g.frame(in: .named("article")).minY)])
                })
        }
    }
}

/// The article frame: the theme's max width and horizontal padding (K-10, K-13), the page background.
public struct ArticleView<H: ArticleHost>: View {
    @ObservedObject public var host: H
    public let areaWidth: CGFloat
    public let lazy: Bool

    public init(host: H, areaWidth: CGFloat, lazy: Bool = true) { self.host = host; self.areaWidth = areaWidth; self.lazy = lazy }

    /// §7.2 with no side panes (the window subtracts them before passing `areaWidth`).
    public var columnWidth: CGFloat {
        ColumnWidth.column(area: areaWidth, sidebar: 0, inspector: 0, maxWidth: host.theme.articleMaxWidth, padding: host.theme.articleHorizontalPadding)
    }

    public var body: some View {
        ArticleBlocksView(host: host, columnWidth: columnWidth, lazy: lazy)
            .padding(.horizontal, host.theme.articleHorizontalPadding)
            .frame(maxWidth: host.theme.articleMaxWidth)
            .frame(maxWidth: .infinity)
            .background(host.theme.background)
    }
}
