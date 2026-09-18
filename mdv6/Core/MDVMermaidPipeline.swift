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
