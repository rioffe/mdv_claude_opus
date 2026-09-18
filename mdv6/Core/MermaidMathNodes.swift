// MermaidMathNodes — R-15 / C-06.2: a whole-label `$$…$$` node is typeset with SwiftMath (16 pt, K-08) behind a blank
// placeholder sized to the image and composited centred at a pixel-snapped origin (I-009); mixed and edge labels use
// the C-07.3 Unicode form.
import Foundation
import AppKit
import BeautifulMermaid

enum MermaidMathNodes {
    struct Plan { let id: String; let latex: String; let image: NSImage }

    /// Pre-layout: replaces whole-`$$` labels by a placeholder the layout measures to the image's size; converts other
    /// math in node and edge labels to Unicode.
    static func plan(_ model: inout ParsedGraphModel, theme: DiagramTheme) -> [Plan] {
        var plans: [Plan] = []
        let color = rgba(theme.foreground)
        for i in model.nodesInOrder.indices {
            let label = model.nodesInOrder[i].node.label
            if let latex = wholeDisplayMath(label) {
                let spec = MathSpec(latex: latex, fontSize: MDVMermaidPipeline.mathLabelFontSize, color: color, display: true)
                if case .image(let image, _, _) = MathImageCache.shared.rendered(for: spec, scale: 2) {
                    model.nodesInOrder[i].node.label = placeholder(for: image.size)
                    plans.append(Plan(id: model.nodesInOrder[i].id, latex: latex, image: image))
                    continue
                }
            }
            if label.contains("$") { model.nodesInOrder[i].node.label = MathMarkdown.plainText(label) }
        }
        for i in model.edges.indices {
            if let l = model.edges[i].label, l.contains("$") { model.edges[i].label = MathMarkdown.plainText(l) }
        }
        return plans
    }

    /// Post-layout: attach the node rects.
    static func resolve(_ plans: [Plan], positioned: PositionedGraph) -> [MathNodePlan] {
        let nodes: [PositionedNode]
        switch positioned.content {
        case .flowchart(let n, _, _), .stateDiagram(let n, _, _): nodes = n
        default: nodes = []
        }
        return plans.compactMap { plan in
            guard let node = nodes.first(where: { $0.id == plan.id }) else { return nil }
            return MathNodePlan(nodeId: plan.id, latex: plan.latex, fontSize: MDVMermaidPipeline.mathLabelFontSize, image: plan.image,
                                imageSize: plan.image.size, nodeRect: CGRect(x: node.x, y: node.y, width: node.width, height: node.height))
        }
    }

    /// The LaTeX of a label that is exactly one `$$…$$` span, else nil.
    static func wholeDisplayMath(_ label: String) -> String? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let spans = MathMarkdown.spans(in: trimmed)
        guard spans.count == 1, spans[0].display, spans[0].range.lowerBound == trimmed.startIndex, spans[0].range.upperBound == trimmed.endIndex else { return nil }
        return spans[0].latex.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A blank label the library measures (13 pt, weight 500, 0.3 em per space, 1.3 line height) to at least the image
    /// size plus 4 pt on each side.
    static func placeholder(for size: CGSize) -> String {
        let fontSize = original_src_styles.FONT_SIZES.nodeLabel
        let spaceWidth = original_src_text_metrics.measureTextWidth("  ", fontSize: fontSize, fontWeight: original_src_styles.FONT_WEIGHTS.nodeLabel)
            - original_src_text_metrics.measureTextWidth(" ", fontSize: fontSize, fontWeight: original_src_styles.FONT_WEIGHTS.nodeLabel)
        let minPadding = original_src_text_metrics.measureTextWidth("", fontSize: fontSize, fontWeight: original_src_styles.FONT_WEIGHTS.nodeLabel)
        let spaces = max(1, Int(ceil((Double(size.width) + 8 - minPadding) / max(spaceWidth, 0.1))))
        let lineHeight = fontSize * original_src_text_metrics.LINE_HEIGHT_RATIO
        let lines = max(1, Int(ceil((Double(size.height) + 8) / lineHeight)))
        return Array(repeating: String(repeating: " ", count: spaces), count: lines).joined(separator: "\n")
    }

    static func rgba(_ c: NSColor) -> RGBA {
        let d = c.usingColorSpace(.deviceRGB) ?? c
        return RGBA(r: UInt8((d.redComponent * 255).rounded()), g: UInt8((d.greenComponent * 255).rounded()), b: UInt8((d.blueComponent * 255).rounded()), a: 255)
    }
}
