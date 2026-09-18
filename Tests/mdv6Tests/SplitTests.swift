import XCTest
@testable import mdv6Core

/// C-02 block split, C-11 slugs, C-12 sections and inline stripping (unit group of §9.0).
final class SplitTests: XCTestCase {

    // MARK: C-02 rules

    /// C-02 rule 1 and 5: blank lines end blocks; leading/trailing newlines trimmed; empties dropped. T-39, R-04.
    func testBlankLineSplitsAndEmptiesDropped() {
        let blocks = ParsedDocument.parseBlocks("# Title\n\n\n\nfirst para\nline two\n   \nsecond\n\n")
        XCTAssertEqual(blocks, ["# Title", "first para\nline two", "second"])
        XCTAssertEqual(ParsedDocument.parseBlocks(""), [])
        XCTAssertEqual(ParsedDocument.parseBlocks("   \n\n  \n"), [])
    }

    /// C-02 rule 2, E-23: a fence keeps its blank lines and closes on any run of the same three-character marker. T-39.
    func testFenceKeepsBlankLinesAndClosesOnSameMarker() {
        let src = "before\n\n```swift\nlet a = 1\n\nlet b = 2\n```\n\nafter"
        XCTAssertEqual(ParsedDocument.parseBlocks(src), ["before", "```swift\nlet a = 1\n\nlet b = 2\n```", "after"])
        // E-23: a ```` block containing a ``` line closes at that ``` line (the run is not required to match in
        // length); the later ```` line then opens a new fence that swallows the blank line and runs to the end.
        let four = "````\ncode\n```\nstill?\n````\n\nnext"
        XCTAssertEqual(ParsedDocument.parseBlocks(four), ["````\ncode\n```\nstill?\n````\n\nnext"])
        XCTAssertEqual(ParsedDocument.parseBlocks("````\ncode\n```\n\nafter"), ["````\ncode\n```", "after"])
        // E-23: an unclosed fence runs to the end of the input.
        XCTAssertEqual(ParsedDocument.parseBlocks("```\na\n\nb\n"), ["```\na\n\nb"])
        // ~~~ fences close only on ~~~, not on ```; the line after the closer joins the block (rule 1).
        XCTAssertEqual(ParsedDocument.parseBlocks("~~~\nx\n```\n\ny\n~~~\nz"), ["~~~\nx\n```\n\ny\n~~~\nz"])
        XCTAssertEqual(ParsedDocument.parseBlocks("~~~\nx\n```\n\ny\n~~~\n\nz"), ["~~~\nx\n```\n\ny\n~~~", "z"])
        // A fence opener may be indented; only newlines are trimmed (rule 5), and a line right after the closing
        // marker still belongs to the block (only a blank line ends a block, rule 1).
        XCTAssertEqual(ParsedDocument.parseBlocks("  ```\n\n  ```\np"), ["  ```\n\n  ```\np"])
    }

    /// C-02 rule 3: a `$$` math fence opens on a line whose first non-space text is `$$` with no second `$$` and closes at the next line containing `$$`. T-39.
    func testMathFenceSpansBlankLines() {
        let src = "$$\na = b\n\nc = d\n$$\n\nnext\n\n$$x$$\n\nlast"
        XCTAssertEqual(ParsedDocument.parseBlocks(src), ["$$\na = b\n\nc = d\n$$", "next", "$$x$$", "last"])
        XCTAssertEqual(ParsedDocument.parseBlocks("$$\nunclosed\n\nstill"), ["$$\nunclosed\n\nstill"])
        XCTAssertTrue(ParsedDocument.isMathFence("$$\na\n$$"))
        XCTAssertFalse(ParsedDocument.isMathFence("$$x$$"))
    }

    /// C-02 rule 4, E-23: an indented code block containing a blank line is split into two blocks. T-39.
    func testIndentedCodeBlockSplitsAtBlankLine() {
        XCTAssertEqual(ParsedDocument.parseBlocks("    a\n\n    b"), ["    a", "    b"])
    }

    /// C-02 rule 6: CRLF and lone CR yield the same blocks and TOC as LF. T-39.
    func testLineEndingsNormalised() {
        let lf = "# A\n\npara\n\n## B\n\n```\nx\n\ny\n```"
        let crlf = lf.replacingOccurrences(of: "\n", with: "\r\n")
        let cr = lf.replacingOccurrences(of: "\n", with: "\r")
        XCTAssertEqual(ParsedDocument(raw: crlf).blocks, ParsedDocument(raw: lf).blocks)
        XCTAssertEqual(ParsedDocument(raw: cr).blocks, ParsedDocument(raw: lf).blocks)
        XCTAssertEqual(ParsedDocument(raw: crlf).tocHeadings, ParsedDocument(raw: lf).tocHeadings)
        XCTAssertEqual(ParsedDocument(raw: crlf).blocks.count, 4)
    }

