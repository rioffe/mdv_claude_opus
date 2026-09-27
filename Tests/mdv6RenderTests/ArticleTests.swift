import XCTest
import AppKit
import SwiftUI
import MarkdownUI
@testable import mdv6Core

/// The article's pure rules: R-24/E-17 find rendering, R-08 fence parts and copy-without-prompts, §7.2 width plumbing
/// (T-18), the R-16 placeholders and the E-16/C-07.1 placement flag.
@MainActor
final class ArticleTests: XCTestCase {

    /// R-24, E-17, T-23: occurrences are counted on source; `**` on `**bold**` counts 2 and marks nothing; three "the" in
    /// one block count three and are all marked; fences, `$$` fences, tables and image blocks are tinted, not highlighted.
    func testFindCountingAndHighlighting() {
        let blocks = ["# The title", "the cat and the dog, the end", "```\nthe code\n```", "$$\nthe\n$$", "| the |\n|---|\n| x |", "![the](x.png)"]
        let m = FindHighlight.matches(query: "the", blocks: blocks)
        XCTAssertEqual(m.map(\.blockIndex), [0, 1, 1, 1, 2, 3, 4, 5])
        XCTAssertEqual(FindHighlight.countOccurrences(query: "", in: "the"), 0)
        XCTAssertEqual(FindHighlight.countOccurrences(query: " ", in: "a b c"), 2)                 // whitespace-only, verbatim
        XCTAssertEqual(FindHighlight.countOccurrences(query: "aa", in: "aaa"), 1)
        XCTAssertEqual(FindHighlight.countOccurrences(query: "**", in: "**bold**"), 2)
        let bold = FindHighlight.highlightedAttributedString(block: "**bold**", query: "**", theme: .highContrast)
        XCTAssertEqual(FindHighlight.markedCount(bold), 0)                                        // counted but unmarked
        XCTAssertEqual(String(bold.characters), "bold")
        let three = FindHighlight.highlightedAttributedString(block: "the cat and the dog, the end", query: "the", theme: .highContrast)
        XCTAssertEqual(FindHighlight.markedCount(three), 3)
        XCTAssertTrue(FindHighlight.shouldInlineHighlight(block: "plain prose"))
        for b in ["```\nx\n```", "~~~\nx\n~~~", "$$\nx\n$$", "| a |\n|---|\n| b |", "text ![img](a.png) more"] {
            XCTAssertFalse(FindHighlight.shouldInlineHighlight(block: b), b)
        }
        XCTAssertEqual(FindHighlight.inlineText("## Heading text"), "Heading text")
        XCTAssertEqual(FindHighlight.inlineText("> quoted\n> more"), "quoted\nmore")
        XCTAssertEqual(FindHighlight.inlineText("- one\n* two\n+ three\n3. four"), "• one\n• two\n• three\nfour")
        let heading = FindHighlight.highlightedAttributedString(block: "## $\\pi$ heading", query: "pi", theme: .highContrast)
        XCTAssertEqual(String(heading.characters), "$\\pi$ heading")                              // math shown as source
        var state = FindState(query: "the", matches: m, current: 2)
        XCTAssertEqual(state.label, "3 of 8"); XCTAssertEqual(state.tint(for: 1), .strong); XCTAssertEqual(state.tint(for: 2), .weak); XCTAssertEqual(state.tint(for: 9), .none)
        state = FindState(); XCTAssertEqual(state.label, "No matches"); XCTAssertFalse(state.canStep)
    }

