import XCTest
@testable import mdv6Core

/// C-10 smart typography and its I-012 exclusions (unit group of §9.0; T-10).
final class TypographyTests: XCTestCase {

    /// C-10: quotes become directional (chosen from the preceding character), dashes and ellipses are replaced. R-17, T-10.
    func testProseIsSmartened() {
        XCTAssertEqual(smartenMarkdown("\"Hello,\" she said. It's 'fine'."), "“Hello,” she said. It’s ‘fine’.")
        XCTAssertEqual(smartenMarkdown("wait... what"), "wait… what")
        XCTAssertEqual(smartenMarkdown("a---b"), "a—b")
        XCTAssertEqual(smartenMarkdown("pages 10--20"), "pages 10–20")
        XCTAssertEqual(smartenMarkdown("one -- two"), "one — two")
        XCTAssertEqual(smartenMarkdown("(\"quoted\")"), "(“quoted”)")
        XCTAssertEqual(smartenMarkdown("'90s rock"), "‘90s rock")   // direction comes from the preceding character only (C-10)
    }

    /// C-10, I-012: other `--` runs are unchanged so CLI flags survive; code spans (a run of n backticks closes only on
    /// exactly n), link/image URL parts and `<…>` spans are left verbatim. T-10.
    func testExclusionsInsideProse() {
        XCTAssertEqual(smartenMarkdown("use --flag and -x"), "use --flag and -x")
        XCTAssertEqual(smartenMarkdown("run `git log --oneline` now"), "run `git log --oneline` now")
        XCTAssertEqual(smartenMarkdown("a ``code with ` inside...`` b..."), "a ``code with ` inside...`` b…")
        XCTAssertEqual(smartenMarkdown("[it's](https://x.y/a--b?q='1') 'ok'"), "[it’s](https://x.y/a--b?q='1') ‘ok’")
        XCTAssertEqual(smartenMarkdown("![alt \"x\"](img--1.png)"), "![alt “x”](img--1.png)")
        XCTAssertEqual(smartenMarkdown("see <https://a.b/c--d> and \"x\""), "see <https://a.b/c--d> and “x”")
        XCTAssertEqual(smartenMarkdown("<span class=\"x\">t</span>"), "<span class=\"x\">t</span>")
    }

    /// C-10, I-012: fences, GFM tables and thematic-break lines are returned unchanged. T-10.
    func testBlocksReturnedUnchanged() {
        let fence = "```\n\"quoted\" -- and...\n```"
        XCTAssertEqual(smartenMarkdown(fence), fence)
        let tilde = "~~~\nit's\n~~~"
        XCTAssertEqual(smartenMarkdown(tilde), tilde)
        let table = "| a | b |\n|---|---|\n| \"x\" | it's... |"
        XCTAssertEqual(smartenMarkdown(table), table)
        XCTAssertEqual(smartenMarkdown("---"), "---")
        XCTAssertEqual(smartenMarkdown("* * *"), "* * *")
        XCTAssertEqual(smartenMarkdown("___"), "___")
    }

    /// §3.2, I-012: math is rewritten before smartening, so `--`, `...` and quotes inside `$…$` are never altered. R-17.
    func testMathRewrittenBeforeSmartening() {
        let block = "Let $a--b$ and \"quote\""
        let rewritten = MathMarkdown.rewrite(block, fontSize: 16, headingSizeEms: [], color: .black)
        let out = smartenMarkdown(rewritten)
        XCTAssertTrue(out.contains("mdv6-math://inline/"))
        XCTAssertTrue(out.contains("“quote”"))
        XCTAssertEqual(MathMarkdown.decode(url: URL(string: String(out.dropFirst("Let ![](".count).prefix { $0 != ")" }))!)?.latex, "a--b")
    }
}
