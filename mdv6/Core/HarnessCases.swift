// HarnessCases — C-17 / R-39: the render harness's discovery (`--scan`), manifest (`--check`) and metrics
// (`pixel`, `ink`, `sequence-layout`, `rhythm`, `display-math`), linked by `tools/render-harness` (which only parses
// arguments, prints the JSON records and maps exit codes). Case output is deterministic for identical inputs (I-001).
import Foundation
import AppKit

/// `test-docs/render-cases.json` (C-17): unknown keys are ignored; paths are repository-relative; ids are unique.
public struct HarnessManifest: Codable {
    public var version: Int
    public var cases: [HarnessCase]
}

public struct HarnessCase: Codable, Equatable {
    public enum Kind: String, Codable { case markdown, mermaid }
    public enum Expectation: String, Codable { case render, fallback }
    public enum Metric: String, Codable { case pixel, ink, sequenceLayout = "sequence-layout", rhythm, displayMath = "display-math" }
    public var id: String
    public var input: String
    public var kind: Kind
    public var width: CGFloat?
    public var scale: CGFloat?
    public var expect: Expectation?
    public var golden: String?
    public var metric: Metric?
    public var theme: String?
}

/// One JSON record per case: `id`, `status` (`pass`/`fail`/`fallback`), `output`.
public struct CaseResult: Equatable {
    public enum Status: String { case pass, fail, fallback }
    public let id: String
    public let status: Status
    public let output: String?
    public let diagnostics: [String]

    public var json: String {
        var d: [String: Any] = ["id": id, "status": status.rawValue]
        d["output"] = output ?? NSNull()
        let data = try! JSONSerialization.data(withJSONObject: d, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }
}

public enum HarnessError: Error, Equatable {
    case usage(String)
    case unreadableInput(String)
    case unknownTheme(String)
    case unwritableOutput(String)
    case invalidManifest(String)
    case unknownCase(String)
}

public enum HarnessRunner {
    // MARK: single render

    /// `render-harness INPUT --output FILE`: a `.md` document or a raw `.mmd` diagram to PNG. The output's parent must
    /// exist (never created). Throws C-17 exit-2 conditions; returns `false` for a render/fallback failure (exit 1).
    @MainActor
    public static func renderOne(input: URL, output: URL, width: CGFloat, scale: CGFloat, themeId: String) throws -> Bool {
        guard let theme = ThemeCatalog.theme(id: themeId) else { throw HarnessError.unknownTheme(themeId) }
        guard let data = FileManager.default.contents(atPath: input.path), let text = String(data: data, encoding: .utf8) else {
            throw HarnessError.unreadableInput(input.path)
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: output.deletingLastPathComponent().path, isDirectory: &isDir), isDir.boolValue else {
            throw HarnessError.unwritableOutput(output.path)
        }
        var o = DocumentRenderer.Options()
        o.width = width; o.scale = scale; o.theme = theme; o.baseURL = input.deletingLastPathComponent()
        let image: NSImage
        if input.pathExtension.lowercased() == "mmd" {
            guard case .rendered(let img) = DocumentRenderer.render(mermaid: text, options: o) else { return false }
            image = img
        } else {
            image = try DocumentRenderer.render(markdown: text, options: o)
        }
        guard let png = DocumentRenderer.png(image) else { return false }
        do { try png.write(to: output) } catch { throw HarnessError.unwritableOutput(output.path) }
        return true
    }

    // MARK: --scan (C-17)

    public struct ScanCase: Equatable {
        public let relativePath: String
        /// nil for a raw `.mmd`; the 0-based fence index inside a `.md`.
        public let fenceIndex: Int?
        public let source: String
        public var id: String { fenceIndex.map { "\(relativePath)#\($0)" } ?? relativePath }
        /// A collision-free relative PNG path under the output directory.
        public var outputName: String {
            let base = relativePath.replacingOccurrences(of: "/", with: "__")
            return fenceIndex.map { "\(base)__fence\($0).png" } ?? "\(base).png"
        }
    }

