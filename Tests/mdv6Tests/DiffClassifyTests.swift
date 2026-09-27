import XCTest
@testable import mdv6Core

/// C-05.1 diff line classification (R-50). T-58 (unit half).
final class DiffClassifyTests: XCTestCase {

    private func kinds(_ text: String) -> [DiffLineKind] {
        DiffHighlighter.classify(text.split(separator: "\n", omittingEmptySubsequences: false))
    }

    /// C-05.1: inside a hunk the counters decide — `--- stale comment` is a removal, not a header. R-50, T-58.
    func testGitDiffFromFixture() {
        let body = """
        diff --git a/schema.sql b/schema.sql
        index 3b18e51..a4c2d09 100644
        --- a/schema.sql
        +++ b/schema.sql
        @@ -1,6 +1,6 @@
         CREATE TABLE notes (
             id INTEGER PRIMARY KEY,
        --- stale comment
        +    -- body is markdown
             body TEXT NOT NULL,
        -    created TEXT
        +    created TEXT NOT NULL DEFAULT (datetime('now'))
         );
        diff --git a/notes.txt b/notes.txt
        new file mode 100644
        index 0000000..e69de29
        --- /dev/null
        +++ b/notes.txt
        @@ -0,0 +1 @@
        +remember the milk
        \\ No newline at end of file
        """
        XCTAssertEqual(kinds(body), [.meta, .meta, .meta, .meta, .hunkHeader,
                                     .context, .context, .removed, .added, .context, .removed, .added, .context,
                                     .meta, .meta, .meta, .meta, .meta, .hunkHeader, .added, .note])
    }

    /// C-05.1 step 3: without `@@` headers, `+`/`-` lines still colour; a space or empty line is context; other text meta.
    func testHandWrittenSnippet() {
        XCTAssertEqual(kinds(" func f() {\n-    old\n+    new\n }\n\nprose"), [.context, .removed, .added, .context, .context, .meta])
    }

    /// C-05.1 step 2: an omitted count is 1; a malformed `@@` line is meta; a context line reduced to empty counts.
    func testHunkCounts() {
        XCTAssertEqual(DiffHighlighter.hunkCounts("@@ -1 +1,2 @@").map { [$0.old, $0.new] }, [1, 2])
        XCTAssertEqual(DiffHighlighter.hunkCounts("@@ -3,0 +4 @@ fn").map { [$0.old, $0.new] }, [0, 1])
        XCTAssertNil(DiffHighlighter.hunkCounts("@@ x y @@"))
        XCTAssertEqual(kinds("@@ x y @@\n+a"), [.meta, .added])
        XCTAssertEqual(kinds("@@ -1,2 +1,2 @@\n\n--- x\n+++ y"), [.hunkHeader, .context, .removed, .added])
    }

    /// C-05: the fence words that select the classifier.
    func testFenceWords() {
        XCTAssertEqual(DiffHighlighter.fenceWords, ["diff", "patch"])
    }
}
