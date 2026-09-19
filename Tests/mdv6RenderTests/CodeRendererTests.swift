import XCTest
import SwiftUI
@testable import mdv6Core

/// C-05 highlighting through tree-sitter for the sixteen languages (K-05, R-08, R-38, R-43); render group of §9.0.
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

    /// T-51, R-43, K-05, C-05: the five added grammars — C++, JSON, Lua, OpenCL, Perl — colour the capture
    /// classes R-43 names, and the fence aliases resolve to the same grammar (`metal`, `c++`, `cc` → C++;
    /// `cl` → OpenCL; `pl` → Perl).
    func testAddedLanguagesCaptureClasses() {
        let plain = MDVTheme.highContrast.codePalette.plain.hex
        func render(_ code: String, _ hint: String) -> AttributedString {
            CodeRenderer.shared.render(code: code, languageHint: hint, theme: .highContrast, zoom: 1)
        }

        let cpp = """
        // a counter
        #include <cstdint>
        struct Counter {
            std::uint32_t n = 42;
            const char *name = "counter";
            int bump(int by) { return n + by; }
        };
        """
        let c = render(cpp, "cpp")
        XCTAssertNotEqual(color(of: "struct", in: c), plain, "cpp keyword")
        XCTAssertNotEqual(color(of: "\"counter\"", in: c), plain, "cpp string")
        XCTAssertNotEqual(color(of: "// a counter", in: c), plain, "cpp comment")
        XCTAssertNotEqual(color(of: "42", in: c), plain, "cpp number")
        XCTAssertNotEqual(color(of: "Counter", in: c), plain, "cpp type")
        XCTAssertNotEqual(color(of: "bump", in: c), plain, "cpp function")
        XCTAssertGreaterThanOrEqual(colors(c).count, 5)

        // D-45: Metal is C++14-based and has no licensed grammar of its own, so a `metal` fence is the C++ grammar.
        let metal = """
        #include <metal_stdlib>
        using namespace metal;

        // scales in place
        kernel void scale(device float4 *v [[buffer(0)]], uint i [[thread_position_in_grid]]) {
            v[i] = v[i] * 2.0f;
        }
        """
        let m = render(metal, "metal")
        XCTAssertNotEqual(color(of: "using", in: m), plain, "metal keyword")
        XCTAssertNotEqual(color(of: "<metal_stdlib>", in: m), plain, "metal string")
        XCTAssertNotEqual(color(of: "// scales in place", in: m), plain, "metal comment")
        XCTAssertNotEqual(color(of: "2.0f", in: m), plain, "metal number")
        XCTAssertNotEqual(color(of: "kernel", in: m), plain, "metal type")
        XCTAssertNotEqual(color(of: "scale", in: m), plain, "metal function")
        for hint in ["c++", "cc", "metal", "msl"] { XCTAssertEqual(render(metal, hint), render(metal, "cpp"), hint) }

        let opencl = """
        /* vector add */
        __kernel void vec_add(__global const float *a, __global float *c, const int n) {
            int i = get_global_id(0);
            if (i < n) c[i] = a[i] + 1.5f;
        }
        """
        let cl = render(opencl, "opencl")
        XCTAssertNotEqual(color(of: "__kernel", in: cl), plain, "opencl keyword")
        XCTAssertNotEqual(color(of: "/* vector add */", in: cl), plain, "opencl comment")
        XCTAssertNotEqual(color(of: "1.5f", in: cl), plain, "opencl number")
        XCTAssertNotEqual(color(of: "float", in: cl), plain, "opencl type")
        XCTAssertNotEqual(color(of: "vec_add", in: cl), plain, "opencl function")
        XCTAssertEqual(render(opencl, "cl"), cl)

        let json = """
        { "name": "mdv6", "count": 42, "ok": true }
        """
        let j = render(json, "json")
        XCTAssertNotEqual(color(of: "\"mdv6\"", in: j), plain, "json string")
        XCTAssertNotEqual(color(of: "42", in: j), plain, "json number")
        XCTAssertNotEqual(color(of: "true", in: j), plain, "json constant")
        XCTAssertGreaterThanOrEqual(colors(j).count, 3)

        let lua = """
        -- counts to n
        local function sum(n)
            local t = 0
            for i = 1, n do t = t + i end
            return t, "done"
        end
        """
        let l = render(lua, "lua")
        XCTAssertNotEqual(color(of: "local", in: l), plain, "lua keyword")
        XCTAssertNotEqual(color(of: "-- counts to n", in: l), plain, "lua comment")
        XCTAssertNotEqual(color(of: "\"done\"", in: l), plain, "lua string")
        XCTAssertNotEqual(color(of: "0", in: l), plain, "lua number")
        XCTAssertNotEqual(color(of: "sum", in: l), plain, "lua function")
        XCTAssertGreaterThanOrEqual(colors(l).count, 4)

        let perl = """
        #!/usr/bin/perl
        use strict;
        my $count = 42;          # a comment
        sub greet {
            my ($name) = @_;
            print "hello, $name\\n";
            return $count > 10 ? "big" : 'small';
        }
        """
        let p = render(perl, "perl")
        XCTAssertNotEqual(color(of: "my", in: p), plain, "perl keyword")
        XCTAssertNotEqual(color(of: "# a comment", in: p), plain, "perl comment")
        XCTAssertNotEqual(color(of: "\"big\"", in: p), plain, "perl string")
        XCTAssertNotEqual(color(of: "42", in: p), plain, "perl number")
        XCTAssertNotEqual(color(of: "greet", in: p), plain, "perl function")
        XCTAssertGreaterThanOrEqual(colors(p).count, 4)
        for hint in ["pl", "perl5"] { XCTAssertEqual(render(perl, hint), p, hint) }
    }

    /// T-51, R-43, C-05: a `markdown` fence is highlighted by two grammars — the block grammar colours the
    /// structure (the heading text, the markers) and `tree-sitter-markdown-inline` colours what is inside a
    /// paragraph (strong, emphasis, a code span, a link) — and `md`/`gfm` resolve to the same grammar.
    func testMarkdownBlockAndInlineCaptures() {
        let plain = MDVTheme.highContrast.codePalette.plain.hex
        let md = """
        # Heading one

        A paragraph with **bold**, _italic_, `code span` and a [link](https://example.com).

        - item one

        > a quote
        """
        let a = CodeRenderer.shared.render(code: md, languageHint: "markdown", theme: .highContrast, zoom: 1)
        XCTAssertNotEqual(color(of: "Heading one", in: a), plain, "heading text")
        XCTAssertNotEqual(color(of: "bold", in: a), plain, "strong emphasis")
        XCTAssertNotEqual(color(of: "italic", in: a), plain, "emphasis")
        XCTAssertNotEqual(color(of: "code span", in: a), plain, "code span")
        XCTAssertNotEqual(color(of: "link", in: a), plain, "link label")
        XCTAssertNotEqual(color(of: "https://example.com", in: a), plain, "link destination")
        XCTAssertGreaterThanOrEqual(colors(a).count, 4)
        for hint in ["md", "gfm"] {
            XCTAssertEqual(CodeRenderer.shared.render(code: md, languageHint: hint, theme: .highContrast, zoom: 1), a, hint)
        }
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
            XCTAssertTrue(font.isMonospace)
        }
        let s = String(a.characters)
        let idx = AttributedString.Index(s.range(of: "# note")!.lowerBound, within: a)!
        XCTAssertTrue(a.runs[idx][CodeRenderer.FontKey.self]!.isItalic)
        let x = AttributedString.Index(s.startIndex, within: a)!
        XCTAssertFalse(a.runs[x][CodeRenderer.FontKey.self]!.isItalic)
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
