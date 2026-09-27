import XCTest
@testable import mdv6Core

/// C-20 frontmatter recognition (C-20.1) and row reduction (C-20.2); E-32 rejections. T-52 (unit half).
final class FrontmatterTests: XCTestCase {

    private func fixture(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../test-docs/\(name)").standardizedFileURL
        return ParsedDocument.normalizeLineEndings(try String(contentsOf: url, encoding: .utf8))
    }

    /// C-20.1: byte-0 fence, exact closers (`---`/`...` YAML, `+++` TOML); the four fixtures. T-52, R-44.
    func testRecognitionOnFixtures() throws {
        let yaml = try XCTUnwrap(frontmatterSpan(in: try fixture("frontmatter.md")))
        XCTAssertTrue(yaml.block.hasPrefix("---\ntitle:"))
        XCTAssertTrue(yaml.block.hasSuffix("lamp_hours: 1096\n---"))
        XCTAssertEqual(yaml.closingLine, 20)

        let toml = try XCTUnwrap(frontmatterSpan(in: try fixture("frontmatter-toml.md")))
        XCTAssertTrue(toml.block.hasSuffix("]\n+++"))   // the array's `]` at column 0 does not end it

        let ellipsis = try XCTUnwrap(frontmatterSpan(in: try fixture("frontmatter-ellipsis-close.md")))
        XCTAssertTrue(ellipsis.block.hasSuffix("depth_m: 61\n..."))

        XCTAssertNil(frontmatterSpan(in: try fixture("frontmatter-negative.md")))   // E-32
    }

    /// C-20.1 / E-32: the exact-line rules and the YAML content guard.
    func testRecognitionRules() {
        XCTAssertNil(frontmatterSpan(in: " ---\na: b\n---\n"))            // leading space
        XCTAssertNil(frontmatterSpan(in: "--- \na: b\n---\n"))            // trailing space
        XCTAssertNil(frontmatterSpan(in: "\n---\na: b\n---\n"))           // not byte 0
        XCTAssertNil(frontmatterSpan(in: "---\na: b\n"))                  // no closer (E-32)
        XCTAssertNil(frontmatterSpan(in: "---\na: b\n  ---\n"))           // indented closer is not a closer
        XCTAssertNil(frontmatterSpan(in: "---\nsee http://example.com\n---\n"))   // no mapping colon
        XCTAssertNil(frontmatterSpan(in: "---\nTODO: x\na sentence here.\n---\n"))  // one prose line fails
        XCTAssertNotNil(frontmatterSpan(in: "---\nurl: http://example.com\n---\n"))
        XCTAssertNotNil(frontmatterSpan(in: "---\n- item\n---\n"))        // a sequence item
        XCTAssertNotNil(frontmatterSpan(in: "---\na: b\n  anything: at all. really\n---\n"))  // continuation
        XCTAssertNotNil(frontmatterSpan(in: "+++\nprose, no guard\n+++\n")) // TOML: no guard
    }

    /// C-20.1 zero-row rule (F-150, E-32): a candidate with no rows is not a header.
    func testZeroRowCandidateIsNotAHeader() {
        XCTAssertNil(frontmatterSpan(in: "---\n\n# Title\n\n---\n\nbody\n"))
        XCTAssertNil(frontmatterSpan(in: "---\n---\n"))
        let doc = ParsedDocument(raw: "---\n\n# Title\n\n---\n\nbody\n")
        XCTAssertNil(doc.frontmatter)
        XCTAssertEqual(doc.tocHeadings.map(\.text), ["Title"])
    }

    /// C-20.2: YAML rows — quotes stripped, `>-` folded, sequences and nested mappings kept verbatim, dedented.
    func testYAMLRows() throws {
        let span = try XCTUnwrap(frontmatterSpan(in: try fixture("frontmatter.md")))
        let rows = frontmatterRows(span.block)
        XCTAssertEqual(rows.map(\.key), ["title", "date", "author", "status", "summary", "tags", "metadata"])
        XCTAssertEqual(rows[0].value, "The Lighthouse Keeper's Inventory")
        XCTAssertEqual(rows[4].value, "A folded scalar, which is why this value runs across several source lines and still counts as one string. Folded summaries are the usual reason a metadata header is taller than a couple of lines.")
        XCTAssertEqual(rows[5].value, "- lighthouses\n- fog\n- inventory")
        XCTAssertEqual(rows[6].value, "edition: 3\nreviewed: true\nstation:\n  bearing: 214\n  lamp_hours: 1096")
    }

    /// C-20.2: `|` keeps breaks, `>` folds with a blank line as a real break, a scalar followed by a group, keyless rows.
    func testYAMLScalarForms() {
        let rows = frontmatterRows("---\nkeep: |\n  a\n  b\nfold: >\n  a\n  b\n\n  c\nmixed: head\n  tail\n- loose\n---")
        XCTAssertEqual(rows, [
            FrontmatterRow(key: "keep", value: "a\nb"),
            FrontmatterRow(key: "fold", value: "a b\nc"),
            FrontmatterRow(key: "mixed", value: "head\ntail"),
            FrontmatterRow(key: nil, value: "- loose"),
        ])
        XCTAssertEqual(frontmatterRows("---\n'q': \"v\"\n---"), [FrontmatterRow(key: "q", value: "v")])
    }

    /// C-20.2: TOML rows — `[section]` keys, `=` pairs, bracket depth ignoring quotes, comments skipped.
    func testTOMLRows() throws {
        let span = try XCTUnwrap(frontmatterSpan(in: try fixture("frontmatter-toml.md")))
        let rows = frontmatterRows(span.block)
        XCTAssertEqual(rows.first, FrontmatterRow(key: "title", value: "Semaphore Timetable"))
        XCTAssertTrue(rows.contains(FrontmatterRow(key: "[station]", value: "")))
        XCTAssertTrue(rows.contains(FrontmatterRow(key: "name", value: "Relay Tower 12")))
        XCTAssertEqual(rows.last, FrontmatterRow(key: "tags", value: "[\n  \"signals\",\n  \"timetables\",\n  \"relay-towers\",\n]"))   // dedent by the group's smallest indent: `]` is at 0
        XCTAssertEqual(frontmatterRows("+++\nname = \"Tower [12]\"\n# c\n+++"), [FrontmatterRow(key: "name", value: "Tower [12]")])
    }
}
