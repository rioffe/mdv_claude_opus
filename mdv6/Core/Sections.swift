// Sections — C-12: section ranges for heading copy (R-22) and inline-Markdown stripping (R-27, C-02 rule 7).
import Foundation

/// C-12: blocks `[i, j)` where `j` is the next TOC heading (C-02 rule 7) with level ≤ the level of `i`, or the block count.
public func sectionRange(blocks: [String], tocHeadings: [TOCHeading], headingAt i: Int) -> Range<Int> {
    guard let heading = tocHeadings.first(where: { $0.blockIndex == i }) else { return i..<min(i + 1, blocks.count) }
    let end = tocHeadings.first { $0.blockIndex > i && $0.level <= heading.level }?.blockIndex ?? blocks.count
    return i..<end
}

/// C-12 copy output: the section's blocks joined with `\n\n`.
public func sectionMarkdown(blocks: [String], tocHeadings: [TOCHeading], headingAt i: Int) -> String {
    blocks[sectionRange(blocks: blocks, tocHeadings: tocHeadings, headingAt: i)].joined(separator: "\n\n")
}

/// C-12: removes trailing `#`s, `**`, `__`, backticks, unescaped `*`, both underscores of an `_…_` pair whose opening
/// `_` is not preceded by a letter or digit (word-internal underscores are kept), and reduces `[text](url)` to `text`.
public func stripInlineMarkdown(_ input: String) -> String {
    var s = input
    // trailing closing #s
    while let last = s.last, last == "#" || last == " " {
        if last == "#" || s.hasSuffix(" #") || s.dropLast().last == "#" { s.removeLast() } else { break }
    }
    s = s.trimmingCharacters(in: .whitespaces)
    // links: [text](url) -> text
    s = replaceLinks(s)
    // `_…_` pairs whose opener is not preceded by a letter/digit
    s = stripUnderscorePairs(s)
    var out = ""
    var chars = Array(s)
    var i = 0
    while i < chars.count {
        let c = chars[i]
        if c == "\\", i + 1 < chars.count, "*_`#[]\\".contains(chars[i + 1]) {   // a Markdown escape: keep the character
            out.append(chars[i + 1]); i += 2; continue
        }
        if c == "*" || c == "`" { i += 1; continue }
        if c == "_", i + 1 < chars.count, chars[i + 1] == "_" { i += 2; continue }   // __
        out.append(c); i += 1
    }
    chars = []
    return out.trimmingCharacters(in: .whitespaces)
}

private func replaceLinks(_ s: String) -> String {
    var out = ""
    var rest = Substring(s)
    while let open = rest.firstIndex(of: "[") {
        guard let close = rest[open...].firstIndex(of: "]"),
              rest.index(after: close) < rest.endIndex, rest[rest.index(after: close)] == "(",
              let paren = rest[rest.index(after: close)...].firstIndex(of: ")") else {
            out += rest[..<rest.index(after: open)]
            rest = rest[rest.index(after: open)...]
            continue
        }
        out += rest[..<open]
        out += rest[rest.index(after: open)..<close]
        rest = rest[rest.index(after: paren)...]
    }
    out += rest
    return out
}

private func stripUnderscorePairs(_ s: String) -> String {
    let chars = Array(s)
    var drop = Set<Int>()
    var i = 0
    while i < chars.count {
        if chars[i] == "_", i + 1 < chars.count, chars[i + 1] == "_" { i += 2; continue }   // `__` is handled by the caller
        if chars[i] == "_" {
            let prevOK = i == 0 || !(chars[i - 1].isLetter || chars[i - 1].isNumber)
            if prevOK, i + 1 < chars.count, !chars[i + 1].isWhitespace {
                // find the closing single underscore
                var j = i + 1
                while j < chars.count {
                    if chars[j] == "_", j + 1 < chars.count, chars[j + 1] == "_" { j += 2; continue }
                    if chars[j] == "_" && !chars[j - 1].isWhitespace { break }
                    j += 1
                }
                if j < chars.count {
                    drop.insert(i); drop.insert(j)
                    i = j + 1
                    continue
                }
            }
        }
        i += 1
    }
    return String(chars.enumerated().filter { !drop.contains($0.offset) }.map(\.element))
}
