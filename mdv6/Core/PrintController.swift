// PrintController — R-45 / C-21: the document re-rendered for paper through the screen's pipeline, one vector PDF per
// C-02 block (SwiftUI `ImageRenderer`), stacked with the screen's rhythm scaled by s_p (C-21.2), paginated between
// blocks (C-21.5), in the fixed `high-contrast` theme with no screen state (I-017). `renderPDF` is the whole pipeline
// to a PDF file plus per-block records (the harness's `--print-pdf`, C-17); `printDocument` hands the same container to
// the print panel.
import SwiftUI
import AppKit
import MarkdownUI

/// Everything print reads (I-017: no zoom, no screen theme, no window).
public struct PrintRequest {
    public let document: ParsedDocument
    public let baseURL: URL?
    public let smartTypography: Bool
    public let showFrontmatter: Bool
    public let mermaidStyle: MermaidStyle
    public let jobTitle: String
    public init(document: ParsedDocument, baseURL: URL?, smartTypography: Bool, showFrontmatter: Bool, mermaidStyle: MermaidStyle, jobTitle: String) {
        self.document = document; self.baseURL = baseURL; self.smartTypography = smartTypography
        self.showFrontmatter = showFrontmatter; self.mermaidStyle = mermaidStyle; self.jobTitle = jobTitle
    }
}

/// C-17 `--print-pdf` records: where each block printed (page space: points, y up), the image draws inside it, and the
/// rects of its math spans (`accepted` false for a span SwiftMath rejects — T-53 (2b)).
public struct PrintImageRecord: Codable, Equatable { public let pixels: [Int]; public let rect: [CGFloat] }
public struct PrintFormulaRecord: Codable, Equatable { public let rect: [CGFloat]; public let accepted: Bool }
public struct PrintBlockRecord: Codable, Equatable {
    public let index: Int
    public let kind: String
    public let page: Int
    public let rect: [CGFloat]
    public let images: [PrintImageRecord]
    public let formulas: [PrintFormulaRecord]
}
public struct PrintOutput { public let pdf: Data; public let blocks: [PrintBlockRecord] }

/// One block's printed page and what print knows about it (block-local rects are y-up).
struct PrintBlock {
    let index: Int
    let kind: String
    let document: CGPDFDocument          // retained: a CGPDFPage does not retain its document (C-21.2)
    let page: CGPDFPage
    let size: CGSize
    let formulas: [(rect: CGRect, accepted: Bool)]
}

@MainActor
public enum PrintController {
    /// C-21.1: the print theme, whatever the screen shows.
    public static let theme = MDVTheme.highContrast
    /// K-17: inline formulas that cannot be vector are baked at this density (864 ppi).
    public static let mathDensity: CGFloat = 12
    /// K-17: a diagram that cannot print as a PDF prints as a raster at this density (288 ppi).
    public static let diagramDensity: CGFloat = 4
    nonisolated public static let letter = CGSize(width: 612, height: 792)

    // MARK: pipeline

    static func renderBlocks(_ r: PrintRequest, contentWidth wc: CGFloat) async -> [PrintBlock] {
        let sp = PrintScale.sp(contentWidth: wc, articleMaxWidth: theme.articleMaxWidth)
        var out: [PrintBlock] = []
        for (i, block) in r.document.blocks.enumerated() {
            if i == 0, let rows = r.document.frontmatter {                         // C-21.6
                guard r.showFrontmatter else { continue }
                if let p = pdf(of: FrontmatterTableView(rows: rows, theme: theme, zoom: sp, paddingScale: sp), width: wc) {
                    out.append(PrintBlock(index: i, kind: "frontmatter", document: p.0, page: p.1, size: p.2, formulas: []))
                }
                continue
            }
            if let b = await printBlock(i, block, r, wc: wc, sp: sp) { out.append(b) }
        }
        return out
    }

    private static func printBlock(_ i: Int, _ block: String, _ r: PrintRequest, wc: CGFloat, sp: CGFloat) async -> PrintBlock? {
        switch BlockKind(block: block) {
        case .mermaidFence:
            let source = FenceParts(block: block).code
            if let page = await diagram(source, style: r.mermaidStyle, wc: wc, sp: sp) {
                return PrintBlock(index: i, kind: "diagram", document: page.0, page: page.1, size: page.2, formulas: [])
            }
            return code(i, "```text\n" + source + "\n```", wc: wc, sp: sp)          // C-21.3: fails both routes → source
        case .codeFence:
            return code(i, block, wc: wc, sp: sp)
        default:
            return prose(i, block, r, wc: wc, sp: sp)
        }
    }

