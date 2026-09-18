import XCTest
@testable import mdv6Core

/// C-07.1 delimiters and rewriting, C-07.2 command rewrites, C-07.3 plain text (unit group of §9.0).
final class MathContractTests: XCTestCase {

    // MARK: C-07.1 delimiters (E-07)

    /// E-07, C-07.1: `$` in prose that is not math stays literal — opener followed by space, closer followed by a digit,
    /// bare `$` inside, escape, empty `$$` pair. T-07.
    func testNonMathDollarsAreLiteral() {
        XCTAssertEqual(MathMarkdown.spans(in: "costs $5 and $10 today").count, 0)
        XCTAssertEqual(MathMarkdown.spans(in: "range $5-$10 today").count, 0)
        XCTAssertEqual(MathMarkdown.spans(in: "$100/month").count, 0)
        XCTAssertEqual(MathMarkdown.spans(in: "escaped \\$x\\$ here").count, 0)
        XCTAssertEqual(MathMarkdown.spans(in: "empty $$ pair").count, 0)
        XCTAssertEqual(MathMarkdown.spans(in: "a $x b").count, 0)                 // never closed
        XCTAssertEqual(MathMarkdown.spans(in: "a $ x$ b").count, 0)               // opener followed by whitespace
        XCTAssertEqual(MathMarkdown.spans(in: "a $x $ b").count, 0)               // closer preceded by whitespace
        XCTAssertEqual(MathMarkdown.spans(in: "a $x$2 b").count, 0)               // closer followed by a digit
        XCTAssertEqual(MathMarkdown.spans(in: "a $x `y$ z` b").count, 0)          // crosses a backtick
        XCTAssertEqual(MathMarkdown.spans(in: "code `$HOME$` here").count, 0)     // inside inline code
        XCTAssertEqual(MathMarkdown.spans(in: "```\n$x$\n```").count, 0)          // fenced block
        XCTAssertEqual(MathMarkdown.rewrite("costs $5 and $10", fontSize: 16, headingSizeEms: [], color: .black), "costs $5 and $10")
    }

    /// C-07.1: inline and display spans, mode by delimiter alone (K-08); own-paragraph detection for one-line and
    /// fence-form `$$`, mid-line `$$` stays inline. T-07, T-46.
    func testSpanDetection() {
        let inline = MathMarkdown.spans(in: "Let $x^2$ and $\\frac{a}{b}$.")
        XCTAssertEqual(inline.map(\.latex), ["x^2", "\\frac{a}{b}"])
        XCTAssertEqual(inline.map(\.display), [false, false])
        let one = MathMarkdown.spans(in: "$$r = \\frac{a}{b}$$")
        XCTAssertEqual(one.count, 1); XCTAssertTrue(one[0].display); XCTAssertTrue(one[0].ownParagraph)
        let fence = MathMarkdown.spans(in: "$$\nr = \\frac{a}{b}\n$$")
        XCTAssertEqual(fence.count, 1); XCTAssertTrue(fence[0].display); XCTAssertTrue(fence[0].ownParagraph)
        XCTAssertEqual(fence[0].latex, "\nr = \\frac{a}{b}\n")
        let mid = MathMarkdown.spans(in: "Text $$\\sum_{i=1}^n$$ text")
        XCTAssertEqual(mid.count, 1); XCTAssertTrue(mid[0].display); XCTAssertFalse(mid[0].ownParagraph)
        let indented = MathMarkdown.spans(in: "  $$x$$  ")
        XCTAssertEqual(indented.count, 1); XCTAssertTrue(indented[0].ownParagraph)
        let listItem = MathMarkdown.spans(in: "- $$E = mc^2$$")
        XCTAssertEqual(listItem.count, 1); XCTAssertFalse(listItem[0].ownParagraph)
        XCTAssertEqual(MathMarkdown.spans(in: "a $x$ b $y$").map(\.latex), ["x", "y"])
        XCTAssertEqual(MathMarkdown.spans(in: "price is $\\$5$ ok").map(\.latex), ["\\$5"])
    }

