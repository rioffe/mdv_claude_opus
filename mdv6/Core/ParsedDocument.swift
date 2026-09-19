// ParsedDocument — the C-02 block split, computed once per load (R-04, I-004).
import Foundation

/// One single-line ATX `#`–`###` heading (C-02 rule 7); `text` is the display form, `slugText` feeds C-11.
public struct TOCHeading: Equatable {
    public let level: Int
    public let text: String
    public let slugText: String
    public let blockIndex: Int

    public init(level: Int, text: String, slugText: String, blockIndex: Int) {
        self.level = level
        self.text = text
        self.slugText = slugText
        self.blockIndex = blockIndex
    }
}

/// C-02: the document split into blocks. Equality is on `raw` (the split is a pure function of it, I-004).
public struct ParsedDocument: Equatable {
    public let raw: String
    public let blocks: [String]
    /// C-02 rule 8: half-open 1-based source-line ranges, one per block — `blockLines[i]` covers exactly `blocks[i]`.
    public let blockLines: [Range<Int>]
    /// C-02 rule 8: the normalised line count (rule 6; a trailing newline adds no empty final line).
    public let lineCount: Int
    public let tocHeadings: [TOCHeading]

    public init(raw: String) {
        self.raw = raw
        let split = ParsedDocument.split(raw)                 // one split per load (I-004)
        self.blocks = split.blocks
        self.blockLines = split.lines
        self.lineCount = split.lineCount
        self.tocHeadings = ParsedDocument.parseTOC(blocks: split.blocks)
    }

    public static func == (a: ParsedDocument, b: ParsedDocument) -> Bool { a.raw == b.raw }

    // MARK: rules

    /// C-02 rule 6: `\r\n` and lone `\r` are treated as `\n` before splitting.
    public static func normalizeLineEndings(_ s: String) -> String {
        guard s.unicodeScalars.contains("\r") else { return s }   // "\r\n" is one Character; test scalars
        return s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    /// C-02 rules 1–8 in one pass: the blocks, their half-open 1-based source-line ranges (rule 8), and the line count.
    /// `blocks[i]` is exactly `lines[i]` of the normalised input, with rule 5's trimming applied (I-004).
    public static func split(_ input: String) -> (blocks: [String], lines: [Range<Int>], lineCount: Int) {
        var lines = normalizeLineEndings(input).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last == "" { lines.removeLast() }        // rule 8: a trailing newline adds no empty final line
        var blocks: [String] = []
        var ranges: [Range<Int>] = []
        var current: [String] = []
        var start: Int? = nil                             // 1-based line of `current[0]`
        var fence: String? = nil        // "```" or "~~~" while inside a code fence (rule 2)
        var inMathFence = false         // rule 3

        func append(_ line: String, at lineNo: Int) {
            if start == nil { start = lineNo }
            current.append(line)
        }
        func flush() {
            let trimmed = trimNewlines(current.joined(separator: "\n"))
            if !trimmed.isEmpty, let s = start {
                blocks.append(trimmed)
                ranges.append(s ..< (s + current.count))
            }
            current = []
            start = nil
        }

        for (i, line) in lines.enumerated() {
            let lineNo = i + 1
            if let marker = fence {
                append(line, at: lineNo)
                if leadingNonSpace(line).hasPrefix(marker) { fence = nil }
                continue
            }
            if inMathFence {
                append(line, at: lineNo)
                if line.contains("$$") { inMathFence = false }
                continue
            }
            if isBlank(line) {          // rule 1
                flush()
                continue
            }
            let head = leadingNonSpace(line)
            if head.hasPrefix("```") {  // rule 2
                fence = "```"
                append(line, at: lineNo)
                continue
            }
            if head.hasPrefix("~~~") {
                fence = "~~~"
                append(line, at: lineNo)
                continue
            }
            if head.hasPrefix("$$") && !head.dropFirst(2).contains("$$") {   // rule 3
                inMathFence = true
                append(line, at: lineNo)
                continue
            }
            append(line, at: lineNo)
        }
        flush()
        return (blocks, ranges, lines.count)
    }

    /// C-02 rules 1–6 (fences per E-23: any run of the same three-character marker closes; unclosed runs to the end;
    /// indented code is not recognised). A thin wrapper over `split`, so the blocks and their line map cannot drift.
    public static func parseBlocks(_ input: String) -> [String] {
        split(input).blocks
    }

    /// C-02 rule 7: `#`/`##`/`###` single-line ATX headings outside fences, first line only.
    public static func parseTOC(blocks: [String]) -> [TOCHeading] {
        var out: [TOCHeading] = []
        for (i, block) in blocks.enumerated() {
            if isFence(block) { continue }
            let trimmed = block.trimmingCharacters(in: .whitespaces)
            guard let level = atxLevel(trimmed) else { continue }
            let firstLine = trimmed.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? trimmed
            let body = String(firstLine.dropFirst(level + 1))
            let stripped = stripInlineMarkdown(body)
            out.append(TOCHeading(level: level,
                                  text: MathMarkdown.plainText(stripped),
                                  slugText: stripped,
                                  blockIndex: i))
        }
        return out
    }

    /// Level 1…3 when the text starts with `# `, `## ` or `### ` (E-22: h4–h6 are never TOC headings).
    public static func atxLevel(_ text: String) -> Int? {
        for level in 1...3 {
            let prefix = String(repeating: "#", count: level) + " "
            if text.hasPrefix(prefix) { return level }
        }
        return nil
    }

    /// A block whose first non-space characters are ` ``` ` or `~~~` (rule 2).
    public static func isFence(_ block: String) -> Bool {
        let head = leadingNonSpace(block)
        return head.hasPrefix("```") || head.hasPrefix("~~~")
    }

    /// A rule-3 math fence: first line is `$$` alone (no second `$$` on that line) and the block spans more than one line.
    public static func isMathFence(_ block: String) -> Bool {
        let firstLine = block.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? block
        let head = leadingNonSpace(firstLine)
        guard head.hasPrefix("$$"), !head.dropFirst(2).contains("$$") else { return false }
        return block.contains("\n")
    }

    /// R-24: a GFM table — first line contains `|`, second line consists only of `-`, `:`, `|`, space.
    public static func isGFMTable(_ block: String) -> Bool {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 2, lines[0].contains("|") else { return false }
        let second = lines[1].trimmingCharacters(in: .whitespaces)
        guard !second.isEmpty, second.contains("-") else { return false }
        return second.allSatisfy { "-:| ".contains($0) }
    }

    // MARK: helpers

    static func isBlank(_ line: String) -> Bool { line.allSatisfy { $0.isWhitespace } }

    static func leadingNonSpace(_ line: String) -> Substring {
        line.drop(while: { $0 == " " || $0 == "\t" })
    }

    static func trimNewlines(_ s: String) -> String {
        var sub = Substring(s)
        while sub.first == "\n" { sub = sub.dropFirst() }
        while sub.last == "\n" { sub = sub.dropLast() }
        return String(sub)
    }
}
