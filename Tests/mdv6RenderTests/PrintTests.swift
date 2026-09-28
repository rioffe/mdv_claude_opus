import XCTest
import AppKit
import PDFKit
@testable import mdv6Core

/// C-21 / R-45 / I-017 / K-17 / E-33 through `PrintController.renderPDF` — the same pipeline the print panel runs — with
/// T-53's scripted oracles computed from the output PDF itself (PDFKit text, the page content stream's image draws).
@MainActor
final class PrintTests: XCTestCase {

    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../..").standardizedFileURL
    let letter = CGSize(width: 612, height: 792)

    private func request(_ path: String, show: Bool = true, raw: String? = nil) throws -> PrintRequest {
        let url = Self.root.appendingPathComponent(path)
        let text = try raw ?? String(contentsOf: url, encoding: .utf8)
        return PrintRequest(document: ParsedDocument(raw: text), baseURL: url.deletingLastPathComponent(), smartTypography: false,
                            showFrontmatter: show, mermaidStyle: .document, jobTitle: url.lastPathComponent)
    }

    private func pdfDocument(_ out: PrintOutput) throws -> PDFDocument { try XCTUnwrap(PDFDocument(data: out.pdf)) }

    private func rect(_ r: [CGFloat]) -> CGRect { CGRect(x: r[0], y: r[1], width: r[2], height: r[3]) }

    /// The image draws of one page, from its content stream (independent of the records the controller wrote).
    private func images(_ doc: PDFDocument, page: Int) -> [PDFImagePlacement] {
        guard let p = doc.page(at: page - 1)?.pageRef else { return [] }
        return PDFImageScan.placements(in: p)
    }

    /// T-53 (1) vector text: every prose block's C-12-stripped tokens appear, in order, in the text PDFKit extracts from
    /// that block's rect (`rhythm.md`: plain headings and paragraphs, F-175). C-21.2, R-45.
    func testVectorText() async throws {
        let out = await PrintController.renderPDF(try request("test-docs/rhythm.md"), paper: letter)
        let doc = try pdfDocument(out)
        let blocks = ParsedDocument(raw: try String(contentsOf: Self.root.appendingPathComponent("test-docs/rhythm.md"), encoding: .utf8)).blocks
        XCTAssertEqual(out.blocks.map(\.index), Array(0 ..< blocks.count))
        for r in out.blocks where r.kind == "prose" {
            let text = doc.page(at: r.page - 1)?.selection(for: rect(r.rect).insetBy(dx: -1, dy: -1))?.string ?? ""
            let tokens = stripInlineMarkdown(blocks[r.index].replacingOccurrences(of: "#", with: "")).split(whereSeparator: \.isWhitespace).map(String.init)
            var rest = Substring(text)
            for t in tokens {
                guard let found = rest.range(of: t) else { return XCTFail("block \(r.index): '\(t)' not in extracted text '\(text)'") }
                rest = rest[found.upperBound...]
            }
        }
    }

    /// T-53 (2) / (2b), R-45, C-21.4 (F-176): no accepted formula's rect holds an image draw; a rejected one does (its E-10
    /// fallback printed, not dropped).
    func testVectorFormulas() async throws {
        let out = await PrintController.renderPDF(try request("test-docs/math.md"), paper: letter)
        let doc = try pdfDocument(out)
        var accepted = 0, rejected = 0
        for r in out.blocks {
            let placed = images(doc, page: r.page).filter { $0.pixels != CGSize(width: 1, height: 1) }.map(\.rect)   // F-184: the 1-pixel spacer
            for f in r.formulas {
                let box = rect(f.rect).insetBy(dx: 0.5, dy: 0.5)
                let hit = placed.contains { $0.intersects(box) }
                if f.accepted { accepted += 1; XCTAssertFalse(hit, "block \(r.index): an accepted formula printed as an image") }
                else { rejected += 1; XCTAssertTrue(hit, "block \(r.index): a rejected formula printed nothing") }
            }
        }
        XCTAssertGreaterThan(accepted, 10)
        XCTAssertGreaterThan(rejected, 0, "math.md's Errors section carries rejected spans")
    }

    /// T-53 (3) pagination, C-21.5: a block no taller than a page is on one page; a taller one is sliced into two records.
    func testPagination() async throws {
        let out = await PrintController.renderPDF(try request("test-docs/math.md"), paper: letter)
        let printable = letter.height - 2 * PrintScale.margin
        for i in Set(out.blocks.map(\.index)) {
            let parts = out.blocks.filter { $0.index == i }
            if parts.map({ $0.rect[3] }).reduce(0, +) <= printable { XCTAssertEqual(parts.count, 1, "block \(i) was sliced") }
        }
        let tall = "```\n" + (1 ... 160).map { "line \($0)" }.joined(separator: "\n") + "\n```\n\nafter"
        let t = await PrintController.renderPDF(try request("test-docs/rhythm.md", raw: tall), paper: letter)
        XCTAssertGreaterThanOrEqual(t.blocks.filter { $0.index == 0 }.count, 2, "a block taller than a page is sliced")
        XCTAssertEqual(t.blocks.filter { $0.index == 1 }.count, 1)
    }

