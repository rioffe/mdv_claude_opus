import XCTest
@testable import mdv6Core

/// C-03 query construction, K-14 limits, R-30 zoom, §7.2 column width, C-15 history codec, C-05 language table, R-35 diagnostics.
final class MiscContractTests: XCTestCase {

    // MARK: C-03

    /// C-03, E-24: tokens split on whitespace, `" ( ) : * ^` dropped, empties discarded, each wrapped `"tok"*`, joined
    /// with spaces; no survivors → nil (no search). K-03: limit 80, snippet 14 tokens. T-24.
    func testFTSQueryConstruction() {
        XCTAssertEqual(FTSQuery.make("auth"), "\"auth\"*")
        XCTAssertEqual(FTSQuery.make("  auth   token "), "\"auth\"* \"token\"*")
        XCTAssertEqual(FTSQuery.make("a:b (c) \"d\" e* f^"), "\"ab\"* \"c\"* \"d\"* \"e\"* \"f\"*")
        XCTAssertNil(FTSQuery.make(""))
        XCTAssertNil(FTSQuery.make("   \t "))
        XCTAssertNil(FTSQuery.make("\"\" () :"))
        XCTAssertEqual(FTSQuery.make("résumé"), "\"résumé\"*")
        XCTAssertEqual(FTSQuery.limit, 80)
        XCTAssertEqual(FTSQuery.snippetTokens, 14)
        XCTAssertEqual(FTSQuery.orderBy, "ORDER BY rank ASC, path COLLATE NOCASE ASC, path ASC")
        XCTAssertEqual(FTSQuery.tokenizer, "unicode61 remove_diacritics 2")
    }

    // MARK: K-14

    /// K-14, E-28, R-41: every ceiling admits content at the ceiling and rejects one unit above; binary units; the E-28 message. T-41.
    func testContentLimits() {
        XCTAssertEqual(ContentLimits.documentBytes, 64 * 1024 * 1024)
        XCTAssertEqual(ContentLimits.mermaidBytes, 1024 * 1024)
        XCTAssertEqual(ContentLimits.latexBytes, 64 * 1024)
        XCTAssertEqual(ContentLimits.encodedImageBytes, 32 * 1024 * 1024)
        XCTAssertEqual(ContentLimits.decodedImageBytes, 256 * 1024 * 1024)
        XCTAssertEqual(ContentLimits.decodedImagePixels, 64_000_000)
        XCTAssertEqual(ContentLimits.imageAxisPixels, 16_384)
        for kind in ContentLimits.Kind.allCases {
            let c = ContentLimits.ceiling(kind)
            XCTAssertTrue(ContentLimits.admits(c, kind: kind), "\(kind) at ceiling")
            XCTAssertFalse(ContentLimits.admits(c + 1, kind: kind), "\(kind) above ceiling")
            XCTAssertTrue(ContentLimits.admits(0, kind: kind))
        }
        XCTAssertTrue(ContentLimits.admitsImage(width: 16_384, height: 3_906, bytesPerPixel: 4))    // 63,999,... px
        XCTAssertFalse(ContentLimits.admitsImage(width: 16_385, height: 1, bytesPerPixel: 4))
        XCTAssertFalse(ContentLimits.admitsImage(width: 8_000, height: 8_001, bytesPerPixel: 4))    // 64,008,000 px
        XCTAssertTrue(ContentLimits.admitsImage(width: 8_000, height: 8_000, bytesPerPixel: 4))     // 64,000,000 px, 256,000,000 B
        XCTAssertFalse(ContentLimits.admitsImage(width: 8_000, height: 8_000, bytesPerPixel: 5))    // 320,000,000 B > 256 MiB
        XCTAssertEqual(ContentLimits.exceededMessage, "input exceeds limit")
    }

    // MARK: R-30

    /// R-30, K-04, D-37: `s' = clamp(roundHalfAway(10s)/10 + d, 0.60, 2.50)`; HUD shows `floor(100s' + 0.5)`. T-11.
    func testZoomStep() {
        XCTAssertEqual(ZoomStep.apply(stored: 1.25, delta: 0.10), 1.4, accuracy: 1e-9)
        XCTAssertEqual(ZoomStep.apply(stored: 1.25, delta: -0.10), 1.2, accuracy: 1e-9)
        XCTAssertEqual(ZoomStep.apply(stored: 1.15, delta: 0.10), 1.3, accuracy: 1e-9)    // 11.5 rounds away → 12
        var s = 1.0
        for _ in 0..<5 { s = ZoomStep.apply(stored: s, delta: 0.10) }
        XCTAssertEqual(s, 1.5, accuracy: 1e-9)
        XCTAssertEqual(ZoomStep.hudPercent(s), 150)
        XCTAssertEqual(ZoomStep.apply(stored: 2.45, delta: 0.10), 2.5, accuracy: 1e-9)
        XCTAssertEqual(ZoomStep.apply(stored: 2.5, delta: 0.10), 2.5, accuracy: 1e-9)
        XCTAssertEqual(ZoomStep.apply(stored: 0.6, delta: -0.10), 0.6, accuracy: 1e-9)
        XCTAssertEqual(ZoomStep.apply(stored: 0.65, delta: -0.10), 0.6, accuracy: 1e-9)
        XCTAssertEqual(ZoomStep.clampOnRead(9), 2.5)
        XCTAssertEqual(ZoomStep.clampOnRead(0.1), 0.6)
        XCTAssertEqual(ZoomStep.clampOnRead(1.37), 1.37)
        XCTAssertEqual(ZoomStep.hudPercent(1.0), 100)
        XCTAssertEqual(ZoomStep.hudPercent(0.6), 60)
        XCTAssertEqual(ZoomStep.hudPercent(1.375), 138)
        XCTAssertEqual(ZoomStep.step, 0.10); XCTAssertEqual(ZoomStep.minimum, 0.60); XCTAssertEqual(ZoomStep.maximum, 2.50)
        XCTAssertEqual(ZoomStep.hudDuration, 0.9)
    }

