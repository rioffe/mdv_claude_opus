// SmartTypography — C-10 `smartenMarkdown` (R-17, I-012). Applied to one C-02 block after math rewriting (§3.2).
import Foundation

/// C-10: returns the block unchanged if it is a fence, a GFM table or a thematic-break line; otherwise, outside inline
/// code spans, link/image URL parts and `<…>` spans: `"`/`'` → directional quotes chosen from the preceding character,
/// `---` → `—`, `--` between letters/digits → `–`, ` -- ` → ` — `, other `--` runs unchanged, `...` → `…`.
public func smartenMarkdown(_ block: String) -> String {
    if ParsedDocument.isFence(block) || ParsedDocument.isGFMTable(block) || isThematicBreak(block) { return block }
    let c = Array(block)
    var out = ""
    out.reserveCapacity(c.count)
    var i = 0
    var previous: Character? = nil          // the last character emitted (for quote direction)

    func emit(_ ch: Character) { out.append(ch); previous = ch }
    func emitVerbatim(_ range: Range<Int>) { for k in range { emit(c[k]) } }
    func opensQuote() -> Bool {
        guard let p = previous else { return true }
        return p.isWhitespace || "([{<“‘—–-/".contains(p)
    }

    while i < c.count {
        let ch = c[i]
        // inline code: a run of n backticks closes only on a run of exactly n
        if ch == "`" {
            var n = 0
            while i + n < c.count && c[i + n] == "`" { n += 1 }
            var j = i + n
            var end = -1
            while j < c.count {
                if c[j] == "`" {
                    var m = 0
                    while j + m < c.count && c[j + m] == "`" { m += 1 }
                    if m == n { end = j + m; break }
                    j += m
                } else { j += 1 }
            }
            if end > 0 { emitVerbatim(i..<end); i = end } else { emitVerbatim(i..<(i + n)); i += n }
            continue
        }
        // link / image URL part: `](` … matching `)`
        if ch == "]", i + 1 < c.count, c[i + 1] == "(" {
            var depth = 0
            var j = i + 1
            var end = -1
            while j < c.count {
                if c[j] == "(" { depth += 1 } else if c[j] == ")" { depth -= 1; if depth == 0 { end = j + 1; break } }
                j += 1
            }
            if end > 0 { emitVerbatim(i..<end); i = end; continue }
        }
        // `<…>` span
        if ch == "<", let close = c[i...].firstIndex(of: ">"), !c[(i + 1)..<close].contains("\n") {
            emitVerbatim(i..<(close + 1)); i = close + 1; continue
        }
        if ch == "-" {
            if i + 2 < c.count, c[i + 1] == "-", c[i + 2] == "-", !(i + 3 < c.count && c[i + 3] == "-") {
                emit("\u{2014}"); i += 3; continue                                   // --- → em dash
            }
            if i + 1 < c.count, c[i + 1] == "-", !(i + 2 < c.count && c[i + 2] == "-") {
                let before = i > 0 ? c[i - 1] : nil
                let after = i + 2 < c.count ? c[i + 2] : nil
                if let b = before, let a = after, (b.isLetter || b.isNumber), (a.isLetter || a.isNumber) {
                    emit("\u{2013}"); i += 2; continue                               // 10--20 → en dash
                }
                if before == " ", after == " " {
                    emit("\u{2014}"); i += 2; continue                               // ` -- ` → ` — `
                }
                emit("-"); emit("-"); i += 2; continue                               // other `--` runs unchanged
            }
            var n = 0
            while i + n < c.count && c[i + n] == "-" { n += 1 }
            if n >= 3 { emitVerbatim(i..<(i + n)); i += n; continue }               // longer runs unchanged
            emit("-"); i += 1; continue
        }
        if ch == ".", i + 2 < c.count, c[i + 1] == ".", c[i + 2] == "." {
            emit("\u{2026}"); i += 3; continue
        }
        if ch == "\"" {
            emit(opensQuote() ? "\u{201C}" : "\u{201D}"); i += 1; continue
        }
        if ch == "'" {
            emit(opensQuote() ? "\u{2018}" : "\u{2019}"); i += 1; continue
        }
        emit(ch); i += 1
    }
    return out
}

/// A thematic-break line: three or more `-`, `*` or `_` (optionally space-separated) and nothing else.
func isThematicBreak(_ block: String) -> Bool {
    let trimmed = block.trimmingCharacters(in: .whitespaces)
    guard let first = trimmed.first, "-*_".contains(first) else { return false }
    let stripped = trimmed.filter { $0 != " " }
    return stripped.count >= 3 && stripped.allSatisfy { $0 == first }
}