    /// Non-hidden `.mmd` files and Mermaid fences in `.md` files, ordered by the UTF-8 bytes of the relative path and
    /// then the fence index.
    public static func scan(root: URL) -> [ScanCase] {
        var files: [String] = []
        if let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in e {
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
                let ext = url.pathExtension.lowercased()
                guard ext == "mmd" || ext == "md" else { continue }
                let rel = url.path.replacingOccurrences(of: root.standardizedFileURL.path + "/", with: "")
                if rel.split(separator: "/").contains(where: { $0.hasPrefix(".") }) { continue }
                files.append(rel)
            }
        }
        files.sort { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
        var cases: [ScanCase] = []
        for rel in files {
            guard let text = try? String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8) else { continue }
            if rel.lowercased().hasSuffix(".mmd") {
                cases.append(ScanCase(relativePath: rel, fenceIndex: nil, source: text))
            } else {
                var index = 0
                for block in ParsedDocument.parseBlocks(text) where BlockKind(block: block) == .mermaidFence {
                    cases.append(ScanCase(relativePath: rel, fenceIndex: index, source: FenceParts(block: block).code))
                    index += 1
                }
            }
        }
        return cases
    }

    /// Renders every scanned case into `outputDir`; E-02 unsupported types are expected fallbacks (`fallback`), every
    /// other fallback is `fail`, a rendered diagram is `pass`.
    @MainActor
    public static func runScan(root: URL, outputDir: URL, width: CGFloat = 860, scale: CGFloat = 2, themeId: String = "high-contrast") throws -> [CaseResult] {
        guard let theme = ThemeCatalog.theme(id: themeId) else { throw HarnessError.unknownTheme(themeId) }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        var o = DocumentRenderer.Options(); o.width = width; o.scale = scale; o.theme = theme
        return scan(root: root).map { c in
            let out = outputDir.appendingPathComponent(c.outputName)
            switch DocumentRenderer.render(mermaid: c.source, options: o) {
            case .rendered(let image):
                guard let png = DocumentRenderer.png(image), (try? png.write(to: out)) != nil else {
                    return CaseResult(id: c.id, status: .fail, output: nil, diagnostics: ["could not write \(out.path)"])
                }
                return CaseResult(id: c.id, status: .pass, output: out.path, diagnostics: [])
            case .fallback(let reason):
                let expected = reason.hasPrefix("unsupported diagram type")
                return CaseResult(id: c.id, status: expected ? .fallback : .fail, output: nil, diagnostics: [reason])
            }
        }
    }

    // MARK: --check (C-17)

    public static func loadManifest(_ url: URL) throws -> HarnessManifest {
        guard let data = FileManager.default.contents(atPath: url.path) else { throw HarnessError.invalidManifest("unreadable \(url.path)") }
        let m: HarnessManifest
        do { m = try JSONDecoder().decode(HarnessManifest.self, from: data) } catch { throw HarnessError.invalidManifest("\(error)") }
        guard m.version == 1 else { throw HarnessError.invalidManifest("version \(m.version)") }
        guard Set(m.cases.map(\.id)).count == m.cases.count else { throw HarnessError.invalidManifest("duplicate ids") }
        return m
    }

    /// Runs the manifest's cases in order (or exactly `only`), writing outputs under `outputDir`.
    @MainActor
    public static func runCheck(manifest: HarnessManifest, root: URL, outputDir: URL, only: String?) throws -> [CaseResult] {
        var selected = manifest.cases
        if let only {
            guard let c = manifest.cases.first(where: { $0.id == only }) else { throw HarnessError.unknownCase(only) }
            selected = [c]
        }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        return try selected.map { try run(case: $0, root: root, outputDir: outputDir) }
    }

