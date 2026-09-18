import XCTest
@testable import mdv6Core

/// C-08 fingerprints and anchor resolution, K-09, E-08, and the R-27 bookmark-title rule (unit group of §9.0).
final class AnchorTests: XCTestCase {

    /// C-08, K-09, D-35: whitespace (tabs, CRLF, NBSP, repeated spaces) normalises to single U+0020; locale-independent
    /// lowercase; canonically equivalent but byte-distinct sequences stay distinct; 80 extended grapheme clusters. T-26.
    func testFingerprintNormalisation() {
        XCTAssertEqual(bookmarkFingerprint("Hello\t\tWorld\r\nAgain\u{00A0}x   y"), "hello world again x y")
        XCTAssertEqual(bookmarkFingerprint("  lead and trail  "), "lead and trail")
        XCTAssertEqual(bookmarkFingerprint("İSTANBUL"), "İSTANBUL".lowercased())
        XCTAssertNotEqual(bookmarkFingerprint("İ"), bookmarkFingerprint("I"))
        let precomposed = "\u{00E9}"            // é
        let decomposed = "e\u{0301}"            // e + combining acute
        XCTAssertFalse(fingerprintsEqual(bookmarkFingerprint(precomposed), bookmarkFingerprint(decomposed)))
        XCTAssertTrue(fingerprintsEqual(bookmarkFingerprint("A b"), "a b"))
        let flags = String(repeating: "\u{1F1FA}\u{1F1F8}", count: 100)   // 100 flag clusters
        XCTAssertEqual(bookmarkFingerprint(flags).count, 80)
        let family = String(repeating: "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}", count: 90)
        XCTAssertEqual(bookmarkFingerprint(family).count, 80)
        XCTAssertEqual(bookmarkFingerprint(String(repeating: "a", count: 200)).count, 80)
        XCTAssertEqual(bookmarkFingerprint(""), "")
    }

    /// C-08, E-08: resolve by fingerprint first, then the clamped index, then 0 for an empty document. T-26.
    func testResolveAnchor() {
        let blocks = ["# A", "para one", "para two", "para three"]
        XCTAssertEqual(resolveBookmarkAnchor(blocks: blocks, storedIndex: 1, fingerprint: bookmarkFingerprint("para three")), 3)
        XCTAssertEqual(resolveBookmarkAnchor(blocks: blocks, storedIndex: 2, fingerprint: "no such"), 2)
        XCTAssertEqual(resolveBookmarkAnchor(blocks: blocks, storedIndex: 99, fingerprint: "no such"), 3)
        XCTAssertEqual(resolveBookmarkAnchor(blocks: blocks, storedIndex: -5, fingerprint: "no such"), 0)
        XCTAssertEqual(resolveBookmarkAnchor(blocks: [], storedIndex: 4, fingerprint: "x"), 0)
        // insert content above: fingerprint still lands on the block
        let shifted = ["intro"] + blocks
        XCTAssertEqual(resolveBookmarkAnchor(blocks: shifted, storedIndex: 2, fingerprint: bookmarkFingerprint("para two")), 3)
    }

    /// C-08, E-08, K-06: a scroll position is restored only when the mtime is within 1 s and the index is in bounds.
    func testScrollRestorable() {
        XCTAssertTrue(AnchorValidity.scrollRestorable(storedMtime: 1000, fileMtime: 1000, index: 3, count: 10))
        XCTAssertTrue(AnchorValidity.scrollRestorable(storedMtime: 1000, fileMtime: 1001, index: 3, count: 10))
        XCTAssertFalse(AnchorValidity.scrollRestorable(storedMtime: 1000, fileMtime: 1002, index: 3, count: 10))
        XCTAssertFalse(AnchorValidity.scrollRestorable(storedMtime: 1000, fileMtime: 1000, index: 10, count: 10))
        XCTAssertFalse(AnchorValidity.scrollRestorable(storedMtime: 1000, fileMtime: 1000, index: 0, count: 0))
        XCTAssertEqual(AnchorValidity.mtimeTolerance, 1)
    }

    /// R-27, K-06, C-12, C-07.3: title = nearest TOC heading within 40 blocks (display text), else the stripped first line
    /// truncated to 60 clusters, else `(line n)`, else `(empty)`. T-26, T-08.
    func testBookmarkTitle() {
        var lines = ["## _Draft_ $\\pi$ notes"]
        lines += (0..<39).map { "para \($0)" }
        lines.append("target paragraph")                     // 40 blocks after the heading
        lines.append("beyond **look-back** [link](u) " + String(repeating: "x", count: 100))
        lines.append("")
        let doc = ParsedDocument(raw: lines.joined(separator: "\n\n"))
        let toc = doc.tocHeadings
        XCTAssertEqual(BookmarkTitle.title(blocks: doc.blocks, toc: toc, index: 40), "Draft π notes")
        let beyond = BookmarkTitle.title(blocks: doc.blocks, toc: toc, index: 41)
        XCTAssertEqual(beyond.count, 60)
        XCTAssertTrue(beyond.hasPrefix("beyond look-back link "))
        XCTAssertEqual(BookmarkTitle.title(blocks: ["**", "x"], toc: [], index: 0), "(line 1)")
        XCTAssertEqual(BookmarkTitle.title(blocks: ["a\nb", "x"], toc: [], index: 0), "a")
        XCTAssertEqual(BookmarkTitle.title(blocks: [], toc: [], index: 0), "(empty)")
        let emoji = String(repeating: "\u{1F1FA}\u{1F1F8}", count: 70)
        XCTAssertEqual(BookmarkTitle.title(blocks: [emoji], toc: [], index: 0).count, 60)
        XCTAssertEqual(BookmarkTitle.lookBack, 40)
        XCTAssertEqual(BookmarkTitle.maxClusters, 60)
    }
}
