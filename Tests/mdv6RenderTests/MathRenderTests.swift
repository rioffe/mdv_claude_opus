import XCTest
import AppKit
@testable import mdv6Core

/// C-07.2 typesetting through the vendored SwiftMath (R-12, R-14, E-10, I-008, K-08, K-14/E-28 for LaTeX).
final class MathRenderTests: XCTestCase {

    private func spec(_ latex: String, display: Bool = false, size: CGFloat = 16) -> MathSpec {
        MathSpec(latex: latex, fontSize: size, color: .black, display: display)
    }

    /// R-12, K-08: `$…$` typesets in `.text` and `$$…$$` in `.display` — the display form of a sum with limits is taller. T-07.
    func testTextVsDisplayMode() {
        guard case .image(_, let inlineAscent, let inlineDescent) = MathImageCache.shared.rendered(for: spec("\\sum_{i=1}^n i"), scale: 2),
              case .image(_, let displayAscent, let displayDescent) = MathImageCache.shared.rendered(for: spec("\\sum_{i=1}^n i", display: true), scale: 2) else {
            return XCTFail("typesetting failed")
        }
        XCTAssertGreaterThan(displayAscent + displayDescent, inlineAscent + inlineDescent)
    }

    /// I-008, K-15: every math image is bitmap-backed (an `NSBitmapImageRep`, never a drawing handler) at the screen scale.
    func testImagesAreBitmapBacked() {
        guard case .image(let image, _, _) = MathImageCache.shared.rendered(for: spec("x^2"), scale: 2) else { return XCTFail() }
        XCTAssertEqual(image.representations.count, 1)
        let rep = image.representations.first as? NSBitmapImageRep
        XCTAssertNotNil(rep)
        XCTAssertEqual(CGFloat(rep!.pixelsWide), (image.size.width * 2).rounded(), accuracy: 1)
        XCTAssertGreaterThan(image.size.width, 0)
    }

    /// C-07.2: registered symbols, `\boxed`, `\operatorname`, `\dfrac`, `align*`, `cases`, `pmatrix` typeset without error. T-07.
    func testRewritesAndSymbolsTypeset() {
        for latex in ["a \\gtrsim b \\leqslant c \\implies d", "\\boxed{E = mc^2}", "\\operatorname{sin} x", "\\dfrac{a}{b}",
                      "\\begin{align*} a &= b \\\\ c &= d \\end{align*}", "f(x) = \\begin{cases} 1 & x > 0 \\\\ 0 & \\text{else} \\end{cases}",
                      "\\begin{pmatrix} 1 & 2 \\\\ 3 & 4 \\end{pmatrix}", "\\hookrightarrow \\varnothing \\checkmark \\iint \\intercal",
                      "\\pmod{n} \\bmod \\coloneqq \\not= \\big( x \\big)", "\\mathbb{R} \\vec{v} \\hat{x}"] {
            if case .fallback(_, let message) = MathImageCache.shared.rendered(for: spec(latex, display: true), scale: 2) {
                XCTFail("\(latex) fell back: \(message ?? "")")
            }
        }
        // \boxed draws a frame: the boxed image is wider than the bare content
        guard case .image(let boxed, _, _) = MathImageCache.shared.rendered(for: spec("\\boxed{x}"), scale: 2),
              case .image(let bare, _, _) = MathImageCache.shared.rendered(for: spec("x"), scale: 2) else { return XCTFail() }
        XCTAssertGreaterThan(boxed.size.width, bare.size.width + 0.6 * 16)
    }

    /// R-14, E-10: LaTeX SwiftMath rejects renders as its source with the parser's message; nothing is blank. T-07.
    func testRejectedLatexFallsBackWithMessage() {
        guard case .fallback(let source, let message) = MathImageCache.shared.rendered(for: spec("\\unknowncmd{x}", display: true), scale: 2) else {
            return XCTFail("expected fallback")
        }
        XCTAssertEqual(source, "$$\\unknowncmd{x}$$")
        XCTAssertFalse((message ?? "").isEmpty)
        guard case .fallback(let inlineSource, _) = MathImageCache.shared.rendered(for: spec("\\frac{a"), scale: 2) else { return XCTFail() }
        XCTAssertEqual(inlineSource, "$\\frac{a$")
    }

    /// R-41, K-14, E-28: a span over 64 KiB shows "input exceeds limit" and never reaches the typesetter; a span at the ceiling does.
    func testLatexCeiling() {
        var entries = 0
        PipelineProbe.onParserEntry = { if $0 == "math" { entries += 1 } }
        defer { PipelineProbe.onParserEntry = nil }
        let atCeiling = String(repeating: "x", count: ContentLimits.latexBytes)
        _ = MathImageCache.shared.rendered(for: spec(atCeiling), scale: 2)
        XCTAssertEqual(entries, 1)
        let over = atCeiling + "x"
        guard case .fallback(_, let message) = MathImageCache.shared.rendered(for: spec(over, display: true), scale: 2) else { return XCTFail() }
        XCTAssertEqual(message, ContentLimits.exceededMessage)
        XCTAssertEqual(entries, 1)
    }

    /// C-07.2: the cache holds 2048 entries keyed by the URL; the same spec is typeset once.
    func testCacheKeyedByURL() {
        let c = MathImageCache()
        var entries = 0
        PipelineProbe.onParserEntry = { if $0 == "math" { entries += 1 } }
        defer { PipelineProbe.onParserEntry = nil }
        _ = c.rendered(for: spec("y"), scale: 2)
        _ = c.rendered(for: spec("y"), scale: 2)
        XCTAssertEqual(entries, 1)
        _ = c.rendered(for: spec("y", size: 17), scale: 2)
        XCTAssertEqual(entries, 2)
        XCTAssertEqual(MathImageCache.cacheLimit, 2048)
    }

    /// R-13: math colour is the theme's text colour — a Sevilla-coloured render contains that colour and no black.
    func testColourFollowsSpec() {
        let brown = RGBA(r: 0x42, g: 0x37, b: 0x2C)
        guard case .image(let image, _, _) = MathImageCache.shared.rendered(for: MathSpec(latex: "x", fontSize: 40, color: brown, display: false), scale: 1) else { return XCTFail() }
        let rep = image.representations.first as! NSBitmapImageRep
        var sawBrown = false, sawBlack = false
        for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide {
            guard let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.9 else { continue }
            let (r, g, b) = (Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
            if abs(r - 0x42) <= 3 && abs(g - 0x37) <= 3 && abs(b - 0x2C) <= 3 { sawBrown = true }
            if r < 4 && g < 4 && b < 4 { sawBlack = true }
        } }
        XCTAssertTrue(sawBrown); XCTAssertFalse(sawBlack)
    }
}
