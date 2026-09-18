// MDVMermaidPipeline — C-06. This file holds the pure half: C-06.1 source sanitisation (rules 1–6, in order) and the
// C-06.2 state-description merge. `prepare/rasterize/displaySize` are appended in W3 (R-10, R-15, E-01, E-02, E-14, E-15).
import Foundation

public enum MDVMermaidPipeline {

    // MARK: C-06.1

    /// C-06.1: rules 1…6 in this order.
    public static func sanitize(_ source: String) -> String {
        var s = dropFrontMatter(source)                                   // 1
        s = renameXYSeries(s)                                             // 2
        var lines = s.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        lines = lines.map(normalizeColors)                                // 3
        lines = mergeStateDescriptions(lines)                             // 4
        lines = lines.map(expandParallelograms)                           // 5
        lines = lines.map(stripFormattingTags)                            // 6
        return lines.joined(separator: "\n")
    }

    /// Rule 1: a leading `---` … `---` YAML front-matter block is dropped (the parser rejects it).
    public static func dropFrontMatter(_ source: String) -> String {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" else { return source }
        guard let close = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else { return source }
        return lines[(close + 1)...].joined(separator: "\n")
    }

    static let xySeriesRegex = try! NSRegularExpression(pattern: #"^(\s*)(line|bar)\s+"[^"]*"\s*(\[)"#, options: [.anchorsMatchLines])

    /// Rule 2: xychart `line "name" [...]`/`bar "name" [...]` → `line [...]`/`bar [...]`.
    public static func renameXYSeries(_ source: String) -> String {
        xySeriesRegex.stringByReplacingMatches(in: source, range: NSRange(source.startIndex..., in: source), withTemplate: "$1$2 $3")
    }

    /// Rule 3: the CSS colour names mapped to hex (only after `fill:`, `stroke:`, `color:` on style lines).
    static let cssColors: [String: String] = [
        "white": "#ffffff", "black": "#000000", "red": "#ff0000", "green": "#008000", "blue": "#0000ff", "yellow": "#ffff00",
        "orange": "#ffa500", "purple": "#800080", "gray": "#808080", "grey": "#808080", "lightgray": "#d3d3d3",
        "lightgrey": "#d3d3d3", "darkgray": "#a9a9a9", "silver": "#c0c0c0", "pink": "#ffc0cb", "lightblue": "#add8e6",
        "lightgreen": "#90ee90", "lightyellow": "#ffffe0", "gold": "#ffd700", "teal": "#008080", "navy": "#000080",
        "maroon": "#800000", "olive": "#808000", "cyan": "#00ffff", "magenta": "#ff00ff", "brown": "#a52a2a",
        "beige": "#f5f5dc", "ivory": "#fffff0", "lavender": "#e6e6fa", "coral": "#ff7f50", "salmon": "#fa8072",
        "tomato": "#ff6347", "crimson": "#dc143c", "indigo": "#4b0082", "violet": "#ee82ee", "khaki": "#f0e68c",
        "tan": "#d2b48c", "wheat": "#f5deb3", "mintcream": "#f5fffa", "honeydew": "#f0fff0", "aliceblue": "#f0f8ff",
        "whitesmoke": "#f5f5f5", "gainsboro": "#dcdcdc", "snow": "#fffafa",
        "transparent": "#00000000", "none": "#00000000",
    ]

    static let colorValueRegex = try! NSRegularExpression(pattern: #"\b(fill|stroke|color)\s*:\s*(#[0-9a-fA-F]{3,4}\b|[A-Za-z]+)"#)

    /// Rule 3: on `style`/`classDef`/`linkStyle` lines, expand `#rgb`/`#rgba` and map the listed names; other names pass through.
    public static func normalizeColors(_ line: String) -> String {
        let head = line.trimmingCharacters(in: .whitespaces)
        guard head.hasPrefix("style ") || head.hasPrefix("classDef ") || head.hasPrefix("linkStyle ") else { return line }
        let ns = line as NSString
        var out = line
        for m in colorValueRegex.matches(in: line, range: NSRange(location: 0, length: ns.length)).reversed() {
            let valueRange = m.range(at: 2)
            let value = ns.substring(with: valueRange)
            let replacement: String
            if value.hasPrefix("#") {
                let digits = value.dropFirst()
                guard digits.count == 3 || digits.count == 4 else { continue }
                replacement = "#" + digits.map { "\($0)\($0)" }.joined()
            } else if let hex = cssColors[value.lowercased()] {
                replacement = hex
            } else {
                continue
            }
            out = (out as NSString).replacingCharacters(in: valueRange, with: replacement)
        }
        return out
    }

    static let stateDescriptionRegex = try! NSRegularExpression(pattern: #"^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+?)\s*$"#)

    /// Rule 4: in a stateDiagram, every `ID: text` line for an ID folds into one `state "a<br/>b" as ID` alias
    /// inserted after the header (the parser keeps only the first registration).
    public static func mergeStateDescriptions(_ lines: [String]) -> [String] {
        guard let header = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
              lines[header].trimmingCharacters(in: .whitespaces).hasPrefix("stateDiagram") else { return lines }
        var descriptions: [(id: String, texts: [String], indent: String)] = []
        var kept: [String] = []
        for (i, line) in lines.enumerated() {
            if i > header, let m = stateDescriptionRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let ns = line as NSString
                let id = ns.substring(with: m.range(at: 2))
                let text = ns.substring(with: m.range(at: 3))
                if let k = descriptions.firstIndex(where: { $0.id == id }) {
                    descriptions[k].texts.append(text)
                } else {
                    descriptions.append((id, [text], ns.substring(with: m.range(at: 1))))
                }
                continue
            }
            kept.append(line)
        }
        guard !descriptions.isEmpty else { return lines }
        let aliases = descriptions.map { "\($0.indent)state \"\($0.texts.joined(separator: "<br/>"))\" as \($0.id)" }
        return Array(kept[...header]) + aliases + Array(kept[(header + 1)...])
    }

    static let parallelogramRegex = try! NSRegularExpression(pattern: #"\[[/\\]([^\[\]]*?)[/\\]\]"#)

    /// Rule 5: `id[/text/]` and `id[\text\]` → `id[text]` (not in the parser's shape table; D-07).
    public static func expandParallelograms(_ line: String) -> String {
        parallelogramRegex.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "[$1]")
    }

    static let formattingTagRegex = try! NSRegularExpression(
        pattern: #"</?(?:b|i|u|s|strong|em|small|sup|sub|span|code|tt|font|mark)(?:\s[^<>]*)?/?>"#,
        options: [.caseInsensitive])

    /// Rule 6: strip `<b> <i> <u> <s> <strong> <em> <small> <sup> <sub> <span> <code> <tt> <font> <mark>` (open and
    /// close), keeping their content; `<br/>` is left alone.
    public static func stripFormattingTags(_ line: String) -> String {
        formattingTagRegex.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "")
    }
}

// MARK: - C-06 rendering half (prepare / displaySize / rasterize)

import AppKit
import BeautifulMermaid

/// R-09: the diagram style menu; persisted document-wide in `mdv6.mermaid.style` (C-04).
public enum MermaidStyle: String, CaseIterable, Sendable {
    case document, light, dark, tokyoNight, catppuccin

