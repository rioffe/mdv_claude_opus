// MathMarkdown — C-07.1 span detection and rewriting to `mdv6-math://` image references, and the C-07.3 plain-text
// form used by the TOC, bookmark titles and mixed Mermaid labels (R-12, R-13, E-07, I-010).
import Foundation

/// One math span found in a prose block. `range` covers the delimiters.
public struct MathSpan: Equatable {
    public let range: Range<String.Index>
    public let latex: String
    /// `$$…$$` (typeset `.display`, K-08) vs `$…$` (`.text`).
    public let display: Bool
    /// A `$$…$$` whose opener is at line start and closer at line end (one line or several) — emitted as its own paragraph.
    public let ownParagraph: Bool
}

public enum MathMarkdown {
    public static let scheme = "mdv6-math"

    // MARK: spans (Pandoc `tex_math_dollars` rules)

    /// C-07.1 delimiter rules: an opening `$` is followed by non-whitespace; a closing `$` is preceded by
    /// non-whitespace and not followed by a digit; a span contains no bare `$` and never crosses a backtick;
    /// `\$` is literal; fenced blocks are never rewritten; an empty `$$` pair is literal (E-07).
    public static func spans(in block: String) -> [MathSpan] {
        if ParsedDocument.isFence(block) { return [] }
        let chars = Array(block)
        var spans: [MathSpan] = []
        var i = 0
        func index(_ offset: Int) -> String.Index { block.index(block.startIndex, offsetBy: offset) }
        func atLineStart(_ pos: Int) -> Bool {
            var k = pos - 1
            while k >= 0 && chars[k] == " " { k -= 1 }
            return k < 0 || chars[k] == "\n"
        }
        func atLineEnd(_ pos: Int) -> Bool {   // pos = index just after the closer
            var k = pos
            while k < chars.count && chars[k] == " " { k += 1 }
            return k >= chars.count || chars[k] == "\n"
        }
        while i < chars.count {
            let c = chars[i]
            if c == "\\" { i += 2; continue }                       // `\$` and any escape: literal
            if c == "`" {                                            // inline code: skip the run
                var n = 0
                while i + n < chars.count && chars[i + n] == "`" { n += 1 }
                var j = i + n
                var closed = false
                while j < chars.count {
                    if chars[j] == "`" {
                        var m = 0
                        while j + m < chars.count && chars[j + m] == "`" { m += 1 }
                        if m == n { closed = true; j += m; break }
                        j += m
                    } else { j += 1 }
                }
                i = closed ? j : i + n
                continue
            }
            if c != "$" { i += 1; continue }
            // display `$$`
            if i + 1 < chars.count && chars[i + 1] == "$" {
                var j = i + 2
                var found = -1
                while j + 1 < chars.count {
                    if chars[j] == "\\" { j += 2; continue }
                    if chars[j] == "`" { break }                     // never crosses a backtick
                    if chars[j] == "$" && chars[j + 1] == "$" { found = j; break }
                    j += 1
                }
                if found >= 0 {
                    let latex = String(chars[(i + 2)..<found])
                    if latex.allSatisfy({ $0.isWhitespace }) {       // empty `$$` pair: literal
                        i = found + 2
                        continue
                    }
                    let own = atLineStart(i) && atLineEnd(found + 2)
                    spans.append(MathSpan(range: index(i)..<index(found + 2), latex: latex, display: true, ownParagraph: own))
                    i = found + 2
                    continue
                }
                i += 2
                continue
            }
            // inline `$`
            guard i + 1 < chars.count, !chars[i + 1].isWhitespace, chars[i + 1] != "$" else { i += 1; continue }
            var j = i + 1
            var closer = -1
            while j < chars.count {
                let d = chars[j]
                if d == "\\" { j += 2; continue }
                if d == "`" { break }                                 // never crosses a backtick
                if d == "$" {
                    let prevOK = !chars[j - 1].isWhitespace
                    let nextOK = j + 1 >= chars.count || !chars[j + 1].isNumber
                    if prevOK && nextOK { closer = j }
                    break                                             // a failed candidate is a bare `$`: no span
                }
                j += 1
            }
            if closer > i {
                let latex = String(chars[(i + 1)..<closer])
                spans.append(MathSpan(range: index(i)..<index(closer + 1), latex: latex, display: false, ownParagraph: false))
                i = closer + 1
            } else {
                i += 1
            }
        }
        return spans
    }

    // MARK: rewriting