    /// T-53 (4) rhythm, C-21.2, I-014 (F-160): the gap between consecutive blocks on a page is s_p × the screen's gap for
    /// that pair under the print theme, within 1 pt.
    func testPrintedRhythm() async throws {
        let req = try request("test-docs/rhythm.md")
        let out = await PrintController.renderPDF(req, paper: letter)
        let sp = PrintScale.sp(contentWidth: PrintScale.contentWidth(paperWidth: letter.width), articleMaxWidth: MDVTheme.highContrast.articleMaxWidth)
        let blocks = req.document.blocks
        for (a, b) in zip(out.blocks, out.blocks.dropFirst()) where a.page == b.page && b.index == a.index + 1 {
            let gap = rect(a.rect).minY - rect(b.rect).maxY                  // PDF space: y grows upward
            let want = sp * ArticleBlockView<StaticArticleHost>.blockInset(theme: .highContrast, previous: blocks[a.index], current: blocks[b.index])
            XCTAssertEqual(gap, want, accuracy: 1, "gap \(a.index)→\(b.index)")
        }
    }

    /// T-53 (5) wrapping, C-21.2: no code block's text lies outside the content width.
    func testCodeWraps() async throws {
        let long = "```swift\nlet s = \"" + String(repeating: "wrap-me ", count: 60) + "\"\n```"
        let out = await PrintController.renderPDF(try request("test-docs/syntax.md", raw: long), paper: letter)
        let doc = try pdfDocument(out)
        let right = letter.width - PrintScale.margin
        for r in out.blocks where r.kind == "code" {
            XCTAssertLessThanOrEqual(rect(r.rect).maxX, right + 0.5)
            let outside = CGRect(x: right + 1, y: rect(r.rect).minY, width: PrintScale.margin - 2, height: rect(r.rect).height)
            XCTAssertEqual(doc.page(at: r.page - 1)?.selection(for: outside)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "", "")
            XCTAssertTrue((doc.page(at: r.page - 1)?.selection(for: rect(r.rect))?.string ?? "").contains("wrap-me"))
        }
        XCTAssertEqual(out.blocks.filter { $0.kind == "code" }.count, 1)
    }

    /// T-53 (6) diagrams, C-21.3: each natively dispatched raw `.mmd` prints a `diagram` block with no image draw in its
    /// rect and extractable label text.
    func testNativeDiagramsPrintAsVector() async throws {
        let dir = Self.root.appendingPathComponent("test-docs/mermaid")
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".mmd") }.sorted()
        var checked = 0
        for f in files {
            let source = try String(contentsOf: dir.appendingPathComponent(f), encoding: .utf8)
            guard MermaidDispatch.isNative(source) else { continue }
            let out = await PrintController.renderPDF(try request("test-docs/mermaid/\(f)", raw: "```mermaid\n\(source)\n```"), paper: letter)
            let doc = try pdfDocument(out)
            let r = try XCTUnwrap(out.blocks.first, f)
            XCTAssertEqual(r.kind, "diagram", f)
            XCTAssertFalse(images(doc, page: r.page).contains { $0.rect.intersects(rect(r.rect).insetBy(dx: 1, dy: 1)) }, "\(f): the diagram printed as an image")
            XCTAssertFalse((doc.page(at: r.page - 1)?.selection(for: rect(r.rect))?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(f): no label text")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 5)
    }

    /// T-53 (7), C-21.6, R-44: the header prints as its table when shown and not at all when hidden.
    func testFrontmatterPrints() async throws {
        let shown = await PrintController.renderPDF(try request("test-docs/frontmatter.md"), paper: letter)
        XCTAssertEqual(shown.blocks.first?.kind, "frontmatter")
        let hidden = await PrintController.renderPDF(try request("test-docs/frontmatter.md", show: false), paper: letter)
        XCTAssertFalse(hidden.blocks.contains { $0.kind == "frontmatter" })
        XCTAssertEqual(hidden.blocks.first?.index, 1)
    }

    /// T-53 (8), I-017, K-17: printing from a session at zoom 1.0 and 1.5 and under `sevilla` and `twilight` yields
    /// identical extracted text and block rects (the request carries no screen state; the theme is `high-contrast`).
    func testIndependentOfScreenState() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-print-\(UUID().uuidString)")
        let suite = "mdv6.print.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: dir) }
        let model = AppModel.bootstrap(supportDir: dir, defaultsSuite: suite)
        let session = DocumentSession(model: model)
        session.open(Self.root.appendingPathComponent("test-docs/rhythm.md"), route: .adding)
        var outputs: [(String, [[CGFloat]])] = []
        for (zoom, theme) in [(1.0, "sevilla"), (1.5, "twilight")] {
            model.preferences.fontScale = zoom; model.preferences.themeId = theme
            let req = try XCTUnwrap(session.printRequest())
            let out = await PrintController.renderPDF(req, paper: letter)
            let text = (try pdfDocument(out)).string ?? ""
            outputs.append((text, out.blocks.map(\.rect)))
        }
        XCTAssertEqual(outputs[0].0, outputs[1].0)
        for (a, b) in zip(outputs[0].1, outputs[1].1) { for (x, y) in zip(a, b) { XCTAssertEqual(x, y, accuracy: 0.5) } }
    }

    /// E-33, R-45: no document, or one with no blocks, has nothing to print.
    func testNothingToPrint() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-print-\(UUID().uuidString)")
        let suite = "mdv6.print.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: dir) }
        let model = AppModel.bootstrap(supportDir: dir, defaultsSuite: suite)
        let session = DocumentSession(model: model)
        XCTAssertNil(session.printRequest())
        let empty = dir.appendingPathComponent("e.md")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "  \n\n".write(to: empty, atomically: true, encoding: .utf8)
        session.open(empty, route: .adding)
        XCTAssertNil(session.printRequest())
    }
}
