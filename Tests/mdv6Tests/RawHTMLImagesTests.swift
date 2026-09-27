import XCTest
@testable import mdv6Core

/// C-22.1 rewrite, C-22.2 display size, C-12 step (0), E-35 (R-51). T-59 (unit half).
final class RawHTMLImagesTests: XCTestCase {

    /// C-22.1: a tag becomes `![](mdv6-img://…)` carrying src, alt, width and height; the URL round-trips. R-51, T-59.
    func testRewriteAndRoundTrip() throws {
        let out = RawHTMLImages.rewrite(#"Logo: <img src="../MDV6.png" alt="mdv" width="320px"> end"#)
        XCTAssertTrue(out.hasPrefix("Logo: ![](mdv6-img://"))
        XCTAssertTrue(out.hasSuffix(") end"))
        let url = try XCTUnwrap(URL(string: String(out.dropFirst("Logo: ![](".count).dropLast(") end".count))))
        let spec = try XCTUnwrap(HTMLImageSpec(url: url))
        XCTAssertEqual(spec.src, "../MDV6.png")
        XCTAssertEqual(spec.alt, "mdv")
        XCTAssertEqual(spec.width, 320)
        XCTAssertNil(spec.height)
        XCTAssertEqual(spec.url, HTMLImageSpec(src: "../MDV6.png", alt: "mdv", width: 320, height: nil).url)
    }

    /// C-22.1: single-quoted and bare values; case-insensitive attribute names; a quoted `>` does not end the tag (F-171).
    func testAttributeForms() throws {
        func spec(_ tag: String) throws -> HTMLImageSpec {
            let out = RawHTMLImages.rewrite(tag)
            return try XCTUnwrap(HTMLImageSpec(url: try XCTUnwrap(URL(string: String(out.dropFirst(4).dropLast())))))
        }
        XCTAssertEqual(try spec("<img src='a.png' alt='single' width=\"100\">").width, 100)
        XCTAssertEqual(try spec("<img SRC=a.png ALT=bare WIDTH=90>").alt, "bare")
        let q = try spec(#"<img src="a.png" alt="a > b" width="60">"#)
        XCTAssertEqual(q.alt, "a > b")
        XCTAssertEqual(q.width, 60)
    }

    /// E-35: literal cases — no or empty src, code spans, fences, a missing `>`, other tags; odd sizes are absent.
    func testLiteralCases() throws {
        XCTAssertEqual(RawHTMLImages.rewrite(#"<img alt="x">"#), #"<img alt="x">"#)
        XCTAssertEqual(RawHTMLImages.rewrite(#"<img src="" alt="x">"#), #"<img src="" alt="x">"#)
        XCTAssertEqual(RawHTMLImages.rewrite("`<img src=\"a.png\">` and ``<img src=b>``"), "`<img src=\"a.png\">` and ``<img src=b>``")
        XCTAssertEqual(RawHTMLImages.rewrite("```\n<img src=\"a.png\">\n```"), "```\n<img src=\"a.png\">\n```")
        XCTAssertEqual(RawHTMLImages.rewrite("<img src=a.png"), "<img src=a.png")
        XCTAssertEqual(RawHTMLImages.rewrite(##"<a href="#">x</a>"##), ##"<a href="#">x</a>"##)
        for bad in ["50%", "0", "auto", "-3"] {
            let out = RawHTMLImages.rewrite("<img src=a.png width=\"\(bad)\">")
            let spec = try XCTUnwrap(HTMLImageSpec(url: try XCTUnwrap(URL(string: String(out.dropFirst(4).dropLast())))))
            XCTAssertNil(spec.width, bad)
        }
    }

    /// C-22.2: caps, never enlarging — both, width only, height only, neither; natural smaller than the cap.
    func testDisplaySize() {
        let natural = CGSize(width: 928, height: 744)
        func size(_ w: CGFloat?, _ h: CGFloat?, _ n: CGSize = natural) -> CGSize {
            HTMLImageSpec(src: "x", alt: "", width: w, height: h).displaySize(natural: n)
        }
        let r = 928.0 / 744.0
        XCTAssertEqual(size(320, nil).width, 320); XCTAssertEqual(size(320, nil).height, 320 / r, accuracy: 0.001)
        XCTAssertEqual(size(240, 80).width, 80 * r, accuracy: 0.001); XCTAssertEqual(size(240, 80).height, 80)
        XCTAssertEqual(size(nil, 60).width, 60 * r, accuracy: 0.001); XCTAssertEqual(size(nil, 60).height, 60)
        XCTAssertEqual(size(nil, nil), natural)
        XCTAssertEqual(size(500, nil, CGSize(width: 100, height: 50)), CGSize(width: 100, height: 50))   // never enlarges
    }

    /// C-22.2: `src` resolves like a Markdown image destination.
    func testResolvedURL() {
        let base = URL(fileURLWithPath: "/docs/test-docs", isDirectory: true)   // the document directory, as `baseURL` is
        XCTAssertEqual(HTMLImageSpec(src: "../MDV6.png", alt: "", width: nil, height: nil).resolvedURL(baseURL: base).path, "/docs/MDV6.png")
        XCTAssertEqual(HTMLImageSpec(src: "http://127.0.0.1:8765/a.png", alt: "", width: nil, height: nil).resolvedURL(baseURL: base).scheme, "http")
    }

    /// C-12 step (0) (F-171): `<img>` tags are removed from TOC text, slugs and bookmark titles.
    func testStripInlineMarkdownRemovesImgTags() {
        XCTAssertEqual(stripInlineMarkdown(#"Logo <img src="../MDV6.png" alt="logo" width="20">"#), "Logo")
        let doc = ParsedDocument(raw: "### Logo <img src=\"../MDV6.png\" width=\"20\">\n\ntext")
        XCTAssertEqual(doc.tocHeadings.first?.text, "Logo")
        XCTAssertEqual(headingSlug(doc.tocHeadings.first?.slugText ?? ""), "logo")
        XCTAssertEqual(BookmarkTitle.title(blocks: doc.blocks, toc: doc.tocHeadings, index: 1), "Logo")
        XCTAssertEqual(stripInlineMarkdown("`<img src=a>` x"), "<img src=a> x")   // a tag in a code span is kept
    }
}