    @MainActor
    static func run(case c: HarnessCase, root: URL, outputDir: URL) throws -> CaseResult {
        guard let theme = ThemeCatalog.theme(id: c.theme ?? "high-contrast") else { throw HarnessError.invalidManifest("unknown theme \(c.theme ?? "")") }
        let input = root.appendingPathComponent(c.input)
        guard let text = try? String(contentsOf: input, encoding: .utf8) else { throw HarnessError.unreadableInput(input.path) }
        var o = DocumentRenderer.Options()
        o.width = c.width ?? 860; o.scale = c.scale ?? 2; o.theme = theme; o.baseURL = input.deletingLastPathComponent()
        let out = outputDir.appendingPathComponent("\(c.id).png")
        var diagnostics: [String] = []
        var image: NSImage? = nil
        var prepared: MDVMermaidPrepared? = nil
        var fallbackReason: String? = nil
        switch c.kind {
        case .mermaid:
            switch DocumentRenderer.render(mermaid: text, options: o) {
            case .rendered(let img): image = img
            case .fallback(let reason): fallbackReason = reason
            }
            prepared = try? MDVMermaidPipeline.prepare(source: text, theme: MDVMermaidPipeline.theme(for: o.mermaidStyle, document: theme))
        case .markdown:
            do { image = try DocumentRenderer.render(markdown: text, options: o) } catch { fallbackReason = "\(error)" }
        }
        let expect = c.expect ?? .render
        if let fallbackReason {
            diagnostics.append(fallbackReason)
            return CaseResult(id: c.id, status: expect == .fallback ? .fallback : .fail, output: nil, diagnostics: diagnostics)
        }
        guard let image, let png = DocumentRenderer.png(image) else { return CaseResult(id: c.id, status: .fail, output: nil, diagnostics: ["render failed"]) }
        if expect == .fallback { return CaseResult(id: c.id, status: .fail, output: nil, diagnostics: ["expected a fallback, got a render"]) }
        try png.write(to: out)
        var ok = true
        if let golden = c.golden {
            let goldenURL = root.appendingPathComponent(golden)
            if let g = NSImage(contentsOf: goldenURL), let gb = Bitmap(image: g), let ob = Bitmap(image: image) {
                if let q = RenderMetrics.pixelMismatch(ob, gb) {
                    if q > RenderMetrics.mismatchTolerance { ok = false; diagnostics.append("pixel mismatch q = \(q)") }
                } else { ok = false; diagnostics.append("golden dimensions differ") }
            } else { ok = false; diagnostics.append("missing golden \(golden)") }
        }
        if let metric = c.metric {
            let (passed, notes) = evaluate(metric: metric, case: c, text: text, image: image, prepared: prepared, options: o)
            diagnostics += notes
            if !passed { ok = false }
        }
        return CaseResult(id: c.id, status: ok ? .pass : .fail, output: out.path, diagnostics: diagnostics)
    }

    // MARK: metrics

    @MainActor
    static func evaluate(metric: HarnessCase.Metric, case c: HarnessCase, text: String, image: NSImage, prepared: MDVMermaidPrepared?,
                         options o: DocumentRenderer.Options) -> (Bool, [String]) {
        switch metric {
        case .pixel:
            return (c.golden != nil, c.golden == nil ? ["pixel metric needs a golden"] : [])
        case .ink:
            return inkMetric(prepared: prepared, theme: o.theme)
        case .sequenceLayout:
            return sequenceLayoutMetric(source: text, prepared: prepared, theme: o.theme)
        case .rhythm:
            return rhythmMetric(text: text, options: o)
        case .displayMath:
            return displayMathMetric(text: text, options: o)
        }
    }

    /// §7.1 / T-17: every math node's crop at 2× has ink ≥ 0.9 × the document typesetting of the same LaTeX in the same colour.
    static func inkMetric(prepared: MDVMermaidPrepared?, theme: MDVTheme) -> (Bool, [String]) {
        guard let p = prepared, !p.mathNodes.isEmpty, let raster = MDVMermaidPipeline.rasterize(p, width: p.naturalSize.width, scale: 2) else {
            return (false, ["no math node to measure"])
        }
        let ink = MermaidMathNodes.rgba(p.theme.foreground)
        var notes: [String] = []
        var ok = true
        for plan in p.mathNodes {
            let origin = plan.origin(scale: 2)
            guard let node = Bitmap(image: raster, crop: CGRect(x: origin.x - 4, y: origin.y - 4, width: plan.imageSize.width * 2 + 8, height: plan.imageSize.height * 2 + 8), onWhite: true),
                  case .image(let doc, _, _) = MathImageCache.shared.rendered(for: MathSpec(latex: plan.latex, fontSize: plan.fontSize, color: ink, display: true), scale: 2),
                  let docCrop = Bitmap(image: doc, crop: CGRect(x: -4, y: -4, width: doc.size.width * 2 + 8, height: doc.size.height * 2 + 8), onWhite: true) else {
                ok = false; notes.append("\(plan.nodeId): crop failed"); continue
            }
            let holds = RenderMetrics.inkWeightHolds(node: node, document: docCrop)
            notes.append("\(plan.nodeId): ink \(RenderMetrics.ink(node)) vs \(RenderMetrics.ink(docCrop)) (\(plan.fontSize) pt) \(holds ? "ok" : "FAIL")")
            if !holds { ok = false }
        }
        return (ok, notes)
    }

