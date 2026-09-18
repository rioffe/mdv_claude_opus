import XCTest
import AppKit
import BeautifulMermaid
@testable import mdv6Core

/// C-06 `MDVMermaidPipeline.prepare/displaySize/rasterize`, the C-06.2 repairs, R-15 math nodes, E-01/E-02 outcomes,
/// I-005 raster sizing, K-07/K-08 constants (render group of §9.0).
final class MermaidTests: XCTestCase {

    private func prepare(_ src: String, theme: DiagramTheme = .zincLight) throws -> MDVMermaidPrepared {
        try MDVMermaidPipeline.prepare(source: src, theme: theme)
    }

    // MARK: E-01, E-02, K-14

    /// T-14, E-01, C-06.2: a node listed in two subgraphs belongs to the last one; the diagram lays out (no ELK assert).
    func testNodeInTwoSubgraphsBelongsToLast() throws {
        let src = """
        flowchart TD
          subgraph X
            A --> PD
          end
          subgraph Y
            PD --> B
          end
        """
        let p = try prepare(src)
        guard case .flowchart(let nodes, _, let groups) = p.positioned.content else { return XCTFail("flowchart expected") }
        XCTAssertEqual(Set(nodes.map(\.id)), ["A", "PD", "B"])
        let y = groups.first { $0.id == "Y" || $0.label == "Y" }!
        let x = groups.first { $0.id == "X" || $0.label == "X" }!
        let pd = nodes.first { $0.id == "PD" }!
        XCTAssertTrue(pd.y >= y.y && pd.y + pd.height <= y.y + y.height + 0.5, "PD inside Y")
        XCTAssertFalse(pd.y >= x.y && pd.y + pd.height <= x.y + x.height && pd.x >= x.x && pd.x + pd.width <= x.x + x.width, "PD not inside X")
        XCTAssertEqual(MDVMermaidPipeline.normalizeSubgraphOwnership(nodeIds: [["A", "PD"], ["PD", "B"]]), [["A"], ["PD", "B"]])
    }

    /// T-13, E-02, R-10: the unsupported types and any parse error throw so the view shows the fallback; nothing crashes.
    func testUnsupportedTypesAndParseErrorsFallBack() {
        for src in ["timeline\n  title X\n  2020 : a", "gantt\n  title G", "pie\n  \"a\" : 1", "mindmap\n  root", "gitGraph\n  commit",
                    "journey\n  title J", "quadrantChart\n  title Q"] {
            XCTAssertThrowsError(try prepare(src), src) { error in
                guard case MermaidPrepareError.unsupported = error else { return XCTFail("\(src): \(error)") }
            }
        }
        XCTAssertThrowsError(try prepare("this is not mermaid at all ]]]")) { error in
            guard case MermaidPrepareError.parse = error else { return XCTFail("\(error)") }
        }
        XCTAssertTrue(MDVMermaidPipeline.unsupportedTypes.isSuperset(of: ["timeline", "gantt", "pie", "mindmap", "gitgraph"]))   // lower-cased first word
    }

