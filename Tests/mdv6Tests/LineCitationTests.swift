import XCTest
@testable import mdv6Core

/// C-19 line citations and the C-02 rule 8 source-line map (unit group of §9.0, test T-50).
final class LineCitationTests: XCTestCase {

    /// `test-docs/links-sibling.md`, the fixture T-49 and T-50 name (resolved from this file's path).
    private var fixture: ParsedDocument {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // Tests/mdv6Tests
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // repository root
        let url = root.appendingPathComponent("test-docs/links-sibling.md")
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return ParsedDocument(raw: text)
    }

    // MARK: C-02 rule 8 (T-50)

    /// C-02 rule 8, I-004, T-50: `blockLines` is half-open and 1-based, `blocks[i]` is exactly those source lines, and
    /// `lineCount` counts the normalised lines without inventing a final empty one.
    func testBlockLinesAreHalfOpenAndCounted() {
        let doc = ParsedDocument(raw: "# A\n\nfirst para\nsecond line\n\nthird para\n\n```\nunclosed")
        XCTAssertEqual(doc.blocks, ["# A", "first para\nsecond line", "third para", "```\nunclosed"])
        XCTAssertEqual(doc.blockLines, [1..<2, 3..<5, 6..<7, 8..<10])
        XCTAssertEqual(doc.lineCount, 9)

        // rule 6: a CRLF copy yields the same map as its LF equivalent
        let crlf = ParsedDocument(raw: "# A\r\n\r\nfirst para\r\nsecond line\r\n\r\nthird para\r\n\r\n```\r\nunclosed")
        XCTAssertEqual(crlf.blockLines, doc.blockLines)
        XCTAssertEqual(crlf.lineCount, doc.lineCount)

        // a trailing newline does not create a final empty line
        XCTAssertEqual(ParsedDocument(raw: "# A\n").lineCount, 1)
        XCTAssertEqual(ParsedDocument(raw: "# A\n").blockLines, [1..<2])

        // a document that opens with blank lines: the first block starts after them
        let lead = ParsedDocument(raw: "\n\n# A\n")
        XCTAssertEqual(lead.lineCount, 3)
        XCTAssertEqual(lead.blockLines, [3..<4])

        // an empty (or blank-only) document has no blocks and no lines to cite
        XCTAssertEqual(ParsedDocument(raw: "").lineCount, 0)
        XCTAssertEqual(ParsedDocument(raw: "").blockLines, [])
        XCTAssertEqual(ParsedDocument(raw: "   \n\n").blocks, [])

        // I-004: the map is derived from the same split that produced `blocks`
        for (i, range) in doc.blockLines.enumerated() {
            let lines = ParsedDocument.normalizeLineEndings(doc.raw)
                .split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            XCTAssertEqual(lines[(range.lowerBound - 1)..<(range.upperBound - 1)].joined(separator: "\n"),
                           ParsedDocument.parseBlocks(doc.raw)[i])
        }
    }

    // MARK: C-19.1 grammar (T-50)

    /// C-19.1, T-50: the anchored, case-insensitive grammar accepts the GitHub forms and rejects `#L0` (the leading digit
    /// must be 1…9), `#L00`, `#L`, `#L10C5`, `#Ll0`, `#L-5` and `#L10-`.
    func testLineCitationGrammar() {
        XCTAssertEqual(LineCitation.parse("L10"), LineCitation(first: 10, last: nil))
        XCTAssertEqual(LineCitation.parse("L10-L12"), LineCitation(first: 10, last: 12))
        XCTAssertEqual(LineCitation.parse("l10-l12"), LineCitation(first: 10, last: 12))
        XCTAssertEqual(LineCitation.parse("L10-12"), LineCitation(first: 10, last: 12))
        XCTAssertEqual(LineCitation.parse("L1"), LineCitation(first: 1, last: nil))
        XCTAssertEqual(LineCitation.parse("L70"), LineCitation(first: 70, last: nil))

        for rejected in ["L", "L0", "L00", "L0-L5", "L10-L0", "L10C5", "Ll0", "L-5", "L10-", "L10-L",
                         "", "example", "L10-L12-L14", "#L10"] {
            XCTAssertNil(LineCitation.parse(rejected), "\(rejected) is not a line citation (C-19.1)")
        }
    }

    /// C-19.2, T-50: the resolved start line is `min(first, last)`; the end is informational.
    func testRangeNormalisation() {
        XCTAssertEqual(LineCitation.parse("L9-L7")!.startLine, 7)
        XCTAssertEqual(LineCitation.parse("L7-L9")!.startLine, 7)
        XCTAssertEqual(LineCitation.parse("L7")!.startLine, 7)
        XCTAssertEqual(LineCitation.parse("L12-L10")!.startLine, 10)
    }

    // MARK: C-19.3 resolution, E-31 (T-50)

    /// C-19.3, E-31, T-50: the target is the last block whose first line is at or before the cited line; a line past
    /// `lineCount` or inside a removed gap clamps to the last such block; a line before the first block resolves to the
    /// first block; a document with no blocks has no target.
    func testResolution() {
        let doc = ParsedDocument(raw: "# A\n\nfirst para\nsecond line\n\nthird para")

        XCTAssertEqual(lineCitationBlock(LineCitation.parse("L1")!, in: doc), 0)      // the heading
        XCTAssertEqual(lineCitationBlock(LineCitation.parse("L4")!, in: doc), 1)      // inside the two-line paragraph
        XCTAssertEqual(lineCitationBlock(LineCitation.parse("L5")!, in: doc), 1)      // the blank line is not covered → the block before it
        XCTAssertEqual(lineCitationBlock(LineCitation.parse("L6")!, in: doc), 2)
        XCTAssertEqual(lineCitationBlock(LineCitation.parse("L99")!, in: doc), 2)     // past `lineCount` → the last block

        let lead = ParsedDocument(raw: "\n\n# A\n")
        XCTAssertEqual(lineCitationBlock(LineCitation.parse("L1")!, in: lead), 0)     // before the first block → the first block

        let empty = ParsedDocument(raw: "")
        XCTAssertNil(lineCitationBlock(LineCitation.parse("L1")!, in: empty))         // no blocks → nothing to flash
    }

    /// C-19, C-19.2, C-19.3, E-31, T-50: the `test-docs/links-sibling.md` map, line by line — the numbering T-49 states.
    func testFixtureLineMap() {
        let doc = fixture
        XCTAssertEqual(doc.lineCount, 11)
        XCTAssertEqual(doc.blocks, ["# Sibling",
                                    "Paragraph one of the sibling, linked from [links.md](links.md).",
                                    "## Second heading",
                                    "Paragraph under the second heading.",
                                    "## Third heading",
                                    "Paragraph under the third heading."])
        XCTAssertEqual(doc.blockLines, [1..<2, 3..<4, 5..<6, 7..<8, 9..<10, 11..<12])

        func target(_ fragment: String) -> Int? { lineCitationBlock(LineCitation.parse(fragment)!, in: doc) }
        XCTAssertEqual(target("L1"), 0)
        XCTAssertEqual(target("L7-L9"), 3)      // resolved by the start line: the paragraph
        XCTAssertEqual(target("L9-L7"), 3)      // a reversed range reads as named
        XCTAssertEqual(target("L9"), 4)
        XCTAssertEqual(target("L10"), 4)        // the blank line 10 → the heading above it
        XCTAssertEqual(target("L11"), 5)
        XCTAssertEqual(target("L12"), 5)        // past `lineCount = 11` → the last block
    }
}