    // MARK: C-21.3 diagrams

    private static func diagram(_ source: String, style: MermaidStyle, wc: CGFloat, sp: CGFloat) async -> (CGPDFDocument, CGPDFPage, CGSize)? {
        let wd = PrintScale.diagramWidth(contentWidth: wc, sp: sp)
        let wl = PrintScale.layoutWidth(diagramWidth: wd, sp: sp)
        let bg = theme.rgba.secondaryBackground.nsColor
        if MermaidDispatch.isNative(source) {
            guard let prepared = try? MDVMermaidPipeline.prepare(source: source, theme: MDVMermaidPipeline.theme(for: style, document: theme)) else { return nil }
            if let p = MDVMermaidPipeline.pdf(prepared, width: wl) {
                return chrome(page: p.page, size: p.size, drawnWidth: min(p.size.width * sp, wd), wc: wc, sp: sp, background: bg)
            }
            guard let raster = MDVMermaidPipeline.rasterize(prepared, width: wl, scale: diagramDensity * sp) else { return nil }
            return chrome(image: raster, drawnWidth: min(raster.size.width * sp, wd), wc: wc, sp: sp, background: bg)
        }
        guard let p = await MermaidWebRenderer.pdf(source: source, theme: theme, width: wl) else { return nil }
        return chrome(page: p.page, size: p.size, drawnWidth: wd, wc: wc, sp: sp, background: bg)
    }

    /// C-21.3: the diagram on the code-block background with 12·s_p vertical insets and a 6 pt radius, centred.
    private static func chrome(page: CGPDFPage? = nil, image: NSImage? = nil, size natural: CGSize? = nil, drawnWidth: CGFloat,
                               wc: CGFloat, sp: CGFloat, background: NSColor) -> (CGPDFDocument, CGPDFPage, CGSize)? {
        let n = natural ?? image?.size ?? .zero
        guard n.width > 0 else { return nil }
        let scale = drawnWidth / n.width
        let drawn = CGSize(width: drawnWidth, height: n.height * scale)
        let inset = 12 * sp
        let size = CGSize(width: wc, height: drawn.height + 2 * inset)
        return makePDF(size: size) { ctx in
            background.setFill()
            NSBezierPath(roundedRect: CGRect(origin: .zero, size: size), xRadius: 6, yRadius: 6).fill()
            let origin = CGPoint(x: (wc - drawn.width) / 2, y: inset)
            if let page {
                ctx.saveGState(); ctx.translateBy(x: origin.x, y: origin.y); ctx.scaleBy(x: scale, y: scale); ctx.drawPDFPage(page); ctx.restoreGState()
            } else if let image {
                image.draw(in: CGRect(origin: origin, size: drawn))
            }
        }
    }

    // MARK: code (C-21.2: soft-wrapped, no hover chrome)

    private static func code(_ i: Int, _ block: String, wc: CGFloat, sp: CGFloat) -> PrintBlock? {
        let parts = FenceParts(block: block)
        let view = PrintCodeBlock(parts: parts, sp: sp)
        guard let p = pdf(of: view, width: wc) else { return nil }
        return PrintBlock(index: i, kind: "code", document: p.0, page: p.1, size: p.2, formulas: [])
    }

    // MARK: prose and C-21.4 math