    /// R-08, C-05: fence parts and the language label; Copy Without Prompts through the chrome's rule.
    func testFenceParts() {
        let p = FenceParts(block: "```bash extra\n$ ls\nout\n$ pwd\n```")
        XCTAssertEqual(p.infoString, "bash extra"); XCTAssertEqual(p.code, "$ ls\nout\n$ pwd")
        XCTAssertEqual(CodeLanguage.label(infoString: p.infoString), "bash")
        XCTAssertTrue(CodeLanguage.isPromptAware(infoString: p.infoString) && CodeLanguage.isPrompted(code: p.code))
        XCTAssertEqual(CodeLanguage.stripPrompts(p.code), "ls\nout\npwd")
        XCTAssertEqual(FenceParts(block: "~~~\nx\n\ny").code, "x\n\ny")                          // unclosed fence
        XCTAssertNil(FenceParts(block: "```\nx\n```").infoString)
        XCTAssertEqual(BlockKind(block: "```mermaid\nflowchart LR\n```"), .mermaidFence)
        XCTAssertEqual(BlockKind(block: "```Mermaid extra\nx\n```"), .mermaidFence)
        XCTAssertEqual(BlockKind(block: "```js\nx\n```"), .codeFence)
        XCTAssertEqual(BlockKind(block: "## h"), .heading(2)); XCTAssertEqual(BlockKind(block: "---"), .thematicBreak); XCTAssertEqual(BlockKind(block: "p"), .other)
    }

    /// T-18, §7.2, K-13, R-11: a 1200 pt window with a 220 pt sidebar and a 240 pt inspector under high-contrast gives a
    /// column of 768 − … and a raster of column − 36; in a wide window the column is 768 and the raster 732; below 37 pt the
    /// raster is exactly 1 pt.
    func testMermaidWidthPlumbing() {
        let t = MDVTheme.highContrast
        let wide = ColumnWidth.column(area: 2400, sidebar: 220, inspector: 240, maxWidth: t.articleMaxWidth, padding: t.articleHorizontalPadding)
        XCTAssertEqual(wide, 768); XCTAssertEqual(ColumnWidth.rasterWidth(natural: 5000, column: wide), 732)
        let narrow = ColumnWidth.column(area: 1200, sidebar: 220, inspector: 240, maxWidth: t.articleMaxWidth, padding: t.articleHorizontalPadding)
        XCTAssertEqual(narrow, 1200 - 228 - 248 - 80 - 12)
        XCTAssertEqual(ColumnWidth.rasterWidth(natural: 5000, column: 36.5), 1)
        let host = StaticArticleHost(document: nil, theme: t, zoom: 1, smartTypography: true, mermaidStyle: .document, baseURL: nil, backingScale: 2)
        XCTAssertEqual(ArticleView(host: host, areaWidth: 2400).columnWidth, 768)
        XCTAssertEqual(ArticleView(host: StaticArticleHost(document: nil, theme: .sevilla, zoom: 1, smartTypography: true, mermaidStyle: .document, baseURL: nil, backingScale: 2), areaWidth: 860).columnWidth, 620 - 60 - 12)
    }

    /// C-07.1 / E-16: only own-paragraph display spans are registered for centring; a display span inside a list item is not.
    func testOwnParagraphRegistry() {
        let own = MathMarkdown.rewrite("$$a+b$$", fontSize: 16, headingSizeEms: [], color: .black)
        let ownURL = URL(string: String(own.dropFirst(4).dropLast()))!
        XCTAssertTrue(MathMarkdown.isOwnParagraph(url: ownURL))
        let item = MathMarkdown.rewrite("- $$c+d$$", fontSize: 16, headingSizeEms: [], color: .black)
        let itemURL = URL(string: String(item.dropFirst("- ![](".count).dropLast()))!
        XCTAssertFalse(MathMarkdown.isOwnParagraph(url: itemURL))
    }

    // MARK: v0.14 — C-22.2 `<img>`, R-16 inline images, C-20.3 / R-44 frontmatter, C-09.1 find typography

