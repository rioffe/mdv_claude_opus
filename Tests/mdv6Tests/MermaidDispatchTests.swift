import XCTest
@testable import mdv6Core

/// C-06.4 dispatch and C-06.1 rule 0 (R-46, R-10). T-54 (unit half).
final class MermaidDispatchTests: XCTestCase {

    /// C-06.4: the six native families by exact keyword or keyword + whitespace; prefixes for state and xychart. T-54.
    func testDispatch() {
        for native in ["graph", "graph TD", "graph\tLR", "flowchart LR", "sequenceDiagram", "classDiagram", "erDiagram",
                       "stateDiagram-v2", "stateDiagram", "xychart-beta"] {
            XCTAssertTrue(MermaidDispatch.isNative(native + "\n  A --> B"), native)
        }
        for web in ["graphfoo", "flowchart-elk TD", "gantt", "pie", "timeline", "journey", "quadrantChart",
                    "requirementDiagram", "mindmap", "gitGraph", ""] {
            XCTAssertFalse(MermaidDispatch.isNative(web + "\n  x"), web)
        }
    }

    /// C-06.4: blank lines, `%%` comments, single- and multi-line `%%{…}%%` directives and a `---` block are skipped.
    func testPreambleSkipped() {
        XCTAssertEqual(MermaidDispatch.firstDirectiveLine("\n%% note\n%%{init: {\"theme\": \"dark\"}}%%\n  Flowchart LR\nA-->B"), "flowchart lr")
        XCTAssertEqual(MermaidDispatch.firstDirectiveLine("%%{\n  init: {\n    \"theme\": \"dark\"\n  }\n}%%\ngantt\n"), "gantt")
        XCTAssertEqual(MermaidDispatch.firstDirectiveLine("---\ntitle: x\n---\nsequenceDiagram\n"), "sequencediagram")
        XCTAssertEqual(MermaidDispatch.firstDirectiveLine("%% only a comment"), "")
    }

    /// C-06.1 rule 0 (F-152): exactly the lines C-06.4 skipped go, except a front-matter block (rule 1's).
    func testRuleZeroStripsThePreamble() {
        let src = "%%{\n  init: {\"theme\": \"forest\"}\n}%%\n%% c\n\nflowchart LR\n  A --> B"
        XCTAssertEqual(MermaidDispatch.stripPreamble(src), "flowchart LR\n  A --> B")
        XCTAssertEqual(MermaidDispatch.stripPreamble("---\ntitle: x\n---\n%% c\ngraph TD\nA"), "---\ntitle: x\n---\ngraph TD\nA")
        XCTAssertEqual(MDVMermaidPipeline.sanitize(src).hasPrefix("flowchart LR"), true)
    }
}