    /// C-07.1: replaces each span with an image reference. `fontSize` is the body size (already zoomed, R-30);
    /// math inside an ATX heading is sized by that heading's em factor (R-13). Own-paragraph `$$` spans become
    /// their own paragraph (blank lines inserted, indentation preserved) so the block-image path centres them.
    public static func rewrite(_ block: String, fontSize: CGFloat, headingSizeEms: [CGFloat], color: RGBA) -> String {
        let found = spans(in: block)
        if found.isEmpty { return block }
        var size = fontSize
        if let level = headingLevel(of: block), level - 1 < headingSizeEms.count {
            size = fontSize * headingSizeEms[level - 1]
        }
        var out = ""
        var cursor = block.startIndex
        for span in found {
            out += block[cursor..<span.range.lowerBound]
            let spanURL = url(for: span, size: size, color: color)
            let ref = "![](" + spanURL + ")"
            if span.ownParagraph {
                registerOwnParagraph(spanURL)
                // keep the indentation of the opener's line; separate the image paragraph with blank lines
                var indent = ""
                var k = span.range.lowerBound
                while k > block.startIndex, block[block.index(before: k)] == " " { k = block.index(before: k); indent.append(" ") }
                out = String(out.dropLast(indent.count))
                if !out.isEmpty && !out.hasSuffix("\n\n") { out += out.hasSuffix("\n") ? "\n" : "\n\n" }
                out += indent + ref
                var after = span.range.upperBound
                while after < block.endIndex, block[after] == " " { after = block.index(after: after) }
                if after < block.endIndex { out += "\n\n" }
                cursor = after
                if cursor < block.endIndex, block[cursor] == "\n" { cursor = block.index(after: cursor) }
                continue
            }
            out += ref
            cursor = span.range.upperBound
        }
        out += block[cursor...]
        return out
    }

    /// C-07.1 placement: the URLs `rewrite` emitted as their own paragraph (centred by `MathDisplayView`); every other
    /// display URL that reaches the block-image path is an E-16 image-only paragraph (list item, table cell) and stays
    /// leading-aligned. Keyed by the full URL (latex, mode, size, colour).
    private static let ownParagraphLock = NSLock()
    nonisolated(unsafe) private static var ownParagraphURLs = Set<String>()

    static func registerOwnParagraph(_ url: String) { ownParagraphLock.lock(); ownParagraphURLs.insert(url); ownParagraphLock.unlock() }

    public static func isOwnParagraph(url: URL) -> Bool {
        ownParagraphLock.lock(); defer { ownParagraphLock.unlock() }
        return ownParagraphURLs.contains(url.absoluteString)
    }

    /// `mdv6-math://inline|display/<base64url(latex)>?s=<size, 1 decimal>&c=<RRGGBBAA>`.
    public static func url(for span: MathSpan, size: CGFloat, color: RGBA) -> String {
        url(latex: span.latex, display: span.display, size: size, color: color)
    }

    public static func url(latex: String, display: Bool, size: CGFloat, color: RGBA) -> String {
        let host = display ? "display" : "inline"
        return "\(scheme)://\(host)/\(base64url(latex))?s=\(String(format: "%.1f", Double(size)))&c=\(color.hex)"
    }