    // MARK: §7.2

    /// §7.2, K-13, K-07, R-11: `w_col = min(area − side − insp, max) − 2p − 2b`; raster width
    /// `⌊min(natural, max(w_col − 36, 1))⌋`, handles counted with the panes. T-18.
    func testColumnWidthFormula() {
        XCTAssertEqual(ColumnWidth.column(area: 2000, sidebar: 0, inspector: 0, maxWidth: 860, padding: 40), 768)
        XCTAssertEqual(ColumnWidth.rasterWidth(natural: 5000, column: 768), 732)
        XCTAssertEqual(ColumnWidth.column(area: 1000, sidebar: 220, inspector: 240, maxWidth: 860, padding: 40),
                       1000 - (220 + 8) - (240 + 8) - 80 - 12)
        XCTAssertEqual(ColumnWidth.column(area: 1000, sidebar: 0, inspector: 0, maxWidth: nil, padding: 30), 1000 - 60 - 12)
        XCTAssertEqual(ColumnWidth.rasterWidth(natural: 300, column: 768), 300)           // never wider than natural
        XCTAssertEqual(ColumnWidth.rasterWidth(natural: 500.7, column: 768), 500)         // whole points
        XCTAssertEqual(ColumnWidth.rasterWidth(natural: 5000, column: 36), 1)             // lower bound 1 pt
        XCTAssertEqual(ColumnWidth.rasterWidth(natural: 5000, column: -100), 1)
        XCTAssertEqual(ColumnWidth.rasterWidth(natural: 5000, column: 37.9), 1)
        XCTAssertEqual(ColumnWidth.blockPadding, 6); XCTAssertEqual(ColumnWidth.handleWidth, 8); XCTAssertEqual(ColumnWidth.mermaidInset, 36)
    }

    // MARK: C-15

    /// C-15: `[{id, path, addedAt}]` Codable with the default date strategy, most recent first; a value that fails to
    /// decode yields an empty history; unknown keys are ignored. T-25, I-013.
    func testHistoryCodec() {
        let e = HistoryEntry(id: UUID(), path: "/tmp/a.md", addedAt: Date(timeIntervalSinceReferenceDate: 1234.5))
        XCTAssertEqual(e.filename, "a.md")
        let data = HistoryCodec.encode([e])
        let json = try! JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        XCTAssertEqual(Set(json[0].keys), ["id", "path", "addedAt"])
        XCTAssertEqual(json[0]["addedAt"] as? Double, 1234.5)
        XCTAssertEqual(json[0]["id"] as? String, e.id.uuidString)
        XCTAssertEqual(HistoryCodec.decode(data), [e])
        XCTAssertEqual(HistoryCodec.decode(nil), [])
        XCTAssertEqual(HistoryCodec.decode(Data("not json".utf8)), [])
        XCTAssertEqual(HistoryCodec.decode(Data("{\"a\":1}".utf8)), [])
        let extra = Data("[{\"id\":\"\(e.id.uuidString)\",\"path\":\"/tmp/a.md\",\"addedAt\":1234.5,\"unknown\":true}]".utf8)
        XCTAssertEqual(HistoryCodec.decode(extra), [e])
    }

    // MARK: C-05