    /// T-19: labels fit between their endpoints and stack above the arrow without overlapping the previous one; the block
    /// holding the final note encloses it; autonumber discs 1…n; an n-line row is (n−1)×13+4 taller than the single-line layout.
    static func sequenceLayoutMetric(source: String, prepared: MDVMermaidPrepared?, theme: MDVTheme) -> (Bool, [String]) {
        guard let p = prepared, case .sequenceDiagram(_, let messages, let blocks, let lifelines, _, let notes) = p.positioned.content else {
            return (false, ["not a sequence diagram"])
        }
        var ok = true
        var out: [String] = []
        func check(_ cond: Bool, _ msg: String) { out.append("\(cond ? "ok" : "FAIL") \(msg)"); if !cond { ok = false } }
        for label in p.sequenceExtras.stackedLabels {
            let msg = messages[label.messageIndex]
            let width = MDVMermaidPipeline.labelWidth(label.lines)
            if msg.isSelf {
                let next = lifelines.map(\.x).filter { $0 > msg.x1 + 1 }.min() ?? .infinity
                check(Double(label.x + width) <= next, "self label of message \(label.messageIndex) stays before the next lifeline")
            } else {
                check(Double(width) <= abs(msg.x2 - msg.x1) - 24 + 0.5, "label of message \(label.messageIndex) fits its actor gap (+24)")
            }
            let previousY = label.messageIndex > 0 ? messages[label.messageIndex - 1].y : -.infinity
            check(Double(label.y - CGFloat(label.lines.count - 1) * label.pitch - label.fontSize) > previousY, "stack of message \(label.messageIndex) is below the previous arrow")
            check(Double(label.y) < msg.y, "stack of message \(label.messageIndex) ends above its arrow")
        }
        if let note = notes.last, let block = blocks.last {
            check(block.y + block.height >= note.y + note.height + 8 - 0.01, "the last block encloses the final note (+8)")
        }
        let wantsNumbers = source.split(whereSeparator: { $0.isNewline }).contains { $0.trimmingCharacters(in: .whitespaces) == "autonumber" }
        if wantsNumbers {
            check(p.sequenceExtras.autonumberDiscs.map(\.number) == Array(1...max(1, messages.count)), "autonumber discs 1…\(messages.count)")
        }
        // row growth against the single-line variant of the same source
        let single = source.replacingOccurrences(of: "<br/>", with: " ").replacingOccurrences(of: "<br>", with: " ")
        if let base = try? MDVMermaidPipeline.prepare(source: single, theme: p.theme), case .sequenceDiagram(_, let baseMessages, _, _, _, _) = base.positioned.content, baseMessages.count == messages.count {
            var expectedShift = 0.0
            for (i, msg) in messages.enumerated() {
                let lines = p.sequenceExtras.stackedLabels.first { $0.messageIndex == i }?.lines.count ?? 1
                if lines > 1 { expectedShift += Double(lines - 1) * 13 + 4 }
                check(abs((msg.y - baseMessages[i].y) - expectedShift) < 0.01, "row \(i) shifted by \(expectedShift) pt ((n−1)×13+4 per multi-line label)")
            }
        }
        return (ok, out)
    }