    /// C-07.1 URL form: `mdv6-math://inline|display/<base64url>?s=<1 decimal>&c=<RRGGBBAA>`; base64url without padding;
    /// decoders re-pad. R-12.
    func testRewriteURLForm() {
        let out = MathMarkdown.rewrite("Let $x^2$.", fontSize: 16, headingSizeEms: [1.75, 1.4, 1.15], color: RGBA(r: 0x42, g: 0x37, b: 0x2C))
        XCTAssertEqual(out, "Let ![](mdv6-math://inline/eF4y?s=16.0&c=42372CFF).")
        let spec = MathMarkdown.decode(url: URL(string: "mdv6-math://inline/eF4y?s=16.0&c=42372CFF")!)!
        XCTAssertEqual(spec, MathSpec(latex: "x^2", fontSize: 16, color: RGBA(r: 0x42, g: 0x37, b: 0x2C), display: false))
        // padding: "ab" → "YWI" (one = stripped); decode re-pads
        XCTAssertEqual(MathMarkdown.base64url("ab"), "YWI")
        XCTAssertEqual(MathMarkdown.base64urlDecode("YWI"), "ab")
        XCTAssertEqual(MathMarkdown.base64urlDecode("YQ"), "a")
        XCTAssertFalse(MathMarkdown.base64url("\u{3FF}\u{3FF}\u{3FF}?>").contains(where: { "+/=".contains($0) }))
        XCTAssertNil(MathMarkdown.decode(url: URL(string: "https://x/y")!))
        let display = MathMarkdown.rewrite("Text $$\\sum$$ text", fontSize: 16, headingSizeEms: [], color: .black)
        XCTAssertTrue(display.hasPrefix("Text ![](mdv6-math://display/"))
        XCTAssertTrue(display.hasSuffix(") text"))
    }

    /// C-07.1: an own-paragraph `$$` (one line or the fence form) is emitted as its own paragraph with blank lines
    /// and its indentation preserved. C-18.10, T-46.
    func testOwnParagraphEmission() {
        let one = MathMarkdown.rewrite("$$r=1$$", fontSize: 16, headingSizeEms: [], color: .black)
        let fence = MathMarkdown.rewrite("$$\nr=1\n$$", fontSize: 16, headingSizeEms: [], color: .black)
        XCTAssertTrue(one.hasPrefix("![](mdv6-math://display/"))
        XCTAssertEqual(MathMarkdown.decode(url: URL(string: String(one.dropFirst(4).dropLast()))!)?.latex, "r=1")
        XCTAssertEqual(MathMarkdown.decode(url: URL(string: String(fence.dropFirst(4).dropLast()))!)?.latex, "\nr=1\n")
        let mixed = MathMarkdown.rewrite("before\n$$x$$\nafter", fontSize: 16, headingSizeEms: [], color: .black)
        XCTAssertTrue(mixed.hasPrefix("before\n\n![](mdv6-math://display/"))
        XCTAssertTrue(mixed.hasSuffix(")\n\nafter"))
        let indented = MathMarkdown.rewrite("  $$x$$", fontSize: 16, headingSizeEms: [], color: .black)
        XCTAssertTrue(indented.hasPrefix("  ![](mdv6-math://display/"))
    }

    /// R-13: math inside an ATX heading is sized by that heading's em factor; elsewhere by the body size.
    func testHeadingMathSizing() {
        let ems: [CGFloat] = [1.75, 1.4, 1.15, 1.0, 0.875, 0.85]
        let h2 = MathMarkdown.rewrite("## $\\pi$ at h2", fontSize: 16, headingSizeEms: ems, color: .black)
        XCTAssertTrue(h2.contains("?s=22.4&"))
        let body = MathMarkdown.rewrite("body $\\pi$", fontSize: 16, headingSizeEms: ems, color: .black)
        XCTAssertTrue(body.contains("?s=16.0&"))
        let zoomed = MathMarkdown.rewrite("# $\\pi$", fontSize: 24, headingSizeEms: ems, color: .black)
        XCTAssertTrue(zoomed.contains("?s=42.0&"))
        XCTAssertEqual(MathMarkdown.headingLevel(of: "#### x"), 4)
        XCTAssertNil(MathMarkdown.headingLevel(of: "#hashtag"))
    }

    // MARK: C-07.3 plain text

