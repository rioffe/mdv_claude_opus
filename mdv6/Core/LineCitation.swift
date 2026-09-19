// LineCitation — C-19: GitHub-style line citations (`#L10`, `#L10-L12`) in a link fragment. The fragment is tested
// against C-19.1's grammar *before* C-11 slug matching (R-19) and resolves to a block through the C-02 rule 8 map.
import Foundation

/// C-19.1/C-19.2: a parsed line citation. `first`/`last` are the fragment's line numbers as written; the range is
/// resolved by `startLine` only (the end is informational, C-19.3).
public struct LineCitation: Equatable, Sendable {
    public let first: Int
    public let last: Int?

    public init(first: Int, last: Int? = nil) {
        self.first = first
        self.last = last
    }

    /// C-19.2: `min(first, last)` — a reversed range (`#L12-L10`) is read as the range it names, not as an error.
    public var startLine: Int { last.map { min(first, $0) } ?? first }

    /// C-19.1: the anchored, case-insensitive grammar `^L([1-9][0-9]*)(?:-(?:L)?([1-9][0-9]*))?$`, applied to the
    /// already-decoded fragment. The leading digit excludes `0`, so `#L0` and `#L00` are not citations (their
    /// fall-through to C-11 slug matching is E-06, not a clamp to the end of the document — F-128).
    public static func parse(_ fragment: String) -> LineCitation? {
        var rest = Substring(fragment)
        guard let lead = rest.first, lead == "L" || lead == "l" else { return nil }
        rest = rest.dropFirst()
        guard let first = number(&rest) else { return nil }
        if rest.isEmpty { return LineCitation(first: first, last: nil) }
        guard rest.first == "-" else { return nil }
        rest = rest.dropFirst()
        if let marker = rest.first, marker == "L" || marker == "l" { rest = rest.dropFirst() }
        guard let last = number(&rest), rest.isEmpty else { return nil }
        return LineCitation(first: first, last: last)
    }

    /// One run of ASCII digits with no leading zero (C-19.1: `[1-9][0-9]*`); nil when the run is absent, zero-leading
    /// or too large to be a line number.
    private static func number(_ rest: inout Substring) -> Int? {
        let run = rest.prefix { $0.isASCII && $0.isNumber }
        guard let head = run.first, head != "0", run.count <= 9, let value = Int(run) else { return nil }
        rest = rest.dropFirst(run.count)
        return value
    }
}

/// C-19.3 / C-02 rule 8 / E-31: the block a citation targets — the last block whose first source line is at or before
/// the resolved start line. A line past `lineCount` or inside a run of lines the split removed clamps to that block;
/// a line before the first block resolves to the first block; a document with no blocks has no target.
public func lineCitationBlock(_ citation: LineCitation, in document: ParsedDocument) -> Int? {
    guard !document.blocks.isEmpty else { return nil }
    let line = citation.startLine
    var target: Int?
    for (index, range) in document.blockLines.enumerated() where range.lowerBound <= line {
        target = index
    }
    return target ?? 0
}