    /// T-45: ink gaps between adjacent blocks in the K-16 band, per-block within ±2 pt of the single view.
    @MainActor
    static func rhythmMetric(text: String, options o: DocumentRenderer.Options) -> (Bool, [String]) {
        let t = o.theme
        let doc = ParsedDocument(raw: text)
        var single = o; single.singleView = true
        guard let blocksImage = try? DocumentRenderer.render(markdown: text, options: o), let singleImage = try? DocumentRenderer.render(markdown: text, options: single),
              let bb = Bitmap(image: blocksImage), let sb = Bitmap(image: singleImage) else { return (false, ["render failed"]) }
        func gaps(_ b: Bitmap) -> [CGFloat] {
            var bands = RenderMetrics.inkBands(b, page: t.rgba.background)
            // a heading rule is a thin band right under its heading: merge it
            var merged: [ClosedRange<Int>] = []
            for band in bands {
                if band.count <= 4 * Int(o.scale), let last = merged.last { merged[merged.count - 1] = last.lowerBound...band.upperBound } else { merged.append(band) }
            }
            bands = merged
            return RenderMetrics.gaps(between: bands, scale: o.scale)
        }
        let g1 = gaps(bb), g2 = gaps(sb)
        var ok = true
        var out: [String] = []
        guard g1.count == doc.blocks.count - 1, g2.count == doc.blocks.count - 1 else {
            return (false, ["expected \(doc.blocks.count - 1) gaps, measured \(g1.count) (blocks) and \(g2.count) (single)"])
        }
        for i in 0..<g1.count {
            let a = BlockKind(block: doc.blocks[i]), b = BlockKind(block: doc.blocks[i + 1])
            let v = max(ArticleBlockView<StaticArticleHost>.margins(theme: t, kind: a).bottom, ArticleBlockView<StaticArticleHost>.margins(theme: t, kind: b).top)
            func font(_ k: BlockKind) -> CGFloat { if case .heading(let l) = k { return t.baseFontSize * t.headingSizeEms[l - 1] } else { return t.baseFontSize } }
            let f = max(font(a), font(b))
            let band = RenderMetrics.rhythmBand(margin: v, fontSize: f)
            let inBand = band.contains(g1[i]), close = abs(g1[i] - g2[i]) <= RenderMetrics.perBlockTolerance
            out.append("\(inBand && close ? "ok" : "FAIL") gap \(i): blocks \(g1[i]) single \(g2[i]) band \(band.lowerBound)…\(band.upperBound)")
            if !(inBand && close) { ok = false }
        }
        return (ok, out)
    }

    /// T-46: one-line vs fence-form `$$` identical, centred within 2 pt, at the `.display` height.
    @MainActor
    static func displayMathMetric(text: String, options o: DocumentRenderer.Options) -> (Bool, [String]) {
        let spans = MathMarkdown.spans(in: text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard spans.count == 1, spans[0].display else { return (false, ["input must be exactly one $$…$$ span"]) }
        let latex = spans[0].latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let one = try? DocumentRenderer.render(markdown: "$$\(latex)$$", options: o), let fence = try? DocumentRenderer.render(markdown: "$$\n\(latex)\n$$", options: o),
              let ob = Bitmap(image: one), let fb = Bitmap(image: fence) else { return (false, ["render failed"]) }
        var out: [String] = []
        var ok = true
        func check(_ cond: Bool, _ msg: String) { out.append("\(cond ? "ok" : "FAIL") \(msg)"); if !cond { ok = false } }
        check(RenderMetrics.pixelMismatch(ob, fb) == 0, "one-line and fence-form rasters identical")
        guard let box = RenderMetrics.inkBounds(ob, page: o.theme.rgba.background) else { return (false, ["no ink"]) }
        let offset = RenderMetrics.horizontalCentreOffset(of: box, in: CGFloat(ob.width)) / o.scale
        check(abs(offset) <= 2, "centred within 2 pt (offset \(offset))")
        if case .image(let display, _, _) = MathImageCache.shared.rendered(for: MathSpec(latex: latex, fontSize: o.theme.baseFontSize * o.zoom, color: o.theme.rgba.text, display: true), scale: o.scale),
           let db = Bitmap(image: display, crop: CGRect(x: 0, y: 0, width: display.size.width * o.scale, height: display.size.height * o.scale), onWhite: true),
           let dbox = RenderMetrics.inkBounds(db, page: RGBA(r: 255, g: 255, b: 255)) {
            check(abs(box.height - dbox.height) <= 3, "ink height \(box.height) px is the .display height \(dbox.height) px")
        }
        return (ok, out)
    }
}

extension Bitmap {
    /// The whole bitmap of an `NSImage`.
    public init?(image: NSImage) {
        guard let rep = image.representations.first as? NSBitmapImageRep else { return nil }
        self.init(image: image, crop: CGRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh), onWhite: false)
    }
}