    /// C-04: an unknown stored value reads as `document`.
    public init(storedValue: String) { self = MermaidStyle(rawValue: storedValue) ?? .document }
}

/// K-07: pinch zoom clamped to [0.5, 4]; zoomed container height ≤ 540 pt.
public enum MermaidZoom {
    public static let range: ClosedRange<CGFloat> = 0.5...4.0
    public static let maxContainerHeight: CGFloat = 540
    public static func clamp(_ z: CGFloat) -> CGFloat { min(max(z, range.lowerBound), range.upperBound) }
}

/// R-10, E-02, E-28: why a diagram could not be prepared; the view shows the source fallback.
public enum MermaidPrepareError: Error, Equatable {
    case exceedsLimit
    case unsupported(String)
    case parse(String)
}

/// R-15: a whole-`$$` node label typeset by SwiftMath and composited after rasterising (I-009).
public struct MathNodePlan {
    public let nodeId: String
    public let latex: String
    public let fontSize: CGFloat
    public let image: NSImage
    public let imageSize: CGSize
    /// The node's rect in diagram points (after layout).
    public let nodeRect: CGRect

    /// The pixel-snapped top-left origin of the image in a raster at `scale` (and `fit`, the display/natural ratio).
    public func origin(scale: CGFloat, fit: CGFloat = 1) -> CGPoint {
        let cx = nodeRect.midX - imageSize.width / 2
        let cy = nodeRect.midY - imageSize.height / 2
        return CGPoint(x: (cx * scale * fit).rounded(), y: (cy * scale * fit).rounded())
    }
}

/// C-06.2 sequence extras mdv6 draws itself: stacked multi-line message labels and autonumber discs.
public struct SequenceExtras {
    public struct StackedLabel {
        public let messageIndex: Int
        public let lines: [String]
        /// Left x of the stack (diagram points) and the baseline y of the lowest line; lines stack upward at `pitch`.
        public let x: CGFloat
        public let y: CGFloat
        public let pitch: CGFloat
        public let fontSize: CGFloat
    }
    public struct Disc { public let number: Int; public let x: CGFloat; public let y: CGFloat }
    public var stackedLabels: [StackedLabel] = []
    public var autonumberDiscs: [Disc] = []
}

/// C-06: the parsed, repaired and laid-out diagram, ready to rasterise at any width.
public struct MDVMermaidPrepared {
    public let positioned: PositionedGraph
    public let naturalSize: CGSize
    public let theme: DiagramTheme
    public let mathNodes: [MathNodePlan]
    public let sequenceExtras: SequenceExtras
    public var diagramType: DiagramType { positioned.diagram.type }
}

extension MDVMermaidPipeline {
    /// E-02, D-04: diagram types the library lacks — shown as the fallback without entering the parser.
    public static let unsupportedTypes: Set<String> = ["timeline", "gantt", "pie", "mindmap", "gitgraph", "journey", "quadrantchart",
                                                        "requirementdiagram", "c4context", "sankey", "block", "packet", "kanban", "architecture"]
    /// K-08: diagram-label math at 16 pt.
    public static let mathLabelFontSize: CGFloat = 16
    /// C-06.2: message-label line pitch 13 pt, 11 pt font.
    public static let stackedLabelPitch: CGFloat = 13
    public static let stackedLabelFontSize: CGFloat = 11
    /// C-06.2: `autonumber` discs r = 8 pt.
    public static let autonumberRadius: CGFloat = 8

