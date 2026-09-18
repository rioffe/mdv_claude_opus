// MermaidRepairs — C-06.2 post-parse and post-layout repairs: subgraph ownership (E-01), state-diagram styles, and
// the sequence-diagram rules for `<br>` labels, actor gaps, row growth, note enclosure and autonumber (E-13, K-08).
import Foundation
import AppKit
import CoreText
import BeautifulMermaid

enum MermaidRepairs {
    // MARK: flowchart / state (pre-layout)

    /// E-01: a node listed in several subgraphs belongs to the **last** one (Mermaid.js semantics); it is removed from the
    /// others. The library's parser keeps the *first* registration, so the last owner is re-derived from the source: every
    /// `subgraph … end` block that mentions a known node id, in declaration order.
    static func normalizeOwnership(_ model: inout ParsedGraphModel, source: String) {
        var flat: [original_src_types.MermaidSubgraph] = []
        func walk(_ subs: [original_src_types.MermaidSubgraph]) { for s in subs { flat.append(s); walk(s.children) } }
        walk(model.subgraphs)
        guard flat.count > 1 else { return }
        let ids = Set(model.nodesInOrder.map(\.id))
        var mentions: [[String]] = Array(repeating: [], count: flat.count)     // node ids mentioned per subgraph, source order
        var stack: [Int] = []
        var next = 0
        for raw in source.split(whereSeparator: { $0.isNewline }) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("subgraph") {
                if next < flat.count { stack.append(next); next += 1 }
                continue
            }
            if line == "end" { _ = stack.popLast(); continue }
            guard let current = stack.last else { continue }
            for token in line.split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "_") }) where ids.contains(String(token)) {
                mentions[current].append(String(token))
            }
        }
        var lastOwner: [String: Int] = [:]
        for (i, list) in mentions.enumerated() { for id in list { lastOwner[id] = i } }
        for (i, sub) in flat.enumerated() {
            var kept = sub.nodeIds.filter { lastOwner[$0] == nil || lastOwner[$0] == i }
            for id in mentions[i] where lastOwner[id] == i && !kept.contains(id) { kept.append(id) }
            sub.nodeIds = kept
        }
    }

    static let classDefRegex = try! NSRegularExpression(pattern: #"^\s*classDef\s+(\w+)\s+(.+?)\s*$"#)
    static let classRegex = try! NSRegularExpression(pattern: #"^\s*class\s+([\w,\-]+)\s+(\w+)\s*$"#)
    static let styleRegex = try! NSRegularExpression(pattern: #"^\s*style\s+([\w,\-]+)\s+(.+?)\s*$"#)

    /// C-06.2 (stateDiagram): `classDef`, `class A,B name` and `style` lines read from the source are applied to the model.
    static func applyStateStyles(_ model: inout ParsedGraphModel, source: String) {
        for line in source.split(whereSeparator: { $0.isNewline }).map(String.init) {
            let ns = line as NSString
            let full = NSRange(location: 0, length: ns.length)
            if let m = classDefRegex.firstMatch(in: line, range: full) {
                let name = ns.substring(with: m.range(at: 1))
                if model.classDefs[name] == nil { model.classDefs[name] = parseStyleProps(ns.substring(with: m.range(at: 2))) }
            } else if let m = classRegex.firstMatch(in: line, range: full) {
                let className = ns.substring(with: m.range(at: 2))
                for id in ns.substring(with: m.range(at: 1)).split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !id.isEmpty {
                    if model.classAssignments[id] == nil { model.classAssignments[id] = className }
                }
            } else if let m = styleRegex.firstMatch(in: line, range: full) {
                let props = parseStyleProps(ns.substring(with: m.range(at: 2)))
                for id in ns.substring(with: m.range(at: 1)).split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !id.isEmpty {
                    var merged = model.nodeStyles[id] ?? [:]
                    for (k, v) in props where merged[k] == nil { merged[k] = v }
                    model.nodeStyles[id] = merged
                }
            }
        }
    }

    static func parseStyleProps(_ s: String) -> [String: String] {
        var out: [String: String] = [:]
        for pair in s.split(separator: ",") {
            let kv = pair.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if kv.count == 2, !kv[0].isEmpty { out[kv[0]] = kv[1] }
        }
        return out
    }

    // MARK: sequence (pre-layout)

    static let brRegex = try! NSRegularExpression(pattern: #"<br\s*/?>"#, options: [.caseInsensitive])

    static func splitBr(_ s: String) -> [String] {
        brRegex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "\n")
            .components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// C-06.2: `<br>` → newline in notes, → space in actor labels; message labels with `<br>` are blanked and drawn by mdv6.
    static func prepareSequenceLabels(_ seq: inout SequenceDiagram) -> [(index: Int, lines: [String])] {
        for i in seq.actors.indices { seq.actors[i].label = splitBr(seq.actors[i].label).joined(separator: " ") }
        for i in seq.notes.indices { seq.notes[i].text = splitBr(seq.notes[i].text).joined(separator: "\n") }
        var stacked: [(Int, [String])] = []
        for i in seq.messages.indices where brRegex.firstMatch(in: seq.messages[i].label, range: NSRange(seq.messages[i].label.startIndex..., in: seq.messages[i].label)) != nil {
            stacked.append((i, splitBr(seq.messages[i].label)))
            seq.messages[i].label = ""
        }
        return stacked
    }

    // MARK: sequence (post-layout)

    /// C-06.2: actor gaps widened until every stacked label fits (+24, self +36) with all x remapped piecewise-linearly;
    /// multi-line rows grown by (n−1)×13+4 with everything below shifted; a block whose last item is a note extended (+8);
    /// autonumber discs at each arrow's tail.
    static func repairSequence(_ positioned: inout PositionedGraph, parsed: SequenceDiagram, stacked: [(index: Int, lines: [String])],
                               autonumber: Bool) -> SequenceExtras {
        guard case .sequenceDiagram(var actors, var messages, var blocks, var lifelines, var activations, var notes) = positioned.content else { return SequenceExtras() }
        var extras = SequenceExtras()
        let pitch = MDVMermaidPipeline.stackedLabelPitch
        let widths = Dictionary(uniqueKeysWithValues: stacked.map { ($0.index, MDVMermaidPipeline.labelWidth($0.lines)) })

        // 1. gap widening
        let order = actors.indices.sorted { actors[$0].x < actors[$1].x }
        let oldCentres = order.map { actors[$0].x + actors[$0].width / 2 }
        var gaps = zip(oldCentres, oldCentres.dropFirst()).map { $1 - $0 }
        var extraRight: Double = 0
        let indexOf: [String: Int] = Dictionary(uniqueKeysWithValues: order.enumerated().map { (actors[$1].id, $0) })
        for (index, width) in widths.sorted(by: { $0.key < $1.key }) {
            let msg = messages[index]
            guard let a = indexOf[msg.from], let b = indexOf[msg.to] else { continue }
            if msg.isSelf {
                let need = Double(width) + 36
                if a + 1 < order.count { gaps[a] = max(gaps[a], need) } else { extraRight = max(extraRight, need) }
            } else {
                let (lo, hi) = (min(a, b), max(a, b))
                let need = Double(width) + 24
                let have = gaps[lo..<hi].reduce(0, +)
                if have < need { let add = (need - have) / Double(hi - lo); for g in lo..<hi { gaps[g] += add } }
            }
        }
        var newCentres = [oldCentres.first ?? 0]
        for g in gaps { newCentres.append(newCentres.last! + g) }
        let remap = MDVMermaidPipeline.remapX(old: oldCentres, new: newCentres)
        for (k, i) in order.enumerated() { actors[i].x = newCentres[k] - actors[i].width / 2 }
        for i in lifelines.indices { lifelines[i].x = remap(lifelines[i].x) }
        for i in messages.indices { messages[i].x1 = remap(messages[i].x1); messages[i].x2 = remap(messages[i].x2) }
        for i in activations.indices { activations[i].x = remap(activations[i].x) }
        for i in blocks.indices { let l = remap(blocks[i].x), r = remap(blocks[i].x + blocks[i].width); blocks[i].x = l; blocks[i].width = r - l }
        for i in notes.indices { let l = remap(notes[i].x), r = remap(notes[i].x + notes[i].width); notes[i].x = l; notes[i].width = r - l }
        positioned.width = max(remap(positioned.width), (newCentres.last ?? 0) + extraRight + 30)

        // 2. row growth
        for (index, lines) in stacked.sorted(by: { $0.index < $1.index }) {
            let delta = Double(lines.count - 1) * Double(pitch) + 4
            let y0 = messages[index].y
            for i in messages.indices where messages[i].y >= y0 - 0.001 { messages[i].y += delta }
            for i in lifelines.indices { if lifelines[i].topY >= y0 { lifelines[i].topY += delta }; if lifelines[i].bottomY >= y0 { lifelines[i].bottomY += delta } }
            for i in activations.indices { if activations[i].topY >= y0 { activations[i].topY += delta }; if activations[i].bottomY >= y0 { activations[i].bottomY += delta } }
            for i in blocks.indices {
                if blocks[i].y >= y0 { blocks[i].y += delta } else if blocks[i].y + blocks[i].height >= y0 { blocks[i].height += delta }
                for d in blocks[i].dividers.indices where blocks[i].dividers[d].y >= y0 { blocks[i].dividers[d].y += delta }
            }
            for i in notes.indices where notes[i].y >= y0 { notes[i].y += delta }
            positioned.height += delta
        }

        // 3. stacked label positions (drawn by mdv6)
        for (index, lines) in stacked.sorted(by: { $0.index < $1.index }) {
            let msg = messages[index]
            let width = Double(MDVMermaidPipeline.labelWidth(lines))
            let x = msg.isSelf ? msg.x1 + 30 : min(msg.x1, msg.x2) + (abs(msg.x2 - msg.x1) - width) / 2
            extras.stackedLabels.append(SequenceExtras.StackedLabel(messageIndex: index, lines: lines, x: CGFloat(x), y: CGFloat(msg.y - 4),
                                                                    pitch: pitch, fontSize: MDVMermaidPipeline.stackedLabelFontSize))
        }

        // 4. a block whose last item is a note is extended to enclose it (+8)
        for (i, block) in parsed.blocks.enumerated() where i < blocks.count {
            for (n, note) in parsed.notes.enumerated() where note.afterIndex == block.endIndex && n < notes.count {
                let bottom = notes[n].y + notes[n].height + 8
                if blocks[i].y + blocks[i].height < bottom { blocks[i].height = bottom - blocks[i].y }
                positioned.height = max(positioned.height, blocks[i].y + blocks[i].height + 8)
            }
        }

        // 5. autonumber discs at each arrow's tail
        if autonumber {
            extras.autonumberDiscs = messages.enumerated().map { SequenceExtras.Disc(number: $0 + 1, x: CGFloat($1.x1), y: CGFloat($1.y)) }
        }

        positioned.content = .sequenceDiagram(actors: actors, messages: messages, blocks: blocks, lifelines: lifelines, activations: activations, notes: notes)
        return extras
    }

    /// Draws the stacked labels (11 pt, muted, 13 pt pitch, upward from the arrow) and the autonumber discs (r = 8, 1-based)
    /// into an unflipped CGContext of `pixelHeight` at `scale` (points → pixels).
    static func drawSequenceExtras(_ extras: SequenceExtras, in ctx: CGContext, theme: DiagramTheme, scale: CGFloat, pixelHeight: CGFloat) {
        guard !extras.stackedLabels.isEmpty || !extras.autonumberDiscs.isEmpty else { return }
        let muted = theme.effectiveMuted().cgColor
        for label in extras.stackedLabels {
            let font = CTFontCreateWithName("Helvetica" as CFString, label.fontSize * scale, nil)
            for (i, line) in label.lines.reversed().enumerated() {
                let baseline = label.y - CGFloat(i) * label.pitch                 // diagram points, top-left origin
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: theme.effectiveMuted()]
                let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: attrs))
                ctx.saveGState()
                ctx.textPosition = CGPoint(x: label.x * scale, y: pixelHeight - baseline * scale)
                CTLineDraw(ctLine, ctx)
                ctx.restoreGState()
            }
        }
        let r = MDVMermaidPipeline.autonumberRadius * scale
        for disc in extras.autonumberDiscs {
            let centre = CGPoint(x: disc.x * scale, y: pixelHeight - disc.y * scale)
            ctx.setFillColor(theme.foreground.cgColor)
            ctx.fillEllipse(in: CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r))
            let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 9 * scale, nil)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: theme.background]
            let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: "\(disc.number)", attributes: attrs))
            let bounds = CTLineGetBoundsWithOptions(ctLine, [.useOpticalBounds])
            ctx.textPosition = CGPoint(x: centre.x - bounds.width / 2, y: centre.y - bounds.height / 2 + 1 * scale)
            CTLineDraw(ctLine, ctx)
        }
        _ = muted
    }
}
