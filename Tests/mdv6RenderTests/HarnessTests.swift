import XCTest
import AppKit
@testable import mdv6Core

/// C-17 / R-39 through `HarnessRunner` (what `tools/render-harness` links): discovery order, fallback classification,
/// manifest rules, the metric cases, exit conditions, and determinism (I-001, E-25 via the pipeline; T-13, T-17, T-19).
@MainActor
final class HarnessTests: XCTestCase {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    var out: URL!

    override func setUp() {
        out = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-harness-\(UUID().uuidString)")
    }
    override func tearDown() { try? FileManager.default.removeItem(at: out) }

    /// T-13, C-17, R-39: `--scan` discovers every raw `.mmd` and every Mermaid fence in `.md`, ordered by UTF-8 bytes of the
    /// relative path then fence index; E-02 unsupported types report `fallback`, everything else `pass`; a second run
    /// yields identical records and identical PNG bytes (I-001) — a stale layout can never be shown for another case (E-25).
    func testScanCorpusOrderAndDeterminism() throws {
        let corpus = Self.root.appendingPathComponent("test-docs/mermaid")
        let cases = HarnessRunner.scan(root: corpus)
        XCTAssertEqual(cases.map(\.id), ["class.mmd", "er.mmd", "fences.md#0", "fences.md#1", "flowchart.mmd", "math.mmd", "sanitised.mmd",
                                          "sequence.mmd", "state.mmd", "two-subgraphs.mmd", "unsupported-gantt.mmd", "unsupported-mindmap.mmd",
                                          "unsupported-pie.mmd", "unsupported-timeline.mmd", "xychart.mmd"])
        XCTAssertEqual(Set(cases.map(\.outputName)).count, cases.count, "collision-free outputs")
        let first = try HarnessRunner.runScan(root: corpus, outputDir: out.appendingPathComponent("a"))
        XCTAssertEqual(first.map(\.status.rawValue), ["pass", "pass", "pass", "fallback", "pass", "pass", "pass", "pass", "pass", "pass", "fallback", "fallback", "fallback", "fallback", "pass"])
        let second = try HarnessRunner.runScan(root: corpus, outputDir: out.appendingPathComponent("b"))
        XCTAssertEqual(first.map { ($0.id, $0.status) }.map { "\($0.0):\($0.1)" }, second.map { "\($0.id):\($0.status)" })
        for r in first where r.status == .pass {
            let a = FileManager.default.contents(atPath: r.output!)!
            let b = FileManager.default.contents(atPath: r.output!.replacingOccurrences(of: "/a/", with: "/b/"))!
            XCTAssertEqual(a, b, "\(r.id) byte-identical on repeat")
        }
        XCTAssertFalse(first.contains { $0.status == .fail })
        // JSON record shape: id, status, output
        let json = try JSONSerialization.jsonObject(with: Data(first[0].json.utf8)) as! [String: Any]
        XCTAssertEqual(Set(json.keys), ["id", "status", "output"])
    }

    /// C-17: the manifest is version-1 JSON with unique ids; unknown keys are ignored; an unknown `--case` is an error.
    func testManifestRules() throws {
        let manifest = try HarnessRunner.loadManifest(Self.root.appendingPathComponent("test-docs/render-cases.json"))
        XCTAssertEqual(manifest.version, 1)
        XCTAssertTrue(manifest.cases.contains { $0.id == "mermaid-math-ink" && $0.metric == .ink })
        XCTAssertTrue(manifest.cases.contains { $0.id == "sequence-layout" && $0.metric == .sequenceLayout })
        XCTAssertThrowsError(try HarnessRunner.runCheck(manifest: manifest, root: Self.root, outputDir: out, only: "nope")) { e in
            XCTAssertEqual(e as? HarnessError, .unknownCase("nope"))
        }
        let dup = out.appendingPathComponent("dup.json")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        try Data("{\"version\":1,\"cases\":[{\"id\":\"x\",\"input\":\"a\",\"kind\":\"mermaid\"},{\"id\":\"x\",\"input\":\"b\",\"kind\":\"mermaid\"}]}".utf8).write(to: dup)
        XCTAssertThrowsError(try HarnessRunner.loadManifest(dup))
        let v2 = out.appendingPathComponent("v2.json")
        try Data("{\"version\":2,\"cases\":[]}".utf8).write(to: v2)
        XCTAssertThrowsError(try HarnessRunner.loadManifest(v2))
    }

    /// T-17 (ink), T-19 (sequence-layout), T-45 (rhythm), T-46 (display-math): the manifest's metric cases pass through the
    /// same code the harness runs; the fallback cases report `fallback`.
    func testMetricCasesPass() throws {
        let manifest = try HarnessRunner.loadManifest(Self.root.appendingPathComponent("test-docs/render-cases.json"))
        for id in ["mermaid-math-ink", "sequence-layout", "rhythm-sevilla", "rhythm-charcoal", "display-math-single-vs-fence", "unsupported-pie"] {
            let r = try HarnessRunner.runCheck(manifest: manifest, root: Self.root, outputDir: out, only: id)
            XCTAssertEqual(r.count, 1)
            XCTAssertEqual(r[0].status, id.hasPrefix("unsupported") ? .fallback : .pass, "\(id): \(r[0].diagnostics)")
        }
    }

    /// C-17: `INPUT --output FILE` — the output's parent must exist (never created); an unknown theme is a usage error;
    /// an unreadable input is an error; a raw `.mmd` and a `.md` both render.
    func testRenderOneConditions() throws {
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let md = Self.root.appendingPathComponent("test-docs/rhythm.md")
        XCTAssertTrue(try HarnessRunner.renderOne(input: md, output: out.appendingPathComponent("r.png"), width: 860, scale: 2, themeId: "sevilla"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.appendingPathComponent("r.png").path))
        let mmd = Self.root.appendingPathComponent("test-docs/mermaid/flowchart.mmd")
        XCTAssertTrue(try HarnessRunner.renderOne(input: mmd, output: out.appendingPathComponent("m.png"), width: 860, scale: 2, themeId: "high-contrast"))
        XCTAssertFalse(try HarnessRunner.renderOne(input: Self.root.appendingPathComponent("test-docs/mermaid/unsupported-pie.mmd"), output: out.appendingPathComponent("p.png"), width: 860, scale: 2, themeId: "high-contrast"))
        XCTAssertThrowsError(try HarnessRunner.renderOne(input: md, output: out.appendingPathComponent("nonexistent/x.png"), width: 860, scale: 2, themeId: "sevilla")) {
            XCTAssertEqual($0 as? HarnessError, .unwritableOutput(out.appendingPathComponent("nonexistent/x.png").path))
        }
        XCTAssertThrowsError(try HarnessRunner.renderOne(input: md, output: out.appendingPathComponent("y.png"), width: 860, scale: 2, themeId: "bogus")) {
            XCTAssertEqual($0 as? HarnessError, .unknownTheme("bogus"))
        }
        XCTAssertThrowsError(try HarnessRunner.renderOne(input: out.appendingPathComponent("missing.md"), output: out.appendingPathComponent("z.png"), width: 860, scale: 2, themeId: "sevilla"))
    }
}