    // MARK: prepare (parse → repair → layout)

    /// C-06: K-14 ceiling (R-41) → C-06.1 sanitise → parse → pre-layout repairs (E-01 ownership, R-15 math placeholders,
    /// sequence `<br>` handling) → ELK layout → post-layout repairs (sequence gaps/rows/notes/autonumber).
    public static func prepare(source: String, theme: DiagramTheme) throws -> MDVMermaidPrepared {
        guard ContentLimits.admits(source.utf8.count, kind: .mermaid) else { throw MermaidPrepareError.exceedsLimit }
        let sanitized = sanitize(source)
        let firstWord = sanitized.split(whereSeparator: { $0.isNewline }).map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("%%") }?.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == ":" }).first.map { String($0).lowercased() } ?? ""
        if unsupportedTypes.contains(firstWord) { throw MermaidPrepareError.unsupported(firstWord) }

        PipelineProbe.enter("mermaid")
        var graph: MermaidGraph
        do { graph = try MermaidParser.parse(sanitized) } catch { throw MermaidPrepareError.parse("\(error)") }

        var mathPlans: [MermaidMathNodes.Plan] = []
        var stacked: [(index: Int, lines: [String])] = []
        let autonumber = sanitized.split(whereSeparator: { $0.isNewline }).contains { $0.trimmingCharacters(in: .whitespaces).lowercased() == "autonumber" }

        switch graph.type {
        case .flowchart, .stateDiagram:
            if var model = graph.payload as? ParsedGraphModel {
                MermaidRepairs.normalizeOwnership(&model, source: sanitized)                     // E-01
                MermaidRepairs.applyStateStyles(&model, source: sanitized)                       // C-06.2 state classDef/class/style
                mathPlans = MermaidMathNodes.plan(&model, theme: theme)                          // R-15 placeholders + Unicode labels
                graph.payload = model
            }
        case .sequenceDiagram:
            if var seq = graph.payload as? SequenceDiagram {
                stacked = MermaidRepairs.prepareSequenceLabels(&seq)                             // <br> rules
                graph.payload = seq
            }
        default: break
        }

        var positioned: PositionedGraph
        do { positioned = try GraphLayout().layout(graph) } catch { throw MermaidPrepareError.parse("\(error)") }

        var extras = SequenceExtras()
        if graph.type == .sequenceDiagram, let seq = graph.payload as? SequenceDiagram {
            extras = MermaidRepairs.repairSequence(&positioned, parsed: seq, stacked: stacked, autonumber: autonumber)
        }
        let mathNodes = MermaidMathNodes.resolve(mathPlans, positioned: positioned)
        let natural = CGSize(width: max(1, positioned.width), height: max(1, positioned.height))
        return MDVMermaidPrepared(positioned: positioned, naturalSize: natural, theme: theme, mathNodes: mathNodes, sequenceExtras: extras)
    }

    // MARK: display size and raster (I-005, R-11)

    /// I-005: whole points, never wider than natural; the single source of both the bitmap size and the view frame.
    public static func displaySize(for p: MDVMermaidPrepared, width: CGFloat) -> CGSize {
        let w = max(1, floor(min(width, p.naturalSize.width)))
        let h = max(1, floor(p.naturalSize.height * w / p.naturalSize.width))
        return CGSize(width: w, height: h)
    }

    /// R-11: rasterise at `displaySize(for:width:)` × `scale`, upright, with math nodes and sequence extras composited.
    public static func rasterize(_ p: MDVMermaidPrepared, width: CGFloat, scale: CGFloat) -> NSImage? {
        let size = displaySize(for: p, width: width)
        let fit = size.width / p.naturalSize.width
        let pw = Int(size.width * scale), ph = Int(size.height * scale)
        guard pw > 0, ph > 0,
              let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        ctx.setFillColor(p.theme.background.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pw, height: ph))
        // The library draws with y = 0 at the top; flip the (bottom-left) CGContext for it.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(ph))
        ctx.scaleBy(x: scale * fit, y: -scale * fit)
        let bounds = CGRect(origin: .zero, size: p.naturalSize)
        DiagramRenderer(theme: p.theme.withTransparent(true)).render(p.positioned, in: ctx, bounds: bounds)
        ctx.restoreGState()
        // Extras are drawn unflipped in raster pixels (top-left diagram coordinates → bottom-left pixels).
        for plan in p.mathNodes {
            let o = plan.origin(scale: scale, fit: fit)
            let w = plan.imageSize.width * scale * fit, h = plan.imageSize.height * scale * fit
            if let cg = (plan.image.representations.first as? NSBitmapImageRep)?.cgImage ?? plan.image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                // the baked bitmap is 2×; at scale·fit = 2 this is a 1:1 pixel copy (no resampling), which is what I-009 needs
                let dw = CGFloat(cg.width) * scale * fit / 2, dh = CGFloat(cg.height) * scale * fit / 2
                ctx.interpolationQuality = .high
                ctx.draw(cg, in: CGRect(x: o.x, y: CGFloat(ph) - o.y - dh, width: dw, height: dh))
                _ = (w, h)
            }
        }
        MermaidRepairs.drawSequenceExtras(p.sequenceExtras, in: ctx, theme: p.theme, scale: scale * fit, pixelHeight: CGFloat(ph))
        guard let cg = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        rep.size = size
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    // MARK: C-06.3 document theme

    /// Mixes `a` toward `b` by `t`.
    public static func mix(_ a: RGBA, _ b: RGBA, _ t: Double) -> RGBA {
        func m(_ x: UInt8, _ y: UInt8) -> UInt8 { UInt8((Double(x) + (Double(y) - Double(x)) * t).rounded()) }
        return RGBA(r: m(a.r, b.r), g: m(a.g, b.g), b: m(a.b, b.b), a: 255)
    }

    /// C-06.3: background = code-block background, foreground = text, surface = page colour mixed 25 % toward the code
    /// background (light) or lifted 16 % toward the foreground (dark); lines/borders/muted are fixed mixes.
    public static func documentTheme(from t: MDVTheme) -> DiagramTheme {
        let bg = t.rgba.secondaryBackground, fg = t.rgba.text
        let surface = t.isDark ? mix(t.rgba.background, fg, 0.16) : mix(t.rgba.background, bg, 0.25)
        return DiagramTheme(background: bg.nsColor, foreground: fg.nsColor,
                            line: mix(bg, fg, 0.55).nsColor, accent: t.rgba.accent.nsColor, muted: mix(bg, fg, 0.45).nsColor,
                            surface: surface.nsColor, border: mix(bg, fg, 0.35).nsColor)
    }

    /// R-09: the five styles.
    public static func theme(for style: MermaidStyle, document: MDVTheme) -> DiagramTheme {
        switch style {
        case .document: return documentTheme(from: document)
        case .light: return .zincLight
        case .dark: return .zincDark
        case .tokyoNight: return .tokyoNight
        case .catppuccin: return .catppuccinMocha
        }
    }

    // MARK: helpers shared with tests

    /// The width the library would measure for stacked label lines at 11 pt / weight 400.
    public static func labelWidth(_ lines: [String]) -> CGFloat {
        lines.map { CGFloat(original_src_text_metrics.measureTextWidth($0, fontSize: Double(stackedLabelFontSize), fontWeight: 400)) }.max() ?? 0
    }

    /// C-06.2: piecewise-linear x remap through old→new actor centres (outside the range: shifted by the end delta).
    public static func remapX(old: [Double], new: [Double]) -> (Double) -> Double {
        return { x in
            guard let first = old.first, let last = old.last, old.count == new.count, old.count >= 1 else { return x }
            if x <= first { return x + (new.first! - first) }
            if x >= last { return x + (new.last! - last) }
            for i in 1..<old.count where x <= old[i] {
                let t = (x - old[i - 1]) / (old[i] - old[i - 1])
                return new[i - 1] + t * (new[i] - new[i - 1])
            }
            return x
        }
    }

    /// E-01: a node listed in several subgraphs belongs to the last one (pure form, on id lists in declaration order).
    public static func normalizeSubgraphOwnership(nodeIds: [[String]]) -> [[String]] {
        var lastOwner: [String: Int] = [:]
        for (i, ids) in nodeIds.enumerated() { for id in ids { lastOwner[id] = i } }
        return nodeIds.enumerated().map { i, ids in ids.filter { lastOwner[$0] == i } }
    }
}

