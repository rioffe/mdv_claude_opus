// MermaidDispatch — C-06.4 native/web dispatch by the first directive line, and C-06.1 rule 0 (R-10, R-46).
import Foundation

public enum MermaidDispatch {

    /// C-06.4: skip blank lines, `%%` comments, `%%{…}%%` directives (single- or multi-line) and a leading `---` block.
    /// Returns (the lower-cased first directive line or "", the indices of the skipped non-front-matter lines).
    static func scan(_ source: String) -> (line: String, skipped: [Int]) {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
        var skipped: [Int] = []
        var inFront = false, inDirective = false
        for (i, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
            if inFront { if line == "---" { inFront = false }; continue }
            if inDirective { skipped.append(i); if line.contains("}%%") { inDirective = false }; continue }
            if line.isEmpty { skipped.append(i); continue }
            if line == "---" { inFront = true; continue }
            if line.hasPrefix("%%{") { skipped.append(i); if !line.contains("}%%") { inDirective = true }; continue }
            if line.hasPrefix("%%") { skipped.append(i); continue }
            return (line.lowercased(), skipped)
        }
        return ("", skipped)
    }

    /// C-06.4: the first directive line, lower-cased; "" when there is none.
    public static func firstDirectiveLine(_ source: String) -> String { scan(source).line }

    /// C-06.4: native exactly for `flowchart`, `graph`, `sequencediagram`, `classdiagram`, `erdiagram` (alone or followed
    /// by whitespace) and lines starting `statediagram` or `xychart`; every other line, and none, is the web path.
    public static func isNative(_ source: String) -> Bool {
        let first = firstDirectiveLine(source)
        for keyword in ["flowchart", "graph", "sequencediagram", "classdiagram", "erdiagram"] where first.hasPrefix(keyword) {
            let rest = first.dropFirst(keyword.count)
            if rest.isEmpty || rest.first!.isWhitespace { return true }
        }
        return first.hasPrefix("statediagram") || first.hasPrefix("xychart")
    }

    /// C-06.1 rule 0: drop exactly the preamble lines C-06.4 skipped, keeping a front-matter block for rule 1.
    public static func stripPreamble(_ source: String) -> String {
        let skipped = Set(scan(source).skipped)
        guard !skipped.isEmpty else { return source }
        return source.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            .filter { !skipped.contains($0.offset) }.map { String($0.element) }.joined(separator: "\n")
    }
}
