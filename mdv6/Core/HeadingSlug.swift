// headingSlug — C-11, GitHub-compatible heading slugs (I-010, D-20).
import Foundation

/// C-11: lower-case; keep letters and digits; keep `-`/`_` when something precedes them; drop every other
/// non-whitespace character; every whitespace run becomes one `-` when something precedes it; strip trailing `-`/`_`.
public func headingSlug(_ s: String) -> String {
    var out = ""
    var inRun = false            // inside a whitespace run; any non-whitespace character (kept or dropped) ends it
    for ch in s.lowercased() {
        if ch.isWhitespace {
            if !inRun {
                inRun = true
                if !out.isEmpty { out.append("-") }
            }
            continue
        }
        inRun = false
        if ch.isLetter || ch.isNumber {
            out.append(ch)
        } else if ch == "-" || ch == "_" {
            if !out.isEmpty { out.append(ch) }
        }
        // every other non-whitespace character is dropped (it still ends a whitespace run: `C++ & Rust` → `c--rust`)
    }
    while let last = out.last, last == "-" || last == "_" { out.removeLast() }
    return out
}