    /// C-02 rule 7, E-22, I-010: only single-line ATX `#`–`###` headings outside fences; `text` is stripped and math-converted (C-07.3), `slugText` stripped only. T-08.
    func testTOCHeadings() {
        let src = "# One\n\n#### four\n\nSetext\n===\n\n```\n# not a heading\n```\n\n## Two with $\\pi$ in it\n\n### _Draft_ notes\n\n## snake_case_name\n\n##No space\n\n# Multi\nline heading?"
        let doc = ParsedDocument(raw: src)
        let toc = doc.tocHeadings
        XCTAssertEqual(toc.map(\.level), [1, 2, 3, 2, 1])
        XCTAssertEqual(toc.map(\.text), ["One", "Two with π in it", "Draft notes", "snake_case_name", "Multi"])
        XCTAssertEqual(toc.map(\.slugText), ["One", "Two with $\\pi$ in it", "Draft notes", "snake_case_name", "Multi"])
        XCTAssertEqual(toc.map(\.blockIndex), [0, 4, 5, 6, 8])
        XCTAssertEqual(doc.blocks[toc[1].blockIndex], "## Two with $\\pi$ in it")
    }

    /// I-004: equality on `raw`; the split is a pure function of the input.
    func testEqualityOnRaw() {
        XCTAssertEqual(ParsedDocument(raw: "a\n\nb"), ParsedDocument(raw: "a\n\nb"))
        XCTAssertNotEqual(ParsedDocument(raw: "a"), ParsedDocument(raw: "b"))
    }

    /// C-02 helpers used by find (R-24, E-17): fence, math fence, GFM table detection.
    func testBlockKindHelpers() {
        XCTAssertTrue(ParsedDocument.isFence("```\nx\n```"))
        XCTAssertTrue(ParsedDocument.isFence("~~~py\nx"))
        XCTAssertFalse(ParsedDocument.isFence("text ```"))
        XCTAssertTrue(ParsedDocument.isGFMTable("| a | b |\n|---|:--:|\n| 1 | 2 |"))
        XCTAssertFalse(ParsedDocument.isGFMTable("| a | b |\nno separator"))
        XCTAssertFalse(ParsedDocument.isGFMTable("a | b"))
    }

    // MARK: C-11 slugs

    /// C-11, I-010, D-20: GitHub-compatible slugs; every whitespace run becomes one `-` when something precedes it. T-22.
    func testHeadingSlug() {
        XCTAssertEqual(headingSlug("Hello World"), "hello-world")
        XCTAssertEqual(headingSlug("a - b"), "a---b")
        XCTAssertEqual(headingSlug("C++ & Rust"), "c--rust")
        XCTAssertEqual(headingSlug("Draft notes"), "draft-notes")
        XCTAssertEqual(headingSlug("snake_case_name"), "snake_case_name")
        XCTAssertEqual(headingSlug("  leading and trailing  "), "leading-and-trailing")
        XCTAssertEqual(headingSlug("Trailing-"), "trailing")
        XCTAssertEqual(headingSlug("_under"), "under")
        XCTAssertEqual(headingSlug("Ünïcödé 日本"), "ünïcödé-日本")
        XCTAssertEqual(headingSlug("4.3.1 Principal"), "431-principal")
        XCTAssertEqual(headingSlug("!!!"), "")
    }

    // MARK: C-12 sections and stripping

    /// C-12: `stripInlineMarkdown` removes trailing `#`s, `**`, `__`, backticks, unescaped `*`, `_…_` pairs not preceded by a letter/digit, and reduces links. T-08.
    func testStripInlineMarkdown() {
        XCTAssertEqual(stripInlineMarkdown("_Draft_ notes"), "Draft notes")
        XCTAssertEqual(stripInlineMarkdown("snake_case_name"), "snake_case_name")
        XCTAssertEqual(stripInlineMarkdown("**bold** and __bold__ and *em* and `code`"), "bold and bold and em and code")
        XCTAssertEqual(stripInlineMarkdown("[text](https://x.y/z) tail"), "text tail")
        XCTAssertEqual(stripInlineMarkdown("Closing ##"), "Closing")
        XCTAssertEqual(stripInlineMarkdown("a \\* b"), "a * b")
        XCTAssertEqual(stripInlineMarkdown("some snake_case_name here"), "some snake_case_name here")
        XCTAssertEqual(stripInlineMarkdown("a \\pi b"), "a \\pi b")
    }

    /// C-12: a section runs to the next TOC heading of level ≤ its own; h4–h6 never end a section. T-30.
    func testSectionRange() {
        let src = "# A\n\np1\n\n## B\n\np2\n\n#### deep\n\np3\n\n### C\n\np4\n\n## D\n\np5"
        let doc = ParsedDocument(raw: src)
        let b = doc.tocHeadings.first { $0.text == "B" }!.blockIndex
        XCTAssertEqual(sectionRange(blocks: doc.blocks, tocHeadings: doc.tocHeadings, headingAt: b), 2..<8)
        let c = doc.tocHeadings.first { $0.text == "C" }!.blockIndex
        XCTAssertEqual(sectionRange(blocks: doc.blocks, tocHeadings: doc.tocHeadings, headingAt: c), 6..<8)
        let d = doc.tocHeadings.first { $0.text == "D" }!.blockIndex
        XCTAssertEqual(sectionRange(blocks: doc.blocks, tocHeadings: doc.tocHeadings, headingAt: d), 8..<10)
        XCTAssertEqual(sectionMarkdown(blocks: doc.blocks, tocHeadings: doc.tocHeadings, headingAt: d), "## D\n\np5")
        XCTAssertEqual(sectionRange(blocks: doc.blocks, tocHeadings: doc.tocHeadings, headingAt: 0), 0..<10)
    }
}
