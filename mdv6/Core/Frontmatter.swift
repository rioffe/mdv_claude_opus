// Frontmatter — C-20.1 recognition and C-20.2 row reduction (R-44). A display reduction, not a YAML/TOML parser.
import Foundation

/// One row of the properties table (C-20.3); `key == nil` is a keyless row spanning the table's width.
public struct FrontmatterRow: Equatable, Sendable {
    public let key: String?
    public let value: String
    public init(key: String?, value: String) { self.key = key; self.value = value }
}

/// A recognised header in a C-02 rule 6 normalised document (C-02 rule 9).
public struct FrontmatterSpan: Equatable {
    /// The opening fence line through the closing fence line, no trailing newline.
    public let block: String
    /// 1-based line of the closing fence.
    public let closingLine: Int
    /// Index of the first character after the closing fence's line break (`endIndex` when it is the last line).
    public let bodyStart: String.Index
}

/// C-20.1: line 1 exactly `---` (YAML) or `+++` (TOML); the first later line exactly a closer (`---`/`...` or `+++`);
/// every YAML line before it YAML-shaped; and at least one C-20.2 row (the zero-row rule, F-150). Else nil (E-32).
public func frontmatterSpan(in normalized: String) -> FrontmatterSpan? {
    let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
    guard let opening = lines.first, opening == "---" || opening == "+++" else { return nil }
    let isYAML = opening == "---"
    let closers: Set<Substring> = isYAML ? ["---", "..."] : ["+++"]
    var offset = normalized.utf8.index(normalized.startIndex, offsetBy: opening.utf8.count)
    for (i, line) in lines.enumerated().dropFirst() {
        offset = normalized.utf8.index(offset, offsetBy: 1)              // the "\n" before this line
        let lineEnd = normalized.utf8.index(offset, offsetBy: line.utf8.count)
        if closers.contains(line) {
            let block = String(normalized[normalized.startIndex ..< lineEnd])
            guard !frontmatterRows(block).isEmpty else { return nil }    // zero-row rule
            let bodyStart = lineEnd < normalized.endIndex ? normalized.utf8.index(after: lineEnd) : lineEnd
            return FrontmatterSpan(block: block, closingLine: i + 1, bodyStart: bodyStart)
        }
        if isYAML && !looksLikeYAML(line) { return nil }
        offset = lineEnd
    }
    return nil                                                            // no closer anywhere
}

/// C-20.1's YAML guard for one line: empty, a continuation (leading space/tab), a comment, a sequence item, or a mapping.
private func looksLikeYAML(_ line: Substring) -> Bool {
    guard let first = line.first else { return true }
    if first == " " || first == "\t" || first == "#" { return true }
    return isSequenceItem(line) || mappingColon(line) != nil
}

private func isSequenceItem(_ line: Substring) -> Bool { line == "-" || line.hasPrefix("- ") }

/// The first `:` followed by a space, a tab, or the end of the line (YAML's mapping rule).
private func mappingColon(_ line: Substring) -> Substring.Index? {
    var i = line.startIndex
    while let colon = line[i...].firstIndex(of: ":") {
        let next = line.index(after: colon)
        if next == line.endIndex || line[next] == " " || line[next] == "\t" { return colon }
        i = next
    }
    return nil
}

private func isBlank(_ line: Substring) -> Bool { line.allSatisfy { $0 == " " || $0 == "\t" } }

/// C-20.2: reduce a header block (fences included) to display rows. Never rejects.
public func frontmatterRows(_ block: String) -> [FrontmatterRow] {
    var lines = block.split(separator: "\n", omittingEmptySubsequences: false)
    guard let opening = lines.first else { return [] }
    let isTOML = opening == "+++"
    if opening == "---" || opening == "+++" { lines.removeFirst() }
    if let last = lines.last, last == "---" || last == "..." || last == "+++" { lines.removeLast() }

    var rows: [FrontmatterRow] = []
    var i = 0
    while i < lines.count {
        let line = lines[i]
        i += 1
        if isBlank(line) || line.first == "#" { continue }
        if isTOML {
            rows.append(tomlRow(line, lines: lines, cursor: &i))
        } else if isSequenceItem(line) {
            rows.append(FrontmatterRow(key: nil, value: String(line)))
        } else if let colon = mappingColon(line) {
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            let scalar = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            var group: [Substring] = []
            while i < lines.count, isBlank(lines[i]) || lines[i].first == " " || lines[i].first == "\t" {
                group.append(lines[i]); i += 1
            }
            while let last = group.last, isBlank(last) { group.removeLast() }
            rows.append(FrontmatterRow(key: unquoted(key), value: yamlValue(scalar, dedented(group))))
        } else {
            rows.append(FrontmatterRow(key: nil, value: line.trimmingCharacters(in: .whitespaces)))
        }
    }
    return rows
}

private func yamlValue(_ scalar: String, _ group: [String]) -> String {
    if group.isEmpty { return unquoted(scalar) }
    switch scalar {
    case ">", ">-", ">+": return folded(group)
    case "|", "|-", "|+", "": return group.joined(separator: "\n")
    default: return ([scalar] + group).joined(separator: "\n")
    }
}

/// YAML `>`: consecutive non-empty lines join with one space; a run of k empty lines becomes k line breaks.
private func folded(_ group: [String]) -> String {
    var out = ""
    var breaks = 0
    for line in group {
        if line.trimmingCharacters(in: .whitespaces).isEmpty { breaks += 1; continue }
        if out.isEmpty { out = line } else { out += breaks > 0 ? String(repeating: "\n", count: breaks) : " "; out += line }
        breaks = 0
    }
    return out
}

private func tomlRow(_ line: Substring, lines: [Substring], cursor: inout Int) -> FrontmatterRow {
    let text = line.trimmingCharacters(in: .whitespaces)
    if text.hasPrefix("[") { return FrontmatterRow(key: text, value: "") }
    guard let eq = text.firstIndex(of: "=") else { return FrontmatterRow(key: nil, value: text) }
    let key = text[..<eq].trimmingCharacters(in: .whitespaces)
    let value = text[text.index(after: eq)...].trimmingCharacters(in: .whitespaces)
    var depth = bracketDepth(Substring(value))
    guard depth > 0 else { return FrontmatterRow(key: key, value: unquoted(value)) }
    var group: [Substring] = []
    while cursor < lines.count, depth > 0 {
        group.append(lines[cursor]); depth += bracketDepth(lines[cursor]); cursor += 1
    }
    return FrontmatterRow(key: key, value: ([value] + dedented(group)).joined(separator: "\n"))
}

/// `[` minus `]`, ignoring brackets inside quotes and everything after an unquoted `#`.
private func bracketDepth(_ text: Substring) -> Int {
    var depth = 0
    var quote: Character? = nil
    for c in text {
        if let q = quote { if c == q { quote = nil }; continue }
        switch c {
        case "\"", "'": quote = c
        case "[": depth += 1
        case "]": depth -= 1
        case "#": return depth
        default: break
        }
    }
    return depth
}

/// Drop the smallest leading indent shared by the group's non-blank lines; blank lines become empty.
private func dedented(_ group: [Substring]) -> [String] {
    let indent = group.filter { !isBlank($0) }.map { $0.prefix(while: { $0 == " " || $0 == "\t" }).count }.min() ?? 0
    return group.map { isBlank($0) ? "" : String($0.dropFirst(indent)) }
}

/// One matching pair of surrounding `"` or `'` (at least two characters).
private func unquoted(_ text: String) -> String {
    guard text.count >= 2, let f = text.first, text.last == f, f == "\"" || f == "'" else { return text }
    return String(text.dropFirst().dropLast())
}