    private static func prose(_ i: Int, _ block: String, _ r: PrintRequest, wc: CGFloat, sp: CGFloat) -> PrintBlock? {
        let size = theme.baseFontSize * sp
        var md = MathMarkdown.rewrite(RawHTMLImages.rewrite(block), fontSize: size, headingSizeEms: theme.headingSizeEms, color: theme.rgba.text)
        if r.smartTypography && theme.smartTypographyAllowed { md = smartenMarkdown(md) }
        let sources = InlineImageSources.sources(in: md)
        let specs = sources.compactMap { s in URL(string: s).flatMap(MathMarkdown.decode(url:)) }

        // A block that is exactly one own-paragraph `$$…$$` SwiftMath accepts: its vector image, centred, 4·s_p padding.
        if sources.count == 1, specs.count == 1, specs[0].display, md.trimmingCharacters(in: .whitespacesAndNewlines) == "![](\(sources[0]))",
           let vector = MathImageCache.shared.vectorImage(for: specs[0]) {
            let s = min(1, wc / vector.size.width)
            let drawn = CGSize(width: vector.size.width * s, height: vector.size.height * s)
            let pad = 4 * sp
            let pageSize = CGSize(width: wc, height: drawn.height + 2 * pad)
            let rect = CGRect(x: (wc - drawn.width) / 2, y: pad, width: drawn.width, height: drawn.height)
            guard let p = makePDF(size: pageSize, draw: { _ in vector.draw(in: rect) }) else { return nil }
            return PrintBlock(index: i, kind: "formula", document: p.0, page: p.1, size: p.2, formulas: [(rect, true)])
        }

        // Inline slots (informative method, C-21.4): placeholders of the slot's size whose pixel size is 1 × (k+1), found
        // again in the laid-out page by that signature, then the real content drawn into each rect.
        let provider = ArticleInlineImageProvider(theme: theme, scale: mathDensity, baseURL: r.baseURL, loadRemote: false, remoteLoader: nil)
        struct Slot { let source: String; let size: CGSize; let vector: NSImage?; let image: NSImage; let isMath: Bool }
        var slots: [Slot] = []
        for source in sources {
            guard let url = URL(string: source, relativeTo: r.baseURL) else { continue }
            if let spec = MathMarkdown.decode(url: url) {
                let baked: NSImage
                switch MathImageCache.shared.rendered(for: spec, scale: mathDensity) {
                case .image(let img, _, _): baked = img
                case .fallback(let src, _): baked = MathFallbackImage.make(source: src, fontSize: spec.fontSize * 0.9, color: spec.color, scale: mathDensity)
                }
                slots.append(Slot(source: source, size: baked.size, vector: MathImageCache.shared.vectorImage(for: spec), image: baked, isMath: true))
            } else if case .image(let img) = provider.resolveLocal(url: url) {
                slots.append(Slot(source: source, size: img.size, vector: nil, image: img, isMath: false))
            }
        }
        func layout(_ images: [String: Image]) -> (CGPDFDocument, CGPDFPage, CGSize)? {
            pdf(of: PrintProse(markdown: md, sp: sp, baseURL: r.baseURL, provider: provider).markdownResolvedInlineImages(images), width: wc)
        }
        let isOnlyImage = sources.count == 1 && md.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("](\(sources[0]))")
            && md.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("![")
        if slots.isEmpty || isOnlyImage {                                        // a block image loads synchronously itself
            guard let p = layout([:]) else { return nil }
            return PrintBlock(index: i, kind: "prose", document: p.0, page: p.1, size: p.2, formulas: [])
        }
        let placeholders = Dictionary(slots.enumerated().map { k, s in (s.source, Image(nsImage: placeholder(size: s.size, index: k))) }, uniquingKeysWith: { a, _ in a })
        if let first = layout(placeholders) {
            let found = PDFImageScan.placements(in: first.1)
            var rects = [CGRect?](repeating: nil, count: slots.count)
            for f in found where f.pixels.width == 1 {
                let k = Int(f.pixels.height) - 1
                if k >= 0, k < rects.count, rects[k] == nil { rects[k] = f.rect }
            }
            // The same layout again with slots that draw nothing (so no placeholder image remains in the page), then the
            // content drawn into the rects the first pass found.
            if rects.allSatisfy({ $0 != nil }),
               let clean = layout(Dictionary(slots.map { ($0.source, emptyImage($0.size)) }, uniquingKeysWith: { a, _ in a })),
               abs(clean.2.height - first.2.height) < 0.5 {
                let drawn = makePDF(size: clean.2) { ctx in
                    ctx.drawPDFPage(clean.1)
                    for (slot, rect) in zip(slots, rects.map { $0! }) { (slot.vector ?? slot.image).draw(in: rect) }
                }
                if let drawn {
                    let formulas = zip(slots, rects).filter { $0.0.isMath }.map { ($0.1!, $0.0.vector != nil) }
                    return PrintBlock(index: i, kind: "prose", document: drawn.0, page: drawn.1, size: drawn.2, formulas: formulas)
                }
            }
        }
        // E-33: the overlay could not place the slots — the baked bitmaps print where MarkdownUI puts them.
        let real = Dictionary(slots.map { ($0.source, Image(nsImage: $0.image)) }, uniquingKeysWith: { a, _ in a })
        guard let p = layout(real) else { return nil }
        return PrintBlock(index: i, kind: "prose", document: p.0, page: p.1, size: p.2, formulas: [])
    }

    /// A slot that reserves its size and draws nothing visible: SwiftUI rasterizes every image in a line of text, so the
    /// spacer is one fully transparent pixel stretched to the slot (F-184) — the only image object a vector formula's
    /// rect may hold.
    private static func emptyImage(_ size: CGSize) -> Image {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0), atX: 0, y: 0)
        rep.size = NSSize(width: max(size.width, 0.1), height: max(size.height, 0.1))
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return Image(nsImage: img)
    }

    /// A solid image in the page colour whose *pixel* size is 1 × (index + 1) — the slot's signature.
    private static func placeholder(size: CGSize, index: Int) -> NSImage {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: index + 1, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let c = theme.rgba.background
        for y in 0 ... index { rep.setColor(NSColor(deviceRed: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1), atX: 0, y: y) }
        rep.size = NSSize(width: max(size.width, 0.1), height: max(size.height, 0.1))
        let img = NSImage(size: rep.size)
        img.addRepresentation(rep)
        return img
    }

    // MARK: PDF helpers

    /// One view, laid out at `width`, into a one-page vector PDF (text stays glyphs).
    static func pdf(of view: some View, width: CGFloat) -> (CGPDFDocument, CGPDFPage, CGSize)? {
        let renderer = ImageRenderer(content: view.frame(width: width, alignment: .topLeading).environment(\.colorScheme, .light))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        var result: (CGPDFDocument, CGPDFPage, CGSize)?
        renderer.render { size, draw in
            guard size.width > 0, size.height > 0 else { return }
            result = makePDF(size: size) { ctx in draw(ctx) }
        }
        return result
    }

    static func makePDF(size: CGSize, draw: (CGContext) -> Void) -> (CGPDFDocument, CGPDFPage, CGSize)? {
        let data = NSMutableData()
        var box = CGRect(origin: .zero, size: size)
        guard let consumer = CGDataConsumer(data: data as CFMutableData), let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        ctx.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        draw(ctx)
        NSGraphicsContext.restoreGraphicsState()
        ctx.endPDFPage()
        ctx.closePDF()
        guard let provider = CGDataProvider(data: data as CFData), let doc = CGPDFDocument(provider), let page = doc.page(at: 1) else { return nil }
        return (doc, page, size)
    }

    // MARK: C-21.1 page, C-21.2 stacking, C-21.5 pagination

    static func printInfo(paper: CGSize) -> NSPrintInfo {
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.paperSize = paper
        info.topMargin = PrintScale.margin; info.bottomMargin = PrintScale.margin
        info.leftMargin = PrintScale.margin; info.rightMargin = PrintScale.margin
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false; info.isVerticallyCentered = false
        info.dictionary()[NSPrintInfo.AttributeKey.headerAndFooter] = true         // job title, date, page numbers
        return info
    }

    /// C-21.2: blocks top-down with s_p × the screen's gap for each pair under the print theme (a hidden header absent).
    static func container(_ blocks: [PrintBlock], request: PrintRequest, contentWidth wc: CGFloat) -> PrintContainerView {
        let sp = PrintScale.sp(contentWidth: wc, articleMaxWidth: theme.articleMaxWidth)
        let view = PrintContainerView(frame: .zero)
        view.jobTitle = request.jobTitle
        view.pageBackground = theme.rgba.background.nsColor
        var y: CGFloat = 0
        var previous: String? = nil
        for b in blocks {
            let current = request.document.blocks[b.index]
            y += sp * ArticleBlockView<StaticArticleHost>.blockInset(theme: theme, previous: previous, current: current)
            view.items.append(.init(block: b, frame: CGRect(x: 0, y: y, width: wc, height: ceil(b.size.height))))
            y += ceil(b.size.height)
            previous = current
        }
        view.frame = CGRect(x: 0, y: 0, width: wc, height: max(y, 1))
        return view
    }

    // MARK: entry points

    /// The whole pipeline to a paginated PDF (the Save-as-PDF output), plus one record per printed block part.
    public static func renderPDF(_ r: PrintRequest, paper: CGSize = letter) async -> PrintOutput {
        FontRegistration.registerBundledFonts()
        let wc = PrintScale.contentWidth(paperWidth: paper.width)
        let blocks = await renderBlocks(r, contentWidth: wc)
        let view = container(blocks, request: r, contentWidth: wc)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-print-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        let info = printInfo(paper: paper)
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
        let op = NSPrintOperation(view: view, printInfo: info)
        op.showsPrintPanel = false
        op.showsProgressPanel = false
        op.jobTitle = r.jobTitle
        op.run()
        let data = (try? Data(contentsOf: url)) ?? Data()
        return PrintOutput(pdf: data, blocks: records(view, pdf: data, paper: paper))
    }

    /// Records from the container frames and the page breaks the container's own rule produces (C-21.5), image draws
    /// read from the finished pages (PDFImageScan).
    static func records(_ view: PrintContainerView, pdf: Data, paper: CGSize) -> [PrintBlockRecord] {
        let pageHeight = paper.height - 2 * PrintScale.margin
        let doc = CGDataProvider(data: pdf as CFData).flatMap(CGPDFDocument.init)
        var tops: [CGFloat] = [0]
        while let top = tops.last, top < view.bounds.height - 0.5 {
            let bottom = view.adjustedBottom(top: top, proposed: top + pageHeight, limit: top + pageHeight * (1 - view.heightAdjustLimit))
            tops.append(bottom <= top ? top + pageHeight : bottom)
        }
        var out: [PrintBlockRecord] = []
        for item in view.items {
            for (p, top) in tops.dropLast().enumerated() {
                let bottom = tops[p + 1]
                let lo = max(item.frame.minY, top), hi = min(item.frame.maxY, bottom)
                guard hi - lo > 0.5 else { continue }
                let pageTopY = paper.height - PrintScale.margin                   // PDF y of the content area's top
                let rect = CGRect(x: PrintScale.margin + item.frame.minX, y: pageTopY - (hi - top), width: item.frame.width, height: hi - lo)
                let blockTopPdf = pageTopY - (item.frame.minY - top)
                let formulas = item.block.formulas.compactMap { f -> PrintFormulaRecord? in
                    let fr = CGRect(x: PrintScale.margin + f.rect.minX, y: blockTopPdf - item.block.size.height + f.rect.minY, width: f.rect.width, height: f.rect.height)
                    guard fr.intersects(rect) else { return nil }
                    return PrintFormulaRecord(rect: [fr.minX, fr.minY, fr.width, fr.height], accepted: f.accepted)
                }
                let images = (doc?.page(at: p + 1)).map(PDFImageScan.placements(in:))?.filter { $0.rect.intersects(rect.insetBy(dx: 0.5, dy: 0.5)) }
                    .map { PrintImageRecord(pixels: [Int($0.pixels.width), Int($0.pixels.height)], rect: [$0.rect.minX, $0.rect.minY, $0.rect.width, $0.rect.height]) } ?? []
                out.append(PrintBlockRecord(index: item.block.index, kind: item.block.kind, page: p + 1,
                                            rect: [rect.minX, rect.minY, rect.width, rect.height], images: images, formulas: formulas))
            }
        }
        return out
    }

    private static var activeOperation: NSPrintOperation?
    private final class RunDelegate: NSObject {
        @objc func done(_ op: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) { MainActor.assumeIsolated { PrintController.activeOperation = nil } }
    }
    private static let runDelegate = RunDelegate()

    /// R-45 / C-21.6: the print panel as a sheet on the window; a second ⌘P while one is open beeps.
    public static func printDocument(_ r: PrintRequest, window: NSWindow?) {
        guard activeOperation == nil else { NSSound.beep(); return }
        let paper = NSPrintInfo.shared.paperSize
        Task { @MainActor in
            let wc = PrintScale.contentWidth(paperWidth: paper.width)
            let blocks = await renderBlocks(r, contentWidth: wc)
            DispatchQueue.main.async {                                      // C-21.6: never from inside the Task
                let view = container(blocks, request: r, contentWidth: wc)
                let op = NSPrintOperation(view: view, printInfo: printInfo(paper: paper))
                op.jobTitle = r.jobTitle
                op.showsPrintPanel = true
                op.showsProgressPanel = true
                op.printPanel.options.formUnion([.showsPaperSize, .showsOrientation, .showsScaling])
                activeOperation = op
                if let window {
                    op.runModal(for: window, delegate: runDelegate, didRun: #selector(RunDelegate.done(_:success:contextInfo:)), contextInfo: nil)
                } else {
                    op.run(); activeOperation = nil
                }
            }
        }
    }
}

