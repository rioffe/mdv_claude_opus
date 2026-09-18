import XCTest
import AppKit
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
}