    /// R-41, K-14, E-28: a source over 1 MiB is rejected before the parser; one at the ceiling is parsed. T-41.
    func testMermaidCeiling() throws {
        var entries = 0
        PipelineProbe.onParserEntry = { if $0 == "mermaid" { entries += 1 } }
        defer { PipelineProbe.onParserEntry = nil }
        let header = "flowchart LR\n  A --> B\n"
        let pad = "%% " + String(repeating: "x", count: ContentLimits.mermaidBytes - header.utf8.count - 4) + "\n"
        let atCeiling = header + pad
        XCTAssertEqual(atCeiling.utf8.count, ContentLimits.mermaidBytes)
        _ = try prepare(atCeiling)
        XCTAssertEqual(entries, 1)
        XCTAssertThrowsError(try prepare(atCeiling + "x")) { error in
            guard case MermaidPrepareError.exceedsLimit = error else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(entries, 1)
    }

    // MARK: T-15, T-16, T-20 (rendered)

    /// T-15, C-06.1, E-14: front matter, `<b>` labels, parallelograms and `#eee`/`white` fills render — with clean labels and
    /// the intended (light, not black) fills read from the model.
    func testSanitisedDiagramRenders() throws {
        let src = "---\ntitle: T\n---\nflowchart LR\n  A[/<b>Input</b>/] --> B[Output]\n  style A fill:#eee\n  style B fill:white"
        let p = try prepare(src)
        guard case .flowchart(let nodes, _, _) = p.positioned.content else { return XCTFail() }
        XCTAssertEqual(nodes.first { $0.id == "A" }?.label, "Input")
        let model = p.positioned.diagram.payload as! ParsedGraphModel
        XCTAssertEqual(model.nodeStyles["A"]?["fill"], "#eeeeee")
        XCTAssertEqual(model.nodeStyles["B"]?["fill"], "#ffffff")
        let image = MDVMermaidPipeline.rasterize(p, width: p.naturalSize.width, scale: 1)!
        XCTAssertTrue(hasPixel(image) { r, g, b in r > 0xE0 && g > 0xE0 && b > 0xE0 && !(r == 0xFF && g == 0xFF && b == 0xFF) }, "light grey fill present")
    }

    /// T-16, E-15: `xychart-beta` with `line "a" [...]` renders two series.
    func testXYChartSeriesRender() throws {
        let src = "xychart-beta\n  x-axis [a, b, c]\n  y-axis 0 --> 10\n  line \"first\" [1, 5, 9]\n  line \"second\" [9, 5, 1]"
        let p = try prepare(src)
        guard case .xyChart(let chart) = p.positioned.content else { return XCTFail("xy chart expected") }
        XCTAssertEqual(chart.lines.count, 2)
        XCTAssertEqual((p.positioned.diagram.payload as? XYChart)?.series.count, 2)
    }

    /// T-20, C-06.1 rule 4, C-06.2: a stateDiagram-v2 with several `ID: line` descriptions and classDef colours — every
    /// state shows all its lines and the colours reach the model (`classDefs`, `classAssignments`, `nodeStyles`).
    func testStateDescriptionsAndClassDefs() throws {
        let src = """
        stateDiagram-v2
          S1: first line
          S1: second line
          S2: only line
          [*] --> S1
          S1 --> S2
          classDef warm fill:#ffe0b0,stroke:#aa5500
          class S1 warm
          style S2 fill:#e0f0ff
        """
        let p = try prepare(src)
        guard case .stateDiagram(let nodes, _, _) = p.positioned.content else { return XCTFail() }
        XCTAssertEqual(nodes.first { $0.id == "S1" }?.label.components(separatedBy: "\n"), ["first line", "second line"])
        XCTAssertEqual(nodes.first { $0.id == "S2" }?.label, "only line")
        let model = p.positioned.diagram.payload as! ParsedGraphModel
        XCTAssertEqual(model.classDefs["warm"]?["fill"], "#ffe0b0")
        XCTAssertEqual(model.classAssignments["S1"], "warm")
        XCTAssertEqual(model.nodeStyles["S2"]?["fill"], "#e0f0ff")
    }

    // MARK: I-005, R-11, K-07

    /// I-005, R-11: `displaySize` is whole points and never wider than natural; the raster's pixel size is exactly
    /// `displaySize × scale`; width 1 pt yields a 1 pt raster; the image is upright.
    func testDisplaySizeAndRaster() throws {
        let p = try prepare("flowchart TD\n  A[Top node] --> B[Left]\n  A --> C[Right]")
        let natural = p.naturalSize
        XCTAssertGreaterThan(natural.width, 100)
        let full = MDVMermaidPipeline.displaySize(for: p, width: 5000)
        XCTAssertEqual(full.width, floor(natural.width)); XCTAssertEqual(full.height, floor(natural.height))
        let narrow = MDVMermaidPipeline.displaySize(for: p, width: 100)
        XCTAssertEqual(narrow.width, 100)
        XCTAssertEqual(narrow.height, floor(natural.height * 100 / natural.width))
        XCTAssertEqual(narrow.width, narrow.width.rounded()); XCTAssertEqual(narrow.height, narrow.height.rounded())
        let one = MDVMermaidPipeline.displaySize(for: p, width: 1)
        XCTAssertEqual(one.width, 1); XCTAssertGreaterThanOrEqual(one.height, 1)
        for scale: CGFloat in [1, 2] {
            let image = MDVMermaidPipeline.rasterize(p, width: 100, scale: scale)!
            let rep = image.representations.first as! NSBitmapImageRep
            XCTAssertEqual(CGFloat(rep.pixelsWide), narrow.width * scale)
            XCTAssertEqual(CGFloat(rep.pixelsHigh), narrow.height * scale)
            XCTAssertEqual(image.size, narrow)
        }
        XCTAssertNotNil(MDVMermaidPipeline.rasterize(p, width: 1, scale: 2))
        // upright: node A (top of a TD layout) is drawn in the upper half, and its vertical mirror is page background
        guard case .flowchart(let nodes, _, _) = p.positioned.content else { return XCTFail() }
        let a = nodes.first { $0.id == "A" }!
        let img = MDVMermaidPipeline.rasterize(p, width: natural.width, scale: 1)!
        let rep = img.representations.first as! NSBitmapImageRep
        let centre = rep.colorAt(x: Int(a.x + a.width / 2), y: Int(a.y + a.height / 2))!
        let mirror = rep.colorAt(x: Int(a.x + a.width / 2), y: rep.pixelsHigh - 1 - Int(a.y + a.height / 2))!
        let bg = DiagramTheme.zincLight.background.usingColorSpace(.deviceRGB)!
        XCTAssertGreaterThan(abs(centre.brightnessComponent - bg.brightnessComponent) + abs(centre.hueComponent - bg.hueComponent), 0.001, "node fill at A")
        XCTAssertEqual(mirror.redComponent, bg.redComponent, accuracy: 0.02, "background below the diagram's mirror point")
    }

    /// K-07: caches of 96 layouts and 192 rasters (≤ 192 MB); pinch zoom clamped to [0.5, 4]; zoomed container ≤ 540 pt.
    func testConstants() {
        XCTAssertEqual(MermaidCaches.layoutLimit, 96); XCTAssertEqual(MermaidCaches.rasterLimit, 192)
        XCTAssertEqual(MermaidCaches.rasterByteLimit, 192 * 1024 * 1024)
        XCTAssertEqual(MermaidZoom.range, 0.5...4.0); XCTAssertEqual(MermaidZoom.maxContainerHeight, 540)
        XCTAssertEqual(MermaidZoom.clamp(9), 4); XCTAssertEqual(MermaidZoom.clamp(0.1), 0.5)
        XCTAssertEqual(MermaidStyle.allCases.map(\.rawValue), ["document", "light", "dark", "tokyoNight", "catppuccin"])
        XCTAssertEqual(MermaidStyle(storedValue: "neon"), .document)
    }

    /// C-06.3: the Document style derives its theme from the active `MDVTheme` — background = code-block background,
    /// foreground = text, surface mixed 25 % toward the code background on light themes (16 % toward foreground on dark).
    func testDocumentTheme() {
        let s = MDVMermaidPipeline.documentTheme(from: .sevilla)
        XCTAssertEqual(s.background, MDVTheme.sevilla.rgba.secondaryBackground.nsColor)
        XCTAssertEqual(s.foreground, MDVTheme.sevilla.rgba.text.nsColor)
        XCTAssertEqual(s.surface, MDVMermaidPipeline.mix(MDVTheme.sevilla.rgba.background, MDVTheme.sevilla.rgba.secondaryBackground, 0.25).nsColor)
        let c = MDVMermaidPipeline.documentTheme(from: .charcoal)
        XCTAssertEqual(c.surface, MDVMermaidPipeline.mix(MDVTheme.charcoal.rgba.background, MDVTheme.charcoal.rgba.text, 0.16).nsColor)
        XCTAssertNotNil(c.line); XCTAssertNotNil(c.border); XCTAssertNotNil(c.muted)
        XCTAssertEqual(MDVMermaidPipeline.theme(for: .light, document: .sevilla), .zincLight)
        XCTAssertEqual(MDVMermaidPipeline.theme(for: .dark, document: .sevilla), .zincDark)
        XCTAssertEqual(MDVMermaidPipeline.theme(for: .tokyoNight, document: .sevilla), .tokyoNight)
        XCTAssertEqual(MDVMermaidPipeline.theme(for: .catppuccin, document: .sevilla), .catppuccinMocha)
    }

    // MARK: sequence repairs (T-19, E-13, K-08)

    private let sequenceSource = """
    sequenceDiagram
      autonumber
      participant A as Alice<br>Wonderland
      participant B as Bob
      A->>B: single line
      B->>A: first line<br>second line<br>third line
      A->>A: think<br>hard
      loop retries
        A->>B: quick
        Note over B: final note<br>with two lines
      end
    """

    /// T-19, E-13, C-06.2, K-08: multi-line message labels are blanked in the model and drawn stacked (13 pt pitch); the
    /// actor gap grows so every label fits between its endpoints (+24, self +36); rows grow by (n−1)×13+4 — a 3-line row is
    /// 30 pt taller than a 1-line row; the block enclosing the last note is extended; autonumber discs 1…n sit at the tails.
    func testSequenceRepairs() throws {
        let p = try prepare(sequenceSource)
        guard case .sequenceDiagram(let actors, let messages, let blocks, let lifelines, _, let notes) = p.positioned.content else { return XCTFail() }
        XCTAssertEqual(actors.first { $0.id == "A" }?.label, "Alice Wonderland")            // <br> → space in actor labels
        XCTAssertEqual(messages.map(\.label), ["single line", "", "", "quick"])           // <br> labels blanked, drawn by mdv6
        XCTAssertEqual(p.sequenceExtras.stackedLabels.map { $0.lines }, [["first line", "second line", "third line"], ["think", "hard"]])
        // rows grow by (n−1)×13+4 for an n-line label: +30 for the 3-line row, +17 for the 2-line self message, measured
        // against the same diagram with single-line labels (the library's own row heights are the baseline, K-08)
        let base = try prepare(sequenceSource.replacingOccurrences(of: "<br>", with: " "))
        guard case .sequenceDiagram(_, let baseMessages, _, _, _, _) = base.positioned.content else { return XCTFail() }
        XCTAssertEqual(messages[0].y - baseMessages[0].y, 0, accuracy: 0.01)
        XCTAssertEqual(messages[1].y - baseMessages[1].y, 30, accuracy: 0.01)
        XCTAssertEqual(messages[2].y - baseMessages[2].y, 30 + 17, accuracy: 0.01)
        XCTAssertEqual(messages[3].y - baseMessages[3].y, 30 + 17, accuracy: 0.01)
        XCTAssertEqual(p.naturalSize.height - base.naturalSize.height, 30 + 17, accuracy: 8.01)   // + the note enclosure (≤ 8)
        // every stacked label fits between its endpoints and stacks upward from the arrow at a 13 pt pitch
        for label in p.sequenceExtras.stackedLabels {
            let msg = messages[label.messageIndex]
            let width = MDVMermaidPipeline.labelWidth(label.lines)
            if msg.isSelf {
                XCTAssertLessThanOrEqual(label.x + width, lifelineAfter(msg.x1, lifelines) - 1, "self label stays before the next lifeline")
            } else {
                XCTAssertGreaterThanOrEqual(min(msg.x1, msg.x2) + width + 0.5, width, "fits")
                XCTAssertLessThanOrEqual(width, abs(msg.x2 - msg.x1) - 24 + 0.5, "label narrower than the gap minus 24")
            }
            XCTAssertEqual(label.pitch, 13); XCTAssertEqual(label.fontSize, 11)
            XCTAssertLessThan(label.y, msg.y, "stack ends above the arrow")
            let previousY = label.messageIndex > 0 ? messages[label.messageIndex - 1].y : -1
            XCTAssertGreaterThan(label.y - CGFloat(label.lines.count - 1) * 13 - 11, previousY, "never overlaps the previous arrow")
        }
        // the note text keeps its line break, the loop block encloses the final note (+8)
        XCTAssertEqual(notes.first?.text, "final note\nwith two lines")
        let loop = blocks.first!
        XCTAssertGreaterThanOrEqual(loop.y + loop.height, notes.first!.y + notes.first!.height + 8 - 0.01)
        // autonumber: discs 1…4 at each arrow's tail, r = 8
        XCTAssertEqual(p.sequenceExtras.autonumberDiscs.map(\.number), [1, 2, 3, 4])
        XCTAssertEqual(p.sequenceExtras.autonumberDiscs.map { Double($0.x) }, messages.map { $0.x1 })
        XCTAssertEqual(MDVMermaidPipeline.autonumberRadius, 8)
        // the raster draws the stacked lines (ink above the second arrow) and the discs
        XCTAssertNotNil(MDVMermaidPipeline.rasterize(p, width: p.naturalSize.width, scale: 2))
    }

    private func lifelineAfter(_ x: Double, _ lifelines: [SequenceLifeline]) -> Double {
        lifelines.map(\.x).filter { $0 > x + 1 }.min() ?? .infinity
    }

    /// C-06.2: the x remap is piecewise-linear through old→new actor centres, so a point between two actors keeps its ratio.
    func testPiecewiseLinearRemap() {
        let remap = MDVMermaidPipeline.remapX(old: [100, 200, 300], new: [100, 260, 400])
        XCTAssertEqual(remap(100), 100); XCTAssertEqual(remap(200), 260); XCTAssertEqual(remap(300), 400)
        XCTAssertEqual(remap(150), 180); XCTAssertEqual(remap(250), 330)
        XCTAssertEqual(remap(50), 50); XCTAssertEqual(remap(350), 450)                   // outside: shifted by the end delta
    }

    // MARK: R-15, I-009, K-08 (math nodes)

    /// R-15, K-08, I-009 (pipeline half of T-17): a whole-`$$` node label is typeset at 16 pt and composited centred at a
    /// pixel-snapped origin; mixed and edge labels use the C-07.3 Unicode form; the node's ink weight is ≥ 0.9 × the
    /// document's at 2×.
    func testMathNodes() throws {
        let src = "flowchart LR\n  A[\"$$E = mc^2$$\"] -->|\"$\\alpha$ edge\"| B[\"mixed $\\pi$ text\"]"
        let p = try prepare(src)
        guard case .flowchart(let nodes, let edges, _) = p.positioned.content else { return XCTFail() }
        XCTAssertEqual(p.mathNodes.count, 1)
        let plan = p.mathNodes[0]
        XCTAssertEqual(plan.nodeId, "A"); XCTAssertEqual(plan.latex, "E = mc^2"); XCTAssertEqual(plan.fontSize, 16)
        let a = nodes.first { $0.id == "A" }!
        XCTAssertTrue(a.label.allSatisfy { $0 == " " || $0 == "\n" }, "blank placeholder label")
        XCTAssertGreaterThanOrEqual(a.width, plan.imageSize.width); XCTAssertGreaterThanOrEqual(a.height, plan.imageSize.height)
        XCTAssertEqual(nodes.first { $0.id == "B" }?.label, "mixed π text")
        XCTAssertEqual(edges.first?.label, "α edge")
        // ink weight: the node crop vs the document rendering of the same LaTeX at the same size, both at 2×
        let raster = MDVMermaidPipeline.rasterize(p, width: p.naturalSize.width, scale: 2)!
        let origin = plan.origin(scale: 2)
        XCTAssertEqual(origin.x, origin.x.rounded()); XCTAssertEqual(origin.y, origin.y.rounded())            // pixel-snapped
        let nodeCrop = Bitmap(image: raster, crop: CGRect(x: origin.x - 4, y: origin.y - 4, width: plan.imageSize.width * 2 + 8, height: plan.imageSize.height * 2 + 8), onWhite: true)!
        // the document side is typeset in the same colour the diagram uses (the Document style's foreground is the theme's
        // text colour, C-06.3 / R-13), so the comparison is weight against weight
        let ink = MermaidMathNodes.rgba(DiagramTheme.zincLight.foreground)
        guard case .image(let docImage, _, _) = MathImageCache.shared.rendered(for: MathSpec(latex: "E = mc^2", fontSize: 16, color: ink, display: true), scale: 2) else { return XCTFail() }
        let docCrop = Bitmap(image: docImage, crop: CGRect(x: -4, y: -4, width: docImage.size.width * 2 + 8, height: docImage.size.height * 2 + 8), onWhite: true)!
        XCTAssertGreaterThan(RenderMetrics.inkedPixelCount(nodeCrop), 0)
        XCTAssertTrue(RenderMetrics.inkWeightHolds(node: nodeCrop, document: docCrop), "ink \(RenderMetrics.ink(nodeCrop)) vs \(RenderMetrics.ink(docCrop))")
    }

    // MARK: helpers

    private func hasPixel(_ image: NSImage, where predicate: (Int, Int, Int) -> Bool) -> Bool {
        let rep = image.representations.first as! NSBitmapImageRep
        for y in stride(from: 0, to: rep.pixelsHigh, by: 2) { for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
            guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
            if predicate(Int(c.redComponent * 255 + 0.5), Int(c.greenComponent * 255 + 0.5), Int(c.blueComponent * 255 + 0.5)) { return true }
        } }
        return false
    }
}