/// C-21.5: a flipped canvas that draws each block's PDF and moves a break that would cut a block to that block's top.
public final class PrintContainerView: NSView {
    struct Item { let block: PrintBlock; let frame: CGRect }
    var items: [Item] = []
    var jobTitle = "mdv6"
    var pageBackground: NSColor = .white

    public override var isFlipped: Bool { true }
    public override var printJobTitle: String { jobTitle }
    /// C-21.5 / K-17: blocks up to 90 % of a page move whole.
    public override var heightAdjustLimit: CGFloat { 0.9 }

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        pageBackground.setFill(); dirtyRect.fill()
        for item in items where item.frame.intersects(dirtyRect) {
            ctx.saveGState()
            ctx.translateBy(x: item.frame.minX, y: item.frame.maxY)             // block PDFs are y-up; this view is flipped
            ctx.scaleBy(x: 1, y: -1)
            ctx.drawPDFPage(item.block.page)
            ctx.restoreGState()
        }
    }

    /// C-21.5: the first block that straddles the proposed break moves to the next page when it is no taller than a page
    /// and does not start at the page's top; the result is clamped to [limit, proposed].
    func adjustedBottom(top: CGFloat, proposed: CGFloat, limit: CGFloat) -> CGFloat {
        var bottom = proposed
        let pageHeight = proposed - top
        for item in items {
            if item.frame.minY >= proposed { break }
            guard item.frame.maxY > proposed else { continue }
            if item.frame.height <= pageHeight && item.frame.minY > top { bottom = item.frame.minY }
            break
        }
        return min(max(bottom, limit), proposed)
    }

    public override func adjustPageHeightNew(_ newBottom: UnsafeMutablePointer<CGFloat>, top: CGFloat, bottom: CGFloat, limit: CGFloat) {
        newBottom.pointee = adjustedBottom(top: top, proposed: bottom, limit: limit)
    }
}