    /// A solid red PNG of the given point size in a temp directory; returns the directory.
    private func redImageDirectory(width: Int, height: Int) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-img-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        try NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("red.png"))
        return dir
    }

    private func redBounds(_ markdown: String, dir: URL, width: CGFloat = 860) throws -> CGRect? {
        var o = DocumentRenderer.Options(); o.scale = 1; o.width = width; o.baseURL = dir
        let img = try DocumentRenderer.render(markdown: markdown, options: o)
        guard let bm = Bitmap(image: img, crop: CGRect(origin: .zero, size: img.size), onWhite: true) else { return nil }
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0 ..< bm.height { for x in 0 ..< bm.width {
            let p = bm.pixel(x, y)
            if p.r > 200 && p.g < 60 && p.b < 60 { minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y) }
        } }
        return maxX < 0 ? nil : CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// R-51, C-22.2: a block `<img>` draws at the size its attributes ask for (caps, aspect kept, never enlarged). T-59.
    func testRawHTMLImageSizes() throws {
        let dir = try redImageDirectory(width: 928, height: 744)
        let w320 = try XCTUnwrap(try redBounds(#"<img src="red.png" alt="x" width="320">"#, dir: dir))
        XCTAssertEqual(w320.width, 320, accuracy: 1.5); XCTAssertEqual(w320.height, 320 * 744 / 928, accuracy: 1.5)
        let both = try XCTUnwrap(try redBounds(#"<img src="red.png" width="240" height="80">"#, dir: dir))
        XCTAssertEqual(both.height, 80, accuracy: 1.5); XCTAssertEqual(both.width, 80 * 928 / 744, accuracy: 1.5)
        let h60 = try XCTUnwrap(try redBounds(#"<img src="red.png" height="60">"#, dir: dir))
        XCTAssertEqual(h60.height, 60, accuracy: 1.5)
        let natural = try XCTUnwrap(try redBounds(#"<img src="red.png">"#, dir: dir))
        XCTAssertLessThanOrEqual(natural.width, 768 + 1)                        // shrunk to the column, never above
        let small = try redImageDirectory(width: 40, height: 20)
        let capped = try XCTUnwrap(try redBounds(#"<img src="red.png" width="300">"#, dir: small))
        XCTAssertEqual(capped.width, 40, accuracy: 1.5)                         // never enlarged
    }

    /// R-16, C-22.2: an inline `<img>` in a sentence draws at its asked size; an inline Markdown image loads from beside
    /// the document; a missing inline image leaves the sentence's other images intact. T-59.
    func testInlineImages() throws {
        let dir = try redImageDirectory(width: 928, height: 744)
        let inline = try XCTUnwrap(try redBounds(#"one <img src="red.png" alt="i" width="120"> two"#, dir: dir))
        XCTAssertEqual(inline.width, 120, accuracy: 1.5)
        let md = try XCTUnwrap(try redBounds("text ![small](red.png) more", dir: try redImageDirectory(width: 30, height: 30)))
        XCTAssertEqual(md.width, 30, accuracy: 1.5)
        let mixed = try XCTUnwrap(try redBounds(#"a <img src="nope.png" width="50"> b <img src="red.png" width="40"> c"#, dir: dir))
        XCTAssertEqual(mixed.width, 40, accuracy: 1.5)
    }

    /// F-173, R-12, D-02: the new inline provider leaves inline math exactly where the math provider put it.
    func testInlineMathPlacementUnchanged() throws {
        let t = MDVTheme.highContrast
        let text = MathMarkdown.rewrite("sum $x_i^2$ and $\\frac{a}{b}$ here", fontSize: t.baseFontSize, headingSizeEms: t.headingSizeEms, color: t.rgba.text)
        func render(_ provider: some InlineImageProviderBox) throws -> Bitmap {
            let view = provider.apply(Markdown(text).markdownTheme(ArticleTheme.markdownTheme(for: t, zoom: 1)))
                .frame(width: 600, alignment: .leading).background(t.background)
            let img = try DocumentRenderer.snapshot(AnyView(view), width: 600, scale: 2, background: t.rgba.background)
            return try XCTUnwrap(Bitmap(image: img, crop: CGRect(origin: .zero, size: img.size), onWhite: true))
        }
        let before = try render(MathOnly())
        let after = try render(Article())
        XCTAssertLessThanOrEqual(try XCTUnwrap(RenderMetrics.pixelMismatch(before, after)), 0.001)
    }

    /// C-20.3, R-44, I-018: the header renders as a table above the body; hidden, it takes no height, padding or spacing,
    /// so the body starts exactly where it would in the same document without a header. T-52.
    func testFrontmatterTableAndHidden() throws {
        let header = "---\ntitle: The Lighthouse\nstatus: draft\n---\n\n"
        let body = "# Heading\n\nA paragraph."
        func render(_ md: String, show: Bool) throws -> Bitmap {
            var o = DocumentRenderer.Options(); o.scale = 1; o.showFrontmatter = show
            let img = try DocumentRenderer.render(markdown: md, options: o)
            return try XCTUnwrap(Bitmap(image: img, crop: CGRect(origin: .zero, size: img.size), onWhite: true))
        }
        let page = MDVTheme.highContrast.rgba.background
        let plain = try render(body, show: true)
        let hidden = try render(header + body, show: false)
        let shown = try render(header + body, show: true)
        XCTAssertEqual(RenderMetrics.inkBands(hidden, page: page).first, RenderMetrics.inkBands(plain, page: page).first)
        XCTAssertEqual(hidden.height, plain.height)
        XCTAssertGreaterThan(shown.height, plain.height + 40)                 // a two-row table sits above the heading
        XCTAssertLessThan(RenderMetrics.inkBands(shown, page: page).first!.lowerBound, RenderMetrics.inkBands(plain, page: page).first!.lowerBound + 1)
    }

    /// R-24, C-09.1: a heading with a find match keeps its height (face, size, leading); a header takes the verbatim
    /// path, fence lines included, whatever the tint tests say. T-60, T-52.
    func testFindTypographyAndVerbatimHeader() throws {
        func height(_ md: String, query: String?) throws -> CGFloat {
            var o = DocumentRenderer.Options(); o.scale = 1; o.findQuery = query
            return try DocumentRenderer.render(markdown: md, options: o).size.height
        }
        for block in ["# The title", "## The subtitle", "### The third", "A paragraph with **the** strong `code` and _the_ emphasis."] {
            XCTAssertEqual(try height(block, query: "the"), try height(block, query: nil), accuracy: 1.5, block)
        }
        XCTAssertEqual(FindHighlight.mode(block: "---\nimage: ![x](y)\n---", isHeader: true), .verbatim)
        XCTAssertEqual(FindHighlight.mode(block: "text ![x](y)", isHeader: false), .tint)
        XCTAssertEqual(FindHighlight.mode(block: "plain", isHeader: false), .inline)
        let v = FindHighlight.verbatimAttributedString(block: "---\ntitle: **bold** fog\n---", query: "fog", theme: .highContrast)
        XCTAssertEqual(String(v.characters), "---\ntitle: **bold** fog\n---")
        XCTAssertEqual(FindHighlight.markedCount(v), 1)
        XCTAssertEqual(FindHighlight.markedCount(FindHighlight.verbatimAttributedString(block: "---\na: b\n---", query: "---", theme: .highContrast)), 2)
    }
}

/// Two inline providers behind one protocol, so the placement test renders the same text through each.
protocol InlineImageProviderBox { func apply<V: View>(_ v: V) -> AnyView }
struct MathOnly: InlineImageProviderBox { func apply<V: View>(_ v: V) -> AnyView { AnyView(v.markdownInlineImageProvider(MathInlineImageProvider(scale: 2))) } }
struct Article: InlineImageProviderBox {
    func apply<V: View>(_ v: V) -> AnyView {
        AnyView(v.markdownInlineImageProvider(ArticleInlineImageProvider(theme: .highContrast, scale: 2, baseURL: nil, loadRemote: false, remoteLoader: nil)))
    }
}
