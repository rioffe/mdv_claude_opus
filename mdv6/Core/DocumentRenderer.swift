// DocumentRenderer — C-17 / R-39: renders a Markdown document (through the same `ArticleBlocksView` the window uses, or
// one `Markdown` view as the I-014 oracle) or a raw Mermaid diagram to a bitmap, offscreen, at a width, scale and theme.
import SwiftUI
import AppKit
import MarkdownUI

/// A fixed host for offscreen rendering (I-001: every render input is a parameter).
public final class StaticArticleHost: ArticleHost {
    @Published public var document: ParsedDocument?
    public let theme: MDVTheme
    public let zoom: CGFloat
    public let smartTypography: Bool
    public let loadRemoteImages: Bool = false
    public let mermaidStyle: MermaidStyle
    public let findState: FindState? = nil
    public let flashedRange: Range<Int>? = nil
    public let hoveredBlockIndex: Int? = nil
    public let baseURL: URL?
    public let renderGeneration: Int = 0
    public let backingScale: CGFloat
    public let remoteLoader: RemoteImageLoader? = nil

    public init(document: ParsedDocument?, theme: MDVTheme, zoom: CGFloat, smartTypography: Bool, mermaidStyle: MermaidStyle, baseURL: URL?, backingScale: CGFloat) {
        self.document = document; self.theme = theme; self.zoom = zoom; self.smartTypography = smartTypography
        self.mermaidStyle = mermaidStyle; self.baseURL = baseURL; self.backingScale = backingScale
    }

    public func copySection(at index: Int) {}
    public func hoverChanged(_ index: Int?) {}
    public func linkClicked(_ url: URL) {}
    public func revealRemoteImageSetting() {}
    public func setMermaidStyle(_ style: MermaidStyle) {}
}

public enum RenderOutcome {
    case rendered(NSImage)
    case fallback(reason: String)
}

public struct DocumentRenderer {
    public struct Options {
        public var width: CGFloat = 860
        public var scale: CGFloat = 2
        public var theme: MDVTheme = .highContrast
        /// The I-014 oracle: the whole document in one `Markdown` view (MarkdownUI applies the theme margins between siblings).
        public var singleView = false
        public var smartTypography = true
        public var zoom: CGFloat = 1
        public var mermaidStyle: MermaidStyle = .document
        public var baseURL: URL? = nil
        public init() {}
    }

    public enum RenderError: Error { case emptyLayout, timeout }

    /// Renders through the article views (or the single `Markdown` view) hosted offscreen; waits for inline image loads
    /// (math) and Mermaid layouts to settle so the output is deterministic for identical inputs (C-17).
    @MainActor
    public static func render(markdown: String, options: Options) throws -> NSImage {
        FontRegistration.registerBundledFonts()
        let doc = ParsedDocument(raw: markdown)
        let host = StaticArticleHost(document: doc, theme: options.theme, zoom: options.zoom, smartTypography: options.smartTypography,
                                     mermaidStyle: options.mermaidStyle, baseURL: options.baseURL, backingScale: options.scale)
        let root: AnyView
        if options.singleView {
            let t = options.theme
            let size = t.baseFontSize * options.zoom
            let text = doc.blocks.map { block -> String in
                var s = MathMarkdown.rewrite(block, fontSize: size, headingSizeEms: t.headingSizeEms, color: t.rgba.text)
                if options.smartTypography && t.smartTypographyAllowed { s = smartenMarkdown(s) }
                return s
            }.joined(separator: "\n\n")
            let column = ColumnWidth.column(area: options.width, sidebar: 0, inspector: 0, maxWidth: t.articleMaxWidth, padding: t.articleHorizontalPadding)
            root = AnyView(
                Markdown(text, baseURL: options.baseURL)
                    .markdownTheme(ArticleTheme.markdownTheme(for: t, zoom: options.zoom))
                    .markdownImageProvider(ArticleImageProvider(theme: t, scale: options.scale, baseURL: options.baseURL, loadRemote: false, remoteLoader: nil))
                    .markdownInlineImageProvider(MathInlineImageProvider(scale: options.scale))
                    .markdownCodeSyntaxHighlighter(ArticleCodeHighlighter(theme: t, zoom: options.zoom))
                    .padding(.horizontal, ColumnWidth.blockPadding)
                    .frame(width: column + 2 * ColumnWidth.blockPadding, alignment: .leading)
                    .padding(.horizontal, t.articleHorizontalPadding)
                    .frame(width: options.width, alignment: .center)
                    .background(t.background)
            )
        } else {
            root = AnyView(ArticleView(host: host, areaWidth: options.width, lazy: false).frame(width: options.width))
        }
        return try snapshot(root, width: options.width, scale: options.scale, background: options.theme.rgba.background)
    }

    /// Renders one raw Mermaid diagram at its natural width (bounded by `width − 36`), `.fallback` for E-02/E-28.
    @MainActor
    public static func render(mermaid source: String, options: Options) -> RenderOutcome {
        let theme = MDVMermaidPipeline.theme(for: options.mermaidStyle, document: options.theme)
        do {
            let p = try MDVMermaidPipeline.prepare(source: source, theme: theme)
            let column = ColumnWidth.column(area: options.width, sidebar: 0, inspector: 0, maxWidth: options.theme.articleMaxWidth, padding: options.theme.articleHorizontalPadding)
            let width = ColumnWidth.rasterWidth(natural: p.naturalSize.width, column: column)
            guard let image = MDVMermaidPipeline.rasterize(p, width: width, scale: options.scale) else { return .fallback(reason: "raster failed") }
            return .rendered(image)
        } catch MermaidPrepareError.exceedsLimit {
            return .fallback(reason: ContentLimits.exceededMessage)
        } catch MermaidPrepareError.unsupported(let t) {
            return .fallback(reason: "unsupported diagram type: \(t)")
        } catch {
            return .fallback(reason: "Mermaid diagram could not be rendered")
        }
    }

    /// PNG bytes of a bitmap-backed image.
    public static func png(_ image: NSImage) -> Data? {
        guard let rep = image.representations.first as? NSBitmapImageRep else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: offscreen hosting

    @MainActor
    static func snapshot(_ view: AnyView, width: CGFloat, scale: CGFloat, background: RGBA) throws -> NSImage {
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = [.intrinsicContentSize]
        let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: width, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        // settle: layout, then wait for async inline images (math) and diagram tasks, until the height is stable
        var lastHeight: CGFloat = -1
        var stable = 0
        var iterations = 0
        repeat {
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: max(1, hosting.fittingSize.height))
            hosting.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
            let h = hosting.fittingSize.height
            if abs(h - lastHeight) < 0.5 && PendingImageLoads.pending == 0 { stable += 1 } else { stable = 0 }
            lastHeight = h
            iterations += 1
            if iterations > 400 { throw RenderError.timeout }
        } while stable < 4
        let height = ceil(hosting.fittingSize.height)
        guard height > 0 else { throw RenderError.emptyLayout }
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        window.setContentSize(NSSize(width: width, height: height))
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        let pw = Int(width * scale), ph = Int(height * scale)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph, bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            throw RenderError.emptyLayout
        }
        rep.size = NSSize(width: width, height: height)
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