/// C-21.2: a prose block for paper — the screen's Markdown theme at s_p (type and margins), local images only.
struct PrintProse: View {
    let markdown: String
    let sp: CGFloat
    let baseURL: URL?
    let provider: ArticleInlineImageProvider
    var body: some View {
        let t = PrintController.theme
        Markdown(markdown, baseURL: baseURL)
            .markdownTheme(ArticleTheme.markdownTheme(for: t, zoom: sp, marginScale: sp))
            .markdownImageProvider(ArticleImageProvider(theme: t, scale: PrintController.diagramDensity, baseURL: baseURL, loadRemote: false, remoteLoader: nil))
            .markdownInlineImageProvider(provider)
            .markdownCodeSyntaxHighlighter(ArticleCodeHighlighter(theme: t, zoom: sp))
            .foregroundStyle(t.text)
    }
}

/// C-21.2: a fenced block for paper — the label, the highlighted code soft-wrapped, no hover toolbar or menu.
struct PrintCodeBlock: View {
    let parts: FenceParts
    let sp: CGFloat
    var body: some View {
        let t = PrintController.theme
        VStack(alignment: .leading, spacing: 4 * sp) {
            if parts.infoString != nil {
                Text(CodeLanguage.label(infoString: parts.infoString)).font(.system(size: 10.5 * sp, weight: .medium, design: .monospaced)).foregroundStyle(t.tertiaryText)
            }
            Text(CodeRenderer.shared.render(code: parts.code, languageHint: parts.infoString, theme: t, zoom: sp))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16 * sp).padding(.vertical, 12 * sp)
        .background(t.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