    /// Decodes an `mdv6-math://` URL (re-padding the base64url payload to a multiple of four); nil for anything else.
    public static func decode(url: URL) -> MathSpec? {
        guard url.scheme == scheme, let host = url.host, host == "inline" || host == "display" else { return nil }
        let payload = url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path
        guard let latex = base64urlDecode(payload) else { return nil }
        var size: CGFloat = 16
        var color = RGBA.black
        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for item in items {
                if item.name == "s", let v = item.value, let d = Double(v) { size = CGFloat(d) }
                if item.name == "c", let v = item.value, let c = RGBA(hex: v) { color = c }
            }
        }
        return MathSpec(latex: latex, fontSize: size, color: color, display: host == "display")
    }

    /// RFC 4648 §5 without `=` padding.
    public static func base64url(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    public static func base64urlDecode(_ s: String) -> String? {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let data = Data(base64Encoded: b) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// The ATX heading level (1…6) of a block whose first line is `#…# text`, else nil (R-13 sizing).
    public static func headingLevel(of block: String) -> Int? {
        let trimmed = block.drop(while: { $0 == " " })
        var n = 0
        for ch in trimmed { if ch == "#" { n += 1 } else { break } }
        guard n >= 1, n <= 6 else { return nil }
        let rest = trimmed.dropFirst(n)
        return rest.first == " " ? n : nil
    }

    // MARK: C-07.3 plain text

    /// C-07.3: every math span in `s` replaced by its Unicode approximation; text outside spans untouched.
    public static func plainText(_ s: String) -> String {
        let found = spans(in: s)
        if found.isEmpty { return s }
        var out = ""
        var cursor = s.startIndex
        for span in found {
            out += s[cursor..<span.range.lowerBound]
            out += latexToPlain(span.latex)
            cursor = span.range.upperBound
        }
        out += s[cursor...]
        return out
    }

    /// C-07.3 conversion of one LaTeX string (no delimiters).
    public static func latexToPlain(_ latex: String) -> String {
        var p = PlainConverter(Array(latex))
        let text = p.convert(until: nil)
        return text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static let wrappers: Set<String> = ["text", "mathrm", "mathbf", "mathit", "mathcal", "mathbb", "operatorname",
                                        "boldsymbol", "bm", "hat", "vec", "bar", "tilde", "textbf", "textit", "mathsf", "mathtt", "left", "right", "displaystyle"]

    static let symbols: [String: String] = [
        // Greek
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε", "varepsilon": "ε", "zeta": "ζ", "eta": "η",
        "theta": "θ", "vartheta": "ϑ", "iota": "ι", "kappa": "κ", "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ", "pi": "π",
        "varpi": "ϖ", "rho": "ρ", "varrho": "ϱ", "sigma": "σ", "varsigma": "ς", "tau": "τ", "upsilon": "υ", "phi": "ϕ",
        "varphi": "φ", "chi": "χ", "psi": "ψ", "omega": "ω",
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π", "Sigma": "Σ", "Upsilon": "Υ",
        "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω",
        // relations
        "leq": "≤", "le": "≤", "geq": "≥", "ge": "≥", "neq": "≠", "ne": "≠", "approx": "≈", "equiv": "≡", "sim": "∼",
        "simeq": "≃", "cong": "≅", "propto": "∝", "ll": "≪", "gg": "≫", "prec": "≺", "succ": "≻", "leqslant": "⩽", "geqslant": "⩾",
        "gtrsim": "≳", "lesssim": "≲", "doteq": "≐", "triangleq": "≜", "models": "⊨", "vDash": "⊨", "Vdash": "⊩",
        "parallel": "∥", "nparallel": "∦", "perp": "⊥", "mid": "∣", "nmid": "∤",
        // operators
        "times": "×", "div": "÷", "pm": "±", "mp": "∓", "cdot": "·", "cdots": "⋯", "ldots": "…", "dots": "…", "dotsc": "…",
        "dotsb": "⋯", "vdots": "⋮", "ddots": "⋱", "ast": "∗", "star": "⋆", "circ": "∘", "bullet": "•", "oplus": "⊕",
        "otimes": "⊗", "odot": "⊙", "sum": "∑", "prod": "∏", "coprod": "∐", "int": "∫", "iint": "∬", "iiint": "∭",
        "oint": "∮", "partial": "∂", "nabla": "∇", "infty": "∞", "sqrt": "√", "surd": "√", "wedge": "∧", "vee": "∨",
        "land": "∧", "lor": "∨", "lnot": "¬", "neg": "¬", "setminus": "∖", "bigcup": "⋃", "bigcap": "⋂",
        // arrows
        "to": "→", "rightarrow": "→", "leftarrow": "←", "leftrightarrow": "↔", "Rightarrow": "⇒", "Leftarrow": "⇐",
        "Leftrightarrow": "⇔", "implies": "⇒", "impliedby": "⇐", "iff": "⇔", "mapsto": "↦", "longrightarrow": "⟶",
        "longleftarrow": "⟵", "uparrow": "↑", "downarrow": "↓", "hookrightarrow": "↪", "hookleftarrow": "↩",
        "nearrow": "↗", "searrow": "↘", "swarrow": "↙", "nwarrow": "↖", "rightharpoonup": "⇀", "leftharpoonup": "↼",
        "rightleftharpoons": "⇌", "leadsto": "⇝", "rightsquigarrow": "⇝", "longmapsto": "⟼", "twoheadrightarrow": "↠",
        // sets and logic
        "in": "∈", "notin": "∉", "ni": "∋", "subset": "⊂", "supset": "⊃", "subseteq": "⊆", "supseteq": "⊇",
        "subsetneq": "⊊", "supsetneq": "⊋", "nsubseteq": "⊈", "nsupseteq": "⊉", "cup": "∪", "cap": "∩", "emptyset": "∅",
        "varnothing": "∅", "forall": "∀", "exists": "∃", "nexists": "∄", "therefore": "∴", "because": "∵",
        "mathbb{R}": "ℝ", "mathbb{N}": "ℕ", "mathbb{Z}": "ℤ", "mathbb{Q}": "ℚ", "mathbb{C}": "ℂ",
        "aleph": "ℵ", "hbar": "ℏ", "hslash": "ℏ", "ell": "ℓ", "Re": "ℜ", "Im": "ℑ", "wp": "℘", "angle": "∠",
        "degree": "°", "prime": "′", "checkmark": "✓", "square": "□", "Box": "□", "blacksquare": "■", "bigstar": "★",
        "langle": "⟨", "rangle": "⟩", "lfloor": "⌊", "rfloor": "⌋", "lceil": "⌈", "rceil": "⌉", "lvert": "|", "rvert": "|",
        "lVert": "‖", "rVert": "‖", "quad": " ", "qquad": "  ", ",": " ", ";": " ", ":": " ", "!": "", " ": " ",
        "{": "{", "}": "}", "%": "%", "$": "$", "&": "&", "#": "#", "_": "_", "backslash": "\\",
    ]

    static let superscripts: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶",
                                                        "7": "⁷", "8": "⁸", "9": "⁹", "+": "⁺", "-": "⁻", "n": "ⁿ", "i": "ⁱ"]
    static let subscripts: [Character: Character] = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆",
                                                      "7": "₇", "8": "₈", "9": "₉", "+": "₊", "-": "₋", "i": "ᵢ", "j": "ⱼ",
                                                      "n": "ₙ", "k": "ₖ", "x": "ₓ"]

    struct PlainConverter {
        let c: [Character]
        var i = 0
        init(_ chars: [Character]) { c = chars }

        /// Converts until the closing brace of the current group (when `until` is `}`), or the end.
        mutating func convert(until: Character?) -> String {
            var out = ""
            while i < c.count {
                let ch = c[i]
                if let u = until, ch == u { i += 1; return out }
                switch ch {
                case "{":
                    i += 1
                    out += convert(until: "}")
                case "}":
                    i += 1                                     // stray brace: removed
                case "\\":
                    out += command()
                case "^", "_":
                    i += 1
                    let arg = argument()
                    let table = ch == "^" ? MathMarkdown.superscripts : MathMarkdown.subscripts
                    if !arg.isEmpty, arg.allSatisfy({ table[$0] != nil }) {
                        out += String(arg.map { table[$0]! })
                    } else {
                        out += String(ch) + arg                // kept verbatim
                    }
                default:
                    out.append(ch)
                    i += 1
                }
            }
            return out
        }

        /// One argument: a `{…}` group (converted) or the next single character/command.
        mutating func argument() -> String {
            guard i < c.count else { return "" }
            if c[i] == "{" { i += 1; return convert(until: "}") }
            if c[i] == "\\" { return command() }
            let ch = c[i]; i += 1
            return String(ch)
        }

        mutating func command() -> String {
            i += 1   // backslash
            guard i < c.count else { return "" }
            var name = ""
            if c[i].isLetter {
                while i < c.count && c[i].isLetter { name.append(c[i]); i += 1 }
            } else {
                name = String(c[i]); i += 1
            }
            switch name {
            case "frac", "dfrac", "tfrac":
                let a = argument(); let b = argument()
                return "\(a)/\(b)"
            case "sqrt":
                var deg = ""
                if i < c.count, c[i] == "[" {
                    i += 1
                    while i < c.count, c[i] != "]" { deg.append(c[i]); i += 1 }
                    if i < c.count { i += 1 }
                }
                let a = argument()
                return (deg.isEmpty ? "√" : "\(deg)√") + a
            case _ where MathMarkdown.wrappers.contains(name):
                if name == "left" || name == "right" {         // `\left(` → `(`; `\left.` → nothing
                    guard i < c.count else { return "" }
                    if c[i] == "\\" { return command() }
                    let d = c[i]; i += 1
                    return d == "." ? "" : String(d)
                }
                if name == "displaystyle" { return "" }
                return argument()
            default:
                if let sym = MathMarkdown.symbols[name] { return sym }
                return name                                     // unknown command → its name
            }
        }
    }
}
