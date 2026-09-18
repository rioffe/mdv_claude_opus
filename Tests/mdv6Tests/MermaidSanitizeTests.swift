import XCTest
@testable import mdv6Core

/// C-06.1 source sanitisation and the C-06.2 state-description merge (unit group of §9.0; T-15, T-16, T-20 sanitiser output).
final class MermaidSanitizeTests: XCTestCase {

    /// C-06.1 rule 1: a leading YAML front-matter block is dropped. T-15.
    func testFrontMatterDropped() {
        let src = "---\ntitle: X\nconfig:\n  theme: dark\n---\nflowchart TD\n  A --> B"
        XCTAssertEqual(MDVMermaidPipeline.dropFrontMatter(src), "flowchart TD\n  A --> B")
        XCTAssertEqual(MDVMermaidPipeline.dropFrontMatter("flowchart TD\n  A --> B"), "flowchart TD\n  A --> B")
        XCTAssertEqual(MDVMermaidPipeline.dropFrontMatter("  ---\nx\n---\ngraph LR"), "graph LR")
    }

    /// C-06.1 rule 2, E-15: xychart `line "name" [...]`/`bar "name" [...]` become the unnamed form. T-16.
    func testXYChartSeriesNames() {
        let src = "xychart-beta\n  x-axis [a, b]\n  line \"revenue\" [1, 2]\n  bar \"cost\" [3, 4]\n  line [5, 6]"
        XCTAssertEqual(MDVMermaidPipeline.renameXYSeries(src), "xychart-beta\n  x-axis [a, b]\n  line [1, 2]\n  bar [3, 4]\n  line [5, 6]")
    }

    /// C-06.1 rule 3, E-14: on style/classDef/linkStyle lines, `#rgb`/`#rgba` expand to 6/8 digits and the listed CSS
    /// names after `fill:`/`stroke:`/`color:` map to hex; `transparent`/`none` → `#00000000`; other names pass through. T-15.
    func testColorNormalisation() {
        XCTAssertEqual(MDVMermaidPipeline.normalizeColors("style A fill:#eee,stroke:#f0f8"), "style A fill:#eeeeee,stroke:#ff00ff88")
        XCTAssertEqual(MDVMermaidPipeline.normalizeColors("classDef x fill:white,stroke:Black,color:LightGray"), "classDef x fill:#ffffff,stroke:#000000,color:#d3d3d3")
        XCTAssertEqual(MDVMermaidPipeline.normalizeColors("linkStyle 0 stroke:none,fill:transparent"), "linkStyle 0 stroke:#00000000,fill:#00000000")
        XCTAssertEqual(MDVMermaidPipeline.normalizeColors("style B fill:papayawhip"), "style B fill:papayawhip")
        XCTAssertEqual(MDVMermaidPipeline.normalizeColors("style C fill: red , stroke-width:2px"), "style C fill: #ff0000 , stroke-width:2px")
        XCTAssertEqual(MDVMermaidPipeline.normalizeColors("A[white] --> B"), "A[white] --> B")   // not a style line
        XCTAssertEqual(MDVMermaidPipeline.normalizeColors("style D fill:#ABCDEF"), "style D fill:#ABCDEF")
        for name in ["white", "black", "red", "green", "blue", "yellow", "orange", "purple", "gray", "grey", "lightgray", "lightgrey",
                     "darkgray", "silver", "pink", "lightblue", "lightgreen", "lightyellow", "gold", "teal", "navy", "maroon", "olive",
                     "cyan", "magenta", "brown", "beige", "ivory", "lavender", "coral", "salmon", "tomato", "crimson", "indigo",
                     "violet", "khaki", "tan", "wheat", "mintcream", "honeydew", "aliceblue", "whitesmoke", "gainsboro", "snow"] {
            let out = MDVMermaidPipeline.normalizeColors("style X fill:\(name)")
            XCTAssertTrue(out.hasPrefix("style X fill:#") && out.count == "style X fill:#".count + 6, "\(name) → \(out)")
        }
    }

    /// C-06.1 rule 4: every `ID: text` description line of a state is folded into one `state "a<br/>b" as ID` alias
    /// inserted after the header. T-20.
    func testStateDescriptionsMerged() {
        let src = "stateDiagram-v2\n  S1: first line\n  S1: second line\n  S2: only\n  S1 --> S2\n  classDef c fill:#eee"
        let out = MDVMermaidPipeline.mergeStateDescriptions(src.split(separator: "\n").map(String.init))
        XCTAssertEqual(out, ["stateDiagram-v2", "  state \"first line<br/>second line\" as S1", "  state \"only\" as S2", "  S1 --> S2", "  classDef c fill:#eee"])
        XCTAssertEqual(MDVMermaidPipeline.mergeStateDescriptions(["flowchart TD", "  A: not a state"]), ["flowchart TD", "  A: not a state"])
        XCTAssertEqual(MDVMermaidPipeline.mergeStateDescriptions(["stateDiagram-v2", "  [*] --> A", "  A --> [*]"]), ["stateDiagram-v2", "  [*] --> A", "  A --> [*]"])
    }

    /// C-06.1 rule 5, D-07: parallelograms `id[/text/]` and `id[\text\]` become `id[text]`. T-15.
    func testParallelogramsExpanded() {
        XCTAssertEqual(MDVMermaidPipeline.expandParallelograms("A[/Input/] --> B[\\Output\\]"), "A[Input] --> B[Output]")
        XCTAssertEqual(MDVMermaidPipeline.expandParallelograms("A[/x\\] --> B"), "A[x] --> B")
        XCTAssertEqual(MDVMermaidPipeline.expandParallelograms("A[plain] --> B"), "A[plain] --> B")
    }

    /// C-06.1 rule 6: inline formatting tags are stripped (open and close), keeping content; `<br/>` is kept. T-15.
    func testFormattingTagsStripped() {
        XCTAssertEqual(MDVMermaidPipeline.stripFormattingTags("A[<b>bold</b> and <i>it</i><br/>next <span class='x'>s</span>]"), "A[bold and it<br/>next s]")
        XCTAssertEqual(MDVMermaidPipeline.stripFormattingTags("<STRONG>x</STRONG> <code>c</code> <font color=red>f</font> <mark>m</mark> <u>u</u> <s>s</s> <sup>2</sup> <sub>i</sub> <tt>t</tt> <small>sm</small> <em>e</em>"), "x c f m u s 2 i t sm e")
        XCTAssertEqual(MDVMermaidPipeline.stripFormattingTags("keep <br> and <br/> and <BR/>"), "keep <br> and <br/> and <BR/>")
        XCTAssertEqual(MDVMermaidPipeline.stripFormattingTags("a < b > c"), "a < b > c")
    }

    /// C-06.1: the rules apply in order 1…6 to a whole source. T-15.
    func testSanitizeAppliesAllRulesInOrder() {
        let src = "---\ntitle: T\n---\nflowchart LR\n  A[/<b>In</b>/] --> B[Out<br/>line]\n  style A fill:#eee,stroke:white\n  style B fill:none"
        let out = MDVMermaidPipeline.sanitize(src)
        XCTAssertEqual(out, "flowchart LR\n  A[In] --> B[Out<br/>line]\n  style A fill:#eeeeee,stroke:#ffffff\n  style B fill:#00000000")
        XCTAssertEqual(MDVMermaidPipeline.sanitize(""), "")
    }
}