    /// C-07.3: fractions, roots, wrappers, super/subscripts, Greek, relations, arrows, unknown commands, braces, whitespace. T-08, I-010.
    func testPlainText() {
        XCTAssertEqual(MathMarkdown.plainText("Heading with $\\Sigma$ in it"), "Heading with Σ in it")
        XCTAssertEqual(MathMarkdown.plainText("$\\pi$ at h2 size, $\\frac{a}{b}$ too"), "π at h2 size, a/b too")
        XCTAssertEqual(MathMarkdown.latexToPlain("\\sqrt{x}"), "√x")
        XCTAssertEqual(MathMarkdown.latexToPlain("\\sqrt[3]{x}"), "3√x")
        XCTAssertEqual(MathMarkdown.latexToPlain("\\text{rate} \\mathbf{v} \\hat{x}"), "rate v x")
        XCTAssertEqual(MathMarkdown.latexToPlain("x^2 + y_{ij} - z^{n+1}"), "x² + yᵢⱼ - zⁿ⁺¹")
        XCTAssertEqual(MathMarkdown.latexToPlain("x^{ab}"), "x^ab")          // no superscript for a, b: kept verbatim
        XCTAssertEqual(MathMarkdown.latexToPlain("a_k x_x"), "aₖ xₓ")
        XCTAssertEqual(MathMarkdown.latexToPlain("\\alpha \\leq \\beta \\to \\infty"), "α ≤ β → ∞")
        XCTAssertEqual(MathMarkdown.latexToPlain("A \\subseteq B \\cup \\emptyset"), "A ⊆ B ∪ ∅")
        XCTAssertEqual(MathMarkdown.latexToPlain("\\foo{x}"), "foox")
        XCTAssertEqual(MathMarkdown.latexToPlain("  a   \n b  "), "a b")
        XCTAssertEqual(MathMarkdown.latexToPlain("\\left( \\frac{1}{2} \\right)"), "( 1/2 )")
        XCTAssertEqual(MathMarkdown.latexToPlain("\\operatorname{sin} x"), "sin x")
        XCTAssertEqual(MathMarkdown.plainText("no math here"), "no math here")
    }

    // MARK: C-07.2 rewrites

    /// C-07.2 (b): the command rewrites, applied in order. T-07, R-14.
    func testPreprocessRewrites() {
        XCTAssertEqual(MathSymbols.preprocess("\\operatorname{sin}"), "\\mathrm{sin}")
        XCTAssertEqual(MathSymbols.preprocess("\\operatorname*{lim}"), "\\mathrm{lim}")
        XCTAssertEqual(MathSymbols.preprocess("\\dfrac{a}{b} \\tfrac{c}{d}"), "\\frac{a}{b} \\frac{c}{d}")
        XCTAssertEqual(MathSymbols.preprocess("\\boldsymbol{v}"), "\\bm{v}")
        XCTAssertEqual(MathSymbols.preprocess("a \\bmod b"), "a \\;\\mathrm{mod}\\; b")
        XCTAssertEqual(MathSymbols.preprocess("a \\pmod{n}"), "a \\;(\\mathrm{mod}\\;n)")
        XCTAssertEqual(MathSymbols.preprocess("a \\not= b"), "a \\neq b")
        XCTAssertEqual(MathSymbols.preprocess("\\big( x \\Big) \\bigg[ \\Bigg] \\bigl\\{ \\bigr\\} \\Bigm|"), "( x ) [ ] \\{ \\} |")
        XCTAssertEqual(MathSymbols.preprocess("a \\coloneqq b"), "a := b")
        XCTAssertEqual(MathSymbols.preprocess("\\begin{align*}x\\end{align*}"), "\\begin{aligned}x\\end{aligned}")
        XCTAssertEqual(MathSymbols.preprocess("\\begin{equation*}x\\end{equation*}"), "x")
        XCTAssertEqual(MathSymbols.preprocess("\\begin{gather*}x\\end{gather*}"), "\\begin{gather}x\\end{gather}")
        XCTAssertEqual(MathSymbols.preprocess("\\begin{multline*}x\\end{multline*}"), "\\begin{gather}x\\end{gather}")
        XCTAssertEqual(MathSymbols.preprocess("\\begin{align}x\\end{align}"), "\\begin{aligned}x\\end{aligned}")
        XCTAssertEqual(MathSymbols.preprocess("\\begin{equation}x\\end{equation}"), "x")
        XCTAssertEqual(MathSymbols.preprocess("plain"), "plain")
    }

    /// C-07.2 (a): the registered-symbol table covers every name the spec lists.
    func testRegisteredSymbolTable() {
        let names = Set(MathSymbols.registeredSymbols.map(\.name))
        for n in ["gtrsim", "lesssim", "leqslant", "geqslant", "lll", "ggg", "implies", "impliedby", "models", "vDash", "Vdash",
                  "hookrightarrow", "rightleftharpoons", "longmapsto", "twoheadrightarrow", "leadsto",
                  "dots", "varnothing", "hslash", "mho", "Box", "square", "blacksquare", "bigstar", "checkmark", "ddagger",
                  "S", "P", "pounds", "copyright", "degree", "beth", "gimel", "wp", "nexists", "complement", "#", "_",
                  "iint", "iiint", "oiint", "bigsqcup", "bigodot", "bigotimes", "biguplus",
                  "intercal", "leftthreetimes", "rightthreetimes", "divideontimes"] {
            XCTAssertTrue(names.contains(n), "missing registered symbol \\\(n)")
        }
        XCTAssertEqual(MathSymbols.registeredSymbols.count, 82)
    }
}
