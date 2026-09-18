import XCTest
import SwiftUI
@testable import mdv6Core

/// C-05 highlighting through tree-sitter for the eleven languages (K-05, R-08, R-38); render group of §9.0.
final class CodeRendererTests: XCTestCase {

    private func colors(_ attributed: AttributedString) -> Set<String> {
        var set = Set<String>()
        for run in attributed.runs { if let c = run[CodeRenderer.CaptureColorKey.self] { set.insert(c) } }
        return set
    }

    private func color(of word: String, in attributed: AttributedString) -> String? {
        let s = String(attributed.characters)
        guard let r = s.range(of: word) else { return nil }
        let idx = AttributedString.Index(r.lowerBound, within: attributed)!
        return attributed.runs[idx][CodeRenderer.CaptureColorKey.self]
    }

    /// C-05, K-05, R-38: every vendored grammar loads against the tree-sitter 0.25 runtime and its highlight query compiles.
    func testAllGrammarsAndQueriesLoad() {
        for lang in CodeLanguage.allCases {
            XCTAssertNotNil(CodeRenderer.shared.grammar(for: lang), "\(lang) grammar")
            XCTAssertFalse(CodeRenderer.shared.plainForSession.contains(lang), "\(lang) query")
        }
    }

    /// T-37, R-38, C-05: swift and sql blocks colour keywords, strings, comments, numbers, types and function names each
    /// differently from plain text; `postgresql` highlights identically to `sql`.
    func testSwiftAndSQLCaptureClasses() {
        let swift = """
        // MARK: - Model
        struct Counter {
            @Published var count: Int = 42
            func bump(by n: Int) -> String {
                guard let x = Optional(n) else { return "none" }
                return "count is \\(count + x)"
            }
        }
        """
        let s = CodeRenderer.shared.render(code: swift, languageHint: "swift", theme: .highContrast, zoom: 1)
        let plain = MDVTheme.highContrast.codePalette.plain.hex
        XCTAssertNotEqual(color(of: "struct", in: s), plain, "keyword")
        XCTAssertNotEqual(color(of: "\"none\"", in: s), plain, "string")
        XCTAssertNotEqual(color(of: "// MARK", in: s), plain, "comment")
        XCTAssertNotEqual(color(of: "42", in: s), plain, "number")
        XCTAssertNotEqual(color(of: "Int", in: s), plain, "type")
        XCTAssertNotEqual(color(of: "bump", in: s), plain, "function")
        XCTAssertGreaterThanOrEqual(colors(s).count, 5)

        let sql = """
        -- users and their orders
        CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL);
        SELECT u.name, COUNT(o.id) FROM users u JOIN orders o ON o.user_id = u.id WHERE u.name = 'alice' AND o.total > 100;
        """
        let q = CodeRenderer.shared.render(code: sql, languageHint: "sql", theme: .highContrast, zoom: 1)
        XCTAssertNotEqual(color(of: "SELECT", in: q), plain, "keyword")
        XCTAssertNotEqual(color(of: "'alice'", in: q), plain, "string")
        XCTAssertNotEqual(color(of: "-- users", in: q), plain, "comment")
        XCTAssertNotEqual(color(of: "100", in: q), plain, "number")
        XCTAssertNotEqual(color(of: "INTEGER", in: q), plain, "type")
        XCTAssertNotEqual(color(of: "COUNT", in: q), plain, "function")
        let pg = CodeRenderer.shared.render(code: sql, languageHint: "postgresql", theme: .highContrast, zoom: 1)
        XCTAssertEqual(q, pg)
    }

    /// T-06, C-05, K-05: each of the nine original languages yields at least two capture colours; an unknown fence is uniform plain monospace.
    func testNineLanguagesColourAndUnknownIsPlain() {
        let samples: [CodeLanguage: String] = [
            .c: "#include <stdio.h>\nint main(void) { return 42; } // done",
            .go: "package main\nfunc main() { s := \"hi\"; _ = s } // c",
            .rust: "fn main() { let x: u32 = 7; println!(\"{}\", x); } // c",
            .bash: "for f in *.txt; do echo \"$f\"; done # c",
            .javascript: "function f(a) { return `x${a}` + 3 } // c",
            .yaml: "key: value\nlist:\n  - 1\n  - \"two\" # c",
            .toml: "[table]\nname = \"x\"\nn = 3 # c",
            .python: "def f(x):\n    return \"s\" + str(3)  # c",
            .ruby: "def f(x)\n  \"s\" + 3.to_s # c\nend",
        ]
        for (lang, code) in samples {
            let a = CodeRenderer.shared.render(code: code, languageHint: lang.rawValue, theme: .charcoal, zoom: 1)
            XCTAssertGreaterThanOrEqual(colors(a).count, 2, "\(lang)")
        }
        let unknown = CodeRenderer.shared.render(code: "+++++[>+++++<-]>.", languageHint: "brainfuck", theme: .charcoal, zoom: 1)
        XCTAssertEqual(colors(unknown), [MDVTheme.charcoal.codePalette.plain.hex])
        XCTAssertEqual(String(unknown.characters), "+++++[>+++++<-]>.")
        let none = CodeRenderer.shared.render(code: "text", languageHint: nil, theme: .charcoal, zoom: 1)
        XCTAssertEqual(colors(none), [MDVTheme.charcoal.codePalette.plain.hex])
    }

    /// C-05, R-30, D-26: fence text is the system monospace face at 0.85 × base × zoom; comments are italic.
    func testFontSizeFollowsZoomAndCommentsItalic() {
        let a = CodeRenderer.shared.render(code: "x = 1 # note", languageHint: "python", theme: .sevilla, zoom: 1.5)
        for run in a.runs {
            let font = run[CodeRenderer.FontKey.self]!
            XCTAssertEqual(font.pointSize, 0.85 * 17 * 1.5, accuracy: 0.01)
            XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.monoSpace))
        }
        let s = String(a.characters)
        let idx = AttributedString.Index(s.range(of: "# note")!.lowerBound, within: a)!
        XCTAssertTrue(a.runs[idx][CodeRenderer.FontKey.self]!.fontDescriptor.symbolicTraits.contains(.italic))
        let x = AttributedString.Index(s.startIndex, within: a)!
        XCTAssertFalse(a.runs[x][CodeRenderer.FontKey.self]!.fontDescriptor.symbolicTraits.contains(.italic))
    }

    /// C-05: the result cache is keyed by (language, theme id, zoom, hash(code)), holds at most 256 entries and is flushed whole when full.
    func testCacheKeyAndFlush() {
        let r = CodeRenderer()
        _ = r.render(code: "a = 1", languageHint: "python", theme: .sevilla, zoom: 1)
        _ = r.render(code: "a = 1", languageHint: "python", theme: .sevilla, zoom: 1)
        XCTAssertEqual(r.cacheCount, 1)
        _ = r.render(code: "a = 1", languageHint: "python", theme: .charcoal, zoom: 1)
        _ = r.render(code: "a = 1", languageHint: "python", theme: .sevilla, zoom: 1.2)
        _ = r.render(code: "a = 1", languageHint: "ruby", theme: .sevilla, zoom: 1)
        XCTAssertEqual(r.cacheCount, 4)
        for i in 0..<300 { _ = r.render(code: "a = \(i)", languageHint: "python", theme: .sevilla, zoom: 1) }
        XCTAssertLessThanOrEqual(r.cacheCount, CodeRenderer.cacheLimit)
        XCTAssertEqual(CodeRenderer.cacheLimit, 256)
    }
}
