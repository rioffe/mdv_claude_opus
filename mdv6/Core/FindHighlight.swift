// FindHighlight — the R-24 find model's pure half: occurrence counting over block source, the E-17 tint-vs-highlight
// rule, and the inline-highlighted rendering of a matching block (D-21).
import Foundation
import SwiftUI

/// R-24: one occurrence in document order.
public struct FindMatch: Equatable, Sendable {
    public let blockIndex: Int
    /// 0-based occurrence within the block.
    public let occurrence: Int
    public init(blockIndex: Int, occurrence: Int) { self.blockIndex = blockIndex; self.occurrence = occurrence }
}

/// R-24: the open find bar's state — `query` is matched verbatim; `matches` counts occurrences; `current` indexes them.
public struct FindState: Equatable, Sendable {
    public var query: String
    public var matches: [FindMatch]
    public var current: Int

    public init(query: String = "", matches: [FindMatch] = [], current: Int = 0) {
        self.query = query; self.matches = matches; self.current = current
    }

    /// "n of m" or "No matches".
    public var label: String { matches.isEmpty ? "No matches" : "\(current + 1) of \(matches.count)" }
    public var canStep: Bool { !matches.isEmpty }
    public var currentBlock: Int? { matches.isEmpty ? nil : matches[current].blockIndex }
    public func tint(for block: Int) -> FindTint {
        guard matches.contains(where: { $0.blockIndex == block }) else { return .none }
        return currentBlock == block ? .strong : .weak
    }
}

public enum FindTint: Equatable, Sendable { case none, weak, strong }

public enum FindHighlight {
    /// R-24: case-insensitive substring occurrences of the verbatim query (no trimming, no diacritic folding); an empty
    /// query has none. Overlapping occurrences are counted from the end of the previous one.
    public static func countOccurrences(query: String, in block: String) -> Int {
        guard !query.isEmpty else { return 0 }
        var count = 0
        var range = block.startIndex..<block.endIndex
        while let found = block.range(of: query, options: [.caseInsensitive], range: range) {
            count += 1
            range = found.upperBound..<block.endIndex
        }
        return count
    }

    /// R-24: every occurrence over every block, in document order.
    public static func matches(query: String, blocks: [String]) -> [FindMatch] {
        var out: [FindMatch] = []
        for (i, block) in blocks.enumerated() {
            for k in 0..<countOccurrences(query: query, in: block) { out.append(FindMatch(blockIndex: i, occurrence: k)) }
        }
        return out
    }

    /// E-17: a code fence, a `$$` math fence, a GFM table, or any block containing `![` is tinted as a whole; every other
    /// matching block is inline-highlighted.
    public static func shouldInlineHighlight(block: String) -> Bool {
        if ParsedDocument.isFence(block) || ParsedDocument.isMathFence(block) || ParsedDocument.isGFMTable(block) { return false }
        if block.contains("![") { return false }
        return true
    }

    /// R-24: the block re-rendered as inline text — leading `#`, `>` and ordered-list markers stripped, `-`/`*`/`+`
    /// bullets shown as `•`, inline Markdown interpreted, math left as `$…$` source — with every occurrence marked.
    public static func highlightedAttributedString(block: String, query: String, theme: MDVTheme) -> AttributedString {
        let text = inlineText(block)
        var out = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
        out.foregroundColor = theme.text
        guard !query.isEmpty else { return out }
        let plain = String(out.characters)
        var search = plain.startIndex..<plain.endIndex
        while let r = plain.range(of: query, options: [.caseInsensitive], range: search) {
            if let lo = AttributedString.Index(r.lowerBound, within: out), let hi = AttributedString.Index(r.upperBound, within: out), lo < hi {
                out[lo..<hi].backgroundColor = theme.accent.opacity(0.35)
                out[lo..<hi][FindMarkKey.self] = true
            }
            search = r.upperBound..<plain.endIndex
        }
        return out
    }

    /// Marks a highlighted occurrence (for tests).
    public enum FindMarkKey: AttributedStringKey { public typealias Value = Bool; public static let name = "mdv6.findMark" }

    /// The line-level rewrite R-24 describes.
    public static func inlineText(_ block: String) -> String {
        block.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            var s = Substring(line)
            let indent = s.prefix { $0 == " " || $0 == "\t" }
            s = s.dropFirst(indent.count)
            if s.hasPrefix("#") { s = s.drop { $0 == "#" }.drop { $0 == " " } }
            while s.hasPrefix(">") { s = s.dropFirst().drop { $0 == " " } }
            if let m = s.firstIndex(where: { !$0.isNumber }), m > s.startIndex, s[m] == "." || s[m] == ")", s.index(after: m) < s.endIndex, s[s.index(after: m)] == " " {
                s = s[s.index(m, offsetBy: 2)...]
            } else if (s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("+ ")) {
                s = "• " + s.dropFirst(2)
            }
            return String(indent) + String(s)
        }.joined(separator: "\n")
    }

    /// The number of marked occurrences in a highlighted string (tests: counted ≠ marked, E-17).
    public static func markedCount(_ s: AttributedString) -> Int {
        s.runs.filter { $0[FindMarkKey.self] == true }.count
    }
}
