import XCTest
@testable import mdv6Core

/// R-35, I-003, T-36: nothing document-derived reaches a log — every log call site goes through `Diagnostics`, and a
/// session exercised end to end emits no line containing document text, a query string or a path.
@MainActor
final class DiagnosticsTests: XCTestCase {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// T-36, R-35: the only `NSLog`/`print` call sites in the application code are the `Diagnostics` sink (the vendored
    /// typesetter's font-registration lines are permitted by R-35 and live outside `mdv6/Core`).
    func testNoOtherLogCallSites() throws {
        let core = Self.root.appendingPathComponent("mdv6/Core")
        var offenders: [String] = []
        for case let url as URL in FileManager.default.enumerator(at: core, includingPropertiesForKeys: nil)! where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (n, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.split(separator: "/", maxSplits: 1).first.map(String.init) ?? ""
                let calls = code.range(of: #"(?<![A-Za-z_.])(NSLog|print|debugPrint|os_log|Logger)\("#, options: .regularExpression) != nil
                if calls && url.lastPathComponent != "Diagnostics.swift" {
                    offenders.append("\(url.lastPathComponent):\(n + 1)")
                }
            }
        }
        XCTAssertEqual(offenders, [])
    }

    /// T-36, I-003: opening, finding, searching and bookmarking a document produces no diagnostic line at all on a healthy
    /// store; the store-failure line names only the store, never content or a query.
    func testSessionEmitsNoContentLines() {
        var lines: [String] = []
        Diagnostics.sink = { lines.append($0) }
        defer { Diagnostics.sink = nil }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-diag-\(UUID().uuidString)")
        let suite = "mdv6.diag.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: dir) }
        let fs = FileSystem.fake(files: ["/secret/doc.md": "# SECRETHEADING\n\nSECRETBODY text"], mtime: 1)
        let model = AppModel.bootstrap(supportDir: dir, defaultsSuite: suite, fileSystem: fs)
        let s = DocumentSession(model: model, watcherFactory: { _, _ in Cancelled() }, pasteboard: { _ in }, systemOpener: { _ in }, beeper: {})
        s.open(urls: [URL(fileURLWithPath: "/secret/doc.md")])
        s.openFind(); s.setFindQuery("SECRETQUERY"); s.findNext()
        _ = model.database.search("SECRETSEARCH")
        s.bookmarkCurrentSpot(); s.setPlaceholder(); s.copySection(at: 0)
        XCTAssertEqual(lines, [])
    }

    final class Cancelled: FileWatching { func cancel() {} }
}
