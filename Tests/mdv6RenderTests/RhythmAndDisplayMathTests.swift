import XCTest
import AppKit
@testable import mdv6Core

/// T-45 (I-014, K-16, C-18.10, R-42) and T-46 (C-07.1, R-12, C-18.10), measured through `DocumentRenderer` — the same
/// `ArticleBlockView`s the window uses, against the single-`Markdown`-view oracle and the page colour.
@MainActor
final class RhythmAndDisplayMathTests: XCTestCase {

    static let rhythmDocument = "# A\n\nfirst paragraph.\n\n## B\n\nsecond paragraph.\n\n### C\n\nthird paragraph."
    static let scratch = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mdv6-rhythm")

    private func render(_ md: String, theme: MDVTheme, singleView: Bool = false, width: CGFloat = 860) throws -> Bitmap {
        var o = DocumentRenderer.Options()
        o.theme = theme; o.singleView = singleView; o.width = width; o.scale = 2
        let image = try DocumentRenderer.render(markdown: md, options: o)
        let rep = image.representations.first as! NSBitmapImageRep
        try? FileManager.default.createDirectory(at: Self.scratch, withIntermediateDirectories: true)
        try? rep.representation(using: .png, properties: [:])?.write(to: Self.scratch.appendingPathComponent("\(theme.id)-\(singleView ? "single" : "blocks")-\(md.hashValue).png"))
        return Bitmap(image: image, crop: CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh), onWhite: false)!
    }

    /// C-18.10: the per-block inset is `max(bottom_i, top_{i+1})` from the theme's spacings (I-014).
    func testBlockInsetIsMaxOfBottomAndTop() {
        let s = MDVTheme.sevilla
        XCTAssertEqual(ArticleBlockView<StaticArticleHost>.blockInset(theme: s, previous: "para", current: "## B"), 32)    // max(14, 32)
        XCTAssertEqual(ArticleBlockView<StaticArticleHost>.blockInset(theme: s, previous: "## B", current: "para"), 12)    // max(12, 0)
        XCTAssertEqual(ArticleBlockView<StaticArticleHost>.blockInset(theme: s, previous: "para", current: "### C"), 22)
        XCTAssertEqual(ArticleBlockView<StaticArticleHost>.blockInset(theme: s, previous: "para", current: "para"), 14)
        XCTAssertEqual(ArticleBlockView<StaticArticleHost>.blockInset(theme: s, previous: nil, current: "# A"), 0)
        let c = MDVTheme.charcoal
        XCTAssertEqual(ArticleBlockView<StaticArticleHost>.blockInset(theme: c, previous: "para", current: "## B"), 26)
        XCTAssertEqual(ArticleBlockView<StaticArticleHost>.blockInset(theme: c, previous: "## B", current: "para"), 10)
        XCTAssertEqual(ArticleBlockView<StaticArticleHost>.blockInset(theme: c, previous: "# A", current: "para"), 14)
    }

    /// C-17: `DocumentRenderer` yields a bitmap at `width × scale` on the page colour.
    func testRendererProducesPageBitmap() throws {
        let b = try render("one paragraph.", theme: .highContrast)
        XCTAssertEqual(b.width, 1720)
        let corner = b.pixel(2, 2)
        XCTAssertEqual(corner.r, MDVTheme.highContrast.rgba.background.r)
        XCTAssertGreaterThan(RenderMetrics.inkBands(b, page: MDVTheme.highContrast.rgba.background).count, 0)
    }

    private func gaps(_ theme: MDVTheme, singleView: Bool) throws -> [CGFloat] {
        let b = try render(Self.rhythmDocument, theme: theme, singleView: singleView)
        let bands = RenderMetrics.inkBands(b, page: theme.rgba.background)
        // bands: A, (A's rule when shown), p1, B, p2, C, p3 — merge the H1 rule into the heading band when present
        var merged = bands
        if theme.showH1Rule, merged.count == 7 { merged = [merged[0].lowerBound...merged[1].upperBound] + Array(merged[2...]) }
        XCTAssertEqual(merged.count, 6, "six ink bands (heading, paragraph ×3) expected, got \(bands)")
        return RenderMetrics.gaps(between: merged, scale: 2)
    }

    /// T-45, I-014, K-16, R-42: for paragraph→`## B`, `## B`→paragraph, paragraph→`### C`, `### C`→paragraph the ink gaps sit in
    /// the band `v ≤ g ≤ v + 0.6 f`; paragraph→heading > heading→paragraph; and the per-block rendering is within ±2 pt
    /// of the single-`Markdown`-view oracle. Sevilla and Charcoal.
    func testRhythmBandSevillaAndCharcoal() throws {
        for theme in [MDVTheme.sevilla, MDVTheme.charcoal] {
            let blocks = try gaps(theme, singleView: false)
            let single = try gaps(theme, singleView: true)
            guard blocks.count == 5, single.count == 5 else { continue }
            let body = theme.baseFontSize
            let pairs: [(name: String, g: CGFloat, v: CGFloat, f: CGFloat)] = [
                ("p1→## B", blocks[1], theme.h2TopSpacing, body * theme.h2SizeEm),
                ("## B→p2", blocks[2], theme.paragraphBottomSpacing, body * theme.h2SizeEm),
                ("p2→### C", blocks[3], theme.h3TopSpacing, body * theme.h3SizeEm),
                ("### C→p3", blocks[4], theme.paragraphBottomSpacing, body * theme.h3SizeEm),
            ]
            for p in pairs {
                let band = RenderMetrics.rhythmBand(margin: p.v, fontSize: p.f)
                XCTAssertTrue(band.contains(p.g), "\(theme.id) \(p.name): g = \(p.g) outside \(band)")
            }
            XCTAssertGreaterThan(blocks[1], blocks[2], "\(theme.id): paragraph→heading gap larger than heading→paragraph")
            XCTAssertGreaterThan(blocks[3], blocks[4], "\(theme.id)")
            for i in 1..<5 {
                XCTAssertLessThanOrEqual(abs(blocks[i] - single[i]), RenderMetrics.perBlockTolerance, "\(theme.id) pair \(i): blocks \(blocks[i]) vs single \(single[i])")
            }
        }
    }

    /// T-46, C-07.1: `$$r = \frac{a}{b}$$` on one line and the three-line fence form give identical rasters, centred within
    /// 2 pt, at the `.display` height (not the body-size E-16 height); `Text $$x$$ text` stays inline in the sentence.
    func testDisplayMathSingleLineAndFence() throws {
        let theme = MDVTheme.highContrast
        let one = try render("$$r = \\frac{a}{b}$$", theme: theme)
        let fence = try render("$$\nr = \\frac{a}{b}\n$$", theme: theme)
        XCTAssertEqual(one.width, fence.width); XCTAssertEqual(one.height, fence.height)
        XCTAssertEqual(RenderMetrics.pixelMismatch(one, fence), 0, "identical rasters")
        let box = RenderMetrics.inkBounds(one, page: theme.rgba.background)!
        let offset = RenderMetrics.horizontalCentreOffset(of: box, in: CGFloat(one.width)) / 2
        XCTAssertLessThanOrEqual(abs(offset), 2, "centred within 2 pt (offset \(offset))")
        // height: the display typesetting of the same LaTeX at 16 pt, not the inline/body one
        guard case .image(let display, _, _) = MathImageCache.shared.rendered(for: MathSpec(latex: "r = \\frac{a}{b}", fontSize: 16, color: theme.rgba.text, display: true), scale: 2),
              case .image(let inline, _, _) = MathImageCache.shared.rendered(for: MathSpec(latex: "r = \\frac{a}{b}", fontSize: 16, color: theme.rgba.text, display: false), scale: 2) else { return XCTFail() }
        let displayInk = Bitmap(image: display, crop: CGRect(x: 0, y: 0, width: display.size.width * 2, height: display.size.height * 2), onWhite: true)!
        let inlineInk = Bitmap(image: inline, crop: CGRect(x: 0, y: 0, width: inline.size.width * 2, height: inline.size.height * 2), onWhite: true)!
        let dh = RenderMetrics.inkBounds(displayInk, page: RGBA(r: 255, g: 255, b: 255))!.height
        let ih = RenderMetrics.inkBounds(inlineInk, page: RGBA(r: 255, g: 255, b: 255))!.height
        XCTAssertGreaterThan(dh, ih)
        XCTAssertEqual(box.height, dh, accuracy: 3)
        // mid-line $$ stays inline: one ink band, and the text's width exceeds the math's
        let mid = try render("Text $$x$$ text", theme: theme)
        let midBands = RenderMetrics.inkBands(mid, page: theme.rgba.background)
        XCTAssertEqual(midBands.count, 1, "one line of text with the image inline")
        XCTAssertLessThan(RenderMetrics.horizontalCentreOffset(of: RenderMetrics.inkBounds(mid, page: theme.rgba.background)!, in: CGFloat(mid.width)), -100, "leading-aligned sentence")
    }
}