/// K-07: 96 layouts, 192 rasters, ≤ 192 MB of raster bytes.
public final class MermaidCaches {
    public static let shared = MermaidCaches()
    public static let layoutLimit = 96
    public static let rasterLimit = 192
    public static let rasterByteLimit = 192 * 1024 * 1024

    public struct LayoutKey: Hashable { public let source: String; public let themeId: String
        public init(source: String, themeId: String) { self.source = source; self.themeId = themeId } }
    public struct RasterKey: Hashable { public let source: String; public let themeId: String; public let width: CGFloat; public let zoom: CGFloat; public let scale: CGFloat
        public init(source: String, themeId: String, width: CGFloat, zoom: CGFloat, scale: CGFloat) { self.source = source; self.themeId = themeId; self.width = width; self.zoom = zoom; self.scale = scale } }

    private var layouts: [LayoutKey: MDVMermaidPrepared] = [:]
    private var layoutOrder: [LayoutKey] = []
    private var rasters: [RasterKey: NSImage] = [:]
    private var rasterOrder: [RasterKey] = []
    private var rasterBytes = 0
    private let lock = NSLock()

    public init() {}

    public func layout(_ key: LayoutKey) -> MDVMermaidPrepared? { lock.lock(); defer { lock.unlock() }; return layouts[key] }
    public func store(_ p: MDVMermaidPrepared, for key: LayoutKey) {
        lock.lock(); defer { lock.unlock() }
        if layouts[key] == nil { layoutOrder.append(key) }
        layouts[key] = p
        while layoutOrder.count > MermaidCaches.layoutLimit { layouts.removeValue(forKey: layoutOrder.removeFirst()) }
    }
    public func raster(_ key: RasterKey) -> NSImage? { lock.lock(); defer { lock.unlock() }; return rasters[key] }
    public func store(_ image: NSImage, for key: RasterKey) {
        lock.lock(); defer { lock.unlock() }
        let bytes = (image.representations.first as? NSBitmapImageRep).map { $0.bytesPerRow * $0.pixelsHigh } ?? 0
        if rasters[key] == nil { rasterOrder.append(key) }
        rasters[key] = image
        rasterBytes += bytes
        while rasterOrder.count > MermaidCaches.rasterLimit || rasterBytes > MermaidCaches.rasterByteLimit, !rasterOrder.isEmpty {
            let k = rasterOrder.removeFirst()
            if let old = rasters.removeValue(forKey: k), let rep = old.representations.first as? NSBitmapImageRep { rasterBytes -= rep.bytesPerRow * rep.pixelsHigh }
        }
    }
    public var layoutCount: Int { lock.lock(); defer { lock.unlock() }; return layouts.count }
    public var rasterCount: Int { lock.lock(); defer { lock.unlock() }; return rasters.count }
}