    /// C-05, K-05, R-38, R-43: language resolution — first word lower-cased, direct names, aliases; anything else plain. T-06, T-37, T-51.
    func testLanguageResolution() {
        XCTAssertEqual(CodeLanguage.resolve(infoString: "Swift"), .swift)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "js {highlight}"), .javascript)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "jsx"), .javascript)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "javascriptreact"), .javascript)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "node"), .javascript)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "sh"), .bash)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "zsh"), .bash)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "shell"), .bash)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "py"), .python)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "python3"), .python)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "rb"), .ruby)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "yml"), .yaml)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "rs"), .rust)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "golang"), .go)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "h"), .c)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "objective-c"), .c)
        XCTAssertEqual(CodeLanguage.resolve(infoString: "objc"), .c)
        for alias in ["sql", "sqlite", "postgresql", "postgres", "mysql", "plsql", "tsql"] {
            XCTAssertEqual(CodeLanguage.resolve(infoString: alias), .sql, alias)
        }
        for direct in ["c", "go", "rust", "bash", "javascript", "yaml", "toml", "python", "ruby"] {
            XCTAssertEqual(CodeLanguage.resolve(infoString: direct)?.rawValue, direct)
        }
        // R-43: the added grammars, and the fence words that resolve to them (`metal` is the C++ grammar, D-45).
        for direct in ["cpp", "json", "lua", "opencl", "perl", "markdown"] {
            XCTAssertEqual(CodeLanguage.resolve(infoString: direct)?.rawValue, direct)
        }
        for alias in ["c++", "cplusplus", "cc", "cxx", "cp", "hpp", "hxx", "hh", "metal", "msl"] {
            XCTAssertEqual(CodeLanguage.resolve(infoString: alias), .cpp, alias)
        }
        for alias in ["cl", "opencl-c"] { XCTAssertEqual(CodeLanguage.resolve(infoString: alias), .opencl, alias) }
        for alias in ["pl", "perl5"] { XCTAssertEqual(CodeLanguage.resolve(infoString: alias), .perl, alias) }
        for alias in ["md", "gfm"] { XCTAssertEqual(CodeLanguage.resolve(infoString: alias), .markdown, alias) }
        XCTAssertNil(CodeLanguage.resolve(infoString: "brainfuck"))
        XCTAssertNil(CodeLanguage.resolve(infoString: "fish"))
        XCTAssertNil(CodeLanguage.resolve(infoString: "console"))
        XCTAssertNil(CodeLanguage.resolve(infoString: nil))
        XCTAssertNil(CodeLanguage.resolve(infoString: ""))
        XCTAssertEqual(CodeLanguage.allCases.count, 17)
    }

    /// C-05, R-08: the prompt-aware set is a separate test on the raw first word (`fish`/`console` yes, `shell-session`
    /// /`powershell` no); a block is prompted when ≥ half its non-empty lines start `$ `/`# `; Copy Without Prompts strips
    /// the prompt from prompted lines and keeps every other line, preserving the line count. T-06.
    func testPromptAwareFences() {
        for word in ["bash", "sh", "zsh", "fish", "shell", "console", "Bash"] {
            XCTAssertTrue(CodeLanguage.isPromptAware(infoString: word), word)
        }
        for word in ["shell-session", "powershell", "python", "", "ps1"] {
            XCTAssertFalse(CodeLanguage.isPromptAware(infoString: word), word)
        }
        XCTAssertFalse(CodeLanguage.isPromptAware(infoString: nil))
        let code = "$ ls -la\ntotal 0\n$ echo hi\nhi\n\n# whoami\nroot"
        XCTAssertTrue(CodeLanguage.isPrompted(code: code))                       // 3 of 6 non-empty lines
        XCTAssertFalse(CodeLanguage.isPrompted(code: "$ a\nb\nc"))              // 1 of 3
        XCTAssertFalse(CodeLanguage.isPrompted(code: ""))
        let stripped = CodeLanguage.stripPrompts(code)
        XCTAssertEqual(stripped, "ls -la\ntotal 0\necho hi\nhi\n\nwhoami\nroot")
        XCTAssertEqual(stripped.split(separator: "\n", omittingEmptySubsequences: false).count,
                       code.split(separator: "\n", omittingEmptySubsequences: false).count)
        XCTAssertEqual(CodeLanguage.stripPrompts("$notaprompt\n#!/bin/sh"), "$notaprompt\n#!/bin/sh")
    }

    /// C-05: the language label shown on a block is the raw first word lower-cased, or `text` when absent (R-08).
    func testLanguageLabel() {
        XCTAssertEqual(CodeLanguage.label(infoString: "Brainfuck extra"), "brainfuck")
        XCTAssertEqual(CodeLanguage.label(infoString: nil), "text")
        XCTAssertEqual(CodeLanguage.label(infoString: "  "), "text")
    }

    // MARK: R-35

    /// R-35, I-003: the only diagnostics sink takes a closed event set, never a document string; every line is `[mdv6]`-prefixed.
    func testDiagnosticsEvents() {
        var captured: [String] = []
        Diagnostics.sink = { captured.append($0) }
        defer { Diagnostics.sink = nil }
        Diagnostics.log(.storeFailure("cannot open /tmp/x/mdv6.db: disk I/O error"))
        Diagnostics.log(.fontRegistrationFailure("Alegreya-Regular.otf"))
        Diagnostics.log(.editorLaunchFailure("The application “Foo” could not be launched"))
        XCTAssertEqual(captured.count, 3)
        XCTAssertTrue(captured.allSatisfy { $0.hasPrefix("[mdv6] ") })
        XCTAssertTrue(captured[0].contains("persistence"))
        XCTAssertTrue(captured[1].contains("font"))
        XCTAssertTrue(captured[2].contains("editor"))
    }
}
