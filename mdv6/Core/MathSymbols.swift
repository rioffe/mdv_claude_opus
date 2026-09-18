// MathSymbols — C-07.2: (a) the extra symbols registered with SwiftMath (Latin Modern Math has the glyphs) and
// (b) the command rewrites applied, in order, before typesetting (R-14). Registration itself lives in MathImageCache.
import Foundation

public enum MathSymbols {
    public enum SymbolKind: Sendable { case relation, ordinary, largeOperator, binary }

    public struct Symbol: Sendable {
        public let name: String
        public let codepoint: String
        public let kind: SymbolKind
    }

    /// C-07.2 (a): relations, arrows (typeset as relations), ordinary symbols, big operators and binary operators.
    public static let registeredSymbols: [Symbol] = {
        func rel(_ n: String, _ c: String) -> Symbol { Symbol(name: n, codepoint: c, kind: .relation) }
        func ord(_ n: String, _ c: String) -> Symbol { Symbol(name: n, codepoint: c, kind: .ordinary) }
        func big(_ n: String, _ c: String) -> Symbol { Symbol(name: n, codepoint: c, kind: .largeOperator) }
        func bin(_ n: String, _ c: String) -> Symbol { Symbol(name: n, codepoint: c, kind: .binary) }
        return [
            // relations
            rel("gtrsim", "\u{2273}"), rel("lesssim", "\u{2272}"), rel("gtrapprox", "\u{2A86}"), rel("lessapprox", "\u{2A85}"),
            rel("leqslant", "\u{2A7D}"), rel("geqslant", "\u{2A7E}"), rel("lll", "\u{22D8}"), rel("ggg", "\u{22D9}"),
            rel("nless", "\u{226E}"), rel("ngtr", "\u{226F}"), rel("nleq", "\u{2270}"), rel("ngeq", "\u{2271}"),
            rel("doteq", "\u{2250}"), rel("triangleq", "\u{225C}"), rel("therefore", "\u{2234}"), rel("because", "\u{2235}"),
            rel("implies", "\u{27F9}"), rel("impliedby", "\u{27F8}"), rel("models", "\u{22A8}"), rel("vDash", "\u{22A8}"),
            rel("Vdash", "\u{22A9}"), rel("nparallel", "\u{2226}"), rel("nmid", "\u{2224}"), rel("subsetneq", "\u{228A}"),
            rel("supsetneq", "\u{228B}"), rel("nsubseteq", "\u{2288}"), rel("nsupseteq", "\u{2289}"), rel("sqsubseteq", "\u{2291}"),
            rel("sqsupseteq", "\u{2292}"), rel("precsim", "\u{227E}"), rel("succsim", "\u{227F}"),
            // arrows
            rel("hookrightarrow", "\u{21AA}"), rel("hookleftarrow", "\u{21A9}"), rel("rightharpoonup", "\u{21C0}"),
            rel("leftharpoonup", "\u{21BC}"), rel("rightleftharpoons", "\u{21CC}"), rel("leftrightharpoons", "\u{21CB}"),
            rel("nearrow", "\u{2197}"), rel("searrow", "\u{2198}"), rel("swarrow", "\u{2199}"), rel("nwarrow", "\u{2196}"),
            rel("longmapsto", "\u{27FC}"), rel("twoheadrightarrow", "\u{21A0}"), rel("rightsquigarrow", "\u{21DD}"),
            rel("leadsto", "\u{21DD}"), rel("rightrightarrows", "\u{21C9}"), rel("leftleftarrows", "\u{21C7}"),
            // ordinary
            ord("dots", "\u{2026}"), ord("dotsc", "\u{2026}"), ord("dotsb", "\u{22EF}"), ord("varnothing", "\u{2205}"),
            ord("hslash", "\u{210F}"), ord("mho", "\u{2127}"), ord("Box", "\u{25A1}"), ord("square", "\u{25A1}"),
            ord("blacksquare", "\u{25A0}"), ord("bigstar", "\u{2605}"), ord("checkmark", "\u{2713}"), ord("ddagger", "\u{2021}"),
            ord("S", "\u{00A7}"), ord("P", "\u{00B6}"), ord("pounds", "\u{00A3}"), ord("copyright", "\u{00A9}"),
            ord("degree", "\u{00B0}"), ord("beth", "\u{2136}"), ord("gimel", "\u{2137}"), ord("wp", "\u{2118}"),
            ord("nexists", "\u{2204}"), ord("complement", "\u{2201}"), ord("#", "\u{0023}"), ord("_", "\u{005F}"),
            // big operators
            big("iint", "\u{222C}"), big("iiint", "\u{222D}"), big("oiint", "\u{222F}"), big("bigsqcup", "\u{2A06}"),
            big("bigodot", "\u{2A00}"), big("bigotimes", "\u{2A02}"), big("biguplus", "\u{2A04}"),
            // binary
            bin("intercal", "\u{22BA}"), bin("leftthreetimes", "\u{22CB}"), bin("rightthreetimes", "\u{22CC}"),
            bin("divideontimes", "\u{22C7}"),
        ]
    }()

    /// C-07.2 (b): the regex rewrites, in the order the spec lists them.
    static let rewrites: [(NSRegularExpression, String)] = {
        func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
        func lit(_ s: String) -> String { NSRegularExpression.escapedTemplate(for: s) }   // literal replacement text
        return [
            (rx(#"\\operatorname\*?\{"#), lit(#"\mathrm{"#)),
            (rx(#"\\[dt]frac\b"#), lit(#"\frac"#)),
            (rx(#"\\boldsymbol\b"#), lit(#"\bm"#)),
            (rx(#"\\bmod\b"#), lit(#"\;\mathrm{mod}\;"#)),
            (rx(#"\\pmod\{([^}]*)\}"#), lit(#"\;(\mathrm{mod}\;"#) + "$1" + lit(")")),
            (rx(#"\\not="#), lit(#"\neq"#)),
            (rx(#"\\(?:big|Big|bigg|Bigg)[lrm]?\s*(?=[\\(\[\]){}|.<>/])"#), ""),
            (rx(#"\\coloneqq\b"#), ":="),
            (rx(#"\\(begin|end)\{(align|equation|gather|multline)\*\}"#), lit("\\") + "$1{$2}"),
            (rx(#"\\(begin|end)\{align\}"#), lit("\\") + "$1{aligned}"),
            (rx(#"\\(begin|end)\{multline\}"#), lit("\\") + "$1{gather}"),
            (rx(#"\\(begin|end)\{equation\}"#), ""),
        ]
    }()

    /// Applies the C-07.2 (b) rewrites in order.
    public static func preprocess(_ latex: String) -> String {
        var s = latex
        for (regex, template) in rewrites {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
        }
        return s
    }
}
