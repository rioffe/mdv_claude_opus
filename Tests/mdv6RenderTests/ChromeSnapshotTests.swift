import XCTest
import SwiftUI
import AppKit
@testable import mdv6Core

/// The plan's stand-in for a locked screen (T-44 static clauses, I-015): hosts the real `DocumentRootView` in an
/// offscreen window on a seeded, isolated store under Sevilla, Charcoal and Twilight and writes
/// `build/observed/snapshot-<theme>.png` for a person to compare with `reference/MDV-ORIGINAL-SEVILLA.png`. The test
/// asserts only that the panes were drawn (non-blank, theme-coloured); the look is judged by eye in the build report.
@MainActor
final class ChromeSnapshotTests: XCTestCase {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    func testHostedWindowSnapshots() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-snap-\(UUID().uuidString)")
        let suite = "mdv6.snap.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: dir) }
        let model = AppModel.bootstrap(supportDir: dir, defaultsSuite: suite)
        let math = Self.root.appendingPathComponent("test-docs/math.md")
        for f in ["links.md", "code.md", "tables.md", "syntax.md"] { model.history.add(path: Self.root.appendingPathComponent("test-docs/\(f)").path) }
        model.preferences.inspectorVisible = true
        model.preferences.bookmarksExpanded = true
        let doc = ParsedDocument(raw: try String(contentsOf: math, encoding: .utf8))
        for i in doc.tocHeadings.map(\.blockIndex).filter({ $0 > 0 }).prefix(4) { model.bookmarks.add(path: math.path, document: doc, index: i) }
        let out = Self.root.appendingPathComponent("build/observed")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        var seen: [String: Bitmap] = [:]
        for themeId in ["sevilla", "charcoal", "twilight"] {
            model.preferences.themeId = themeId
            let session = DocumentSession(model: model)
            session.open(urls: [math])
            session.setPlaceholder()
            let hosting = NSHostingView(rootView: DocumentRootView(session: session).frame(width: 1400, height: 900))
            let window = NSWindow(contentRect: NSRect(x: -30000, y: -30000, width: 1400, height: 900), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            for _ in 0..<12 { RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05)) }
            guard let view = window.contentView?.superview ?? window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return XCTFail() }
            view.cacheDisplay(in: view.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent("snapshot-\(themeId).png"))
            window.close()
            let image = NSImage(size: rep.size); image.addRepresentation(rep)
            let bitmap = Bitmap(image: image)!
            let theme = ThemeCatalog.theme(id: themeId)!
            // drawn: a good share of non-page pixels, and the accent colour present (badges, the current placeholder row)
            var nonPage = 0, accent = 0
            for y in stride(from: 0, to: bitmap.height, by: 3) { for x in stride(from: 0, to: bitmap.width, by: 3) {
                let p = bitmap.pixel(x, y)
                if abs(Int(p.r) - Int(theme.rgba.background.r)) > 8 || abs(Int(p.g) - Int(theme.rgba.background.g)) > 8 || abs(Int(p.b) - Int(theme.rgba.background.b)) > 8 { nonPage += 1 }
                if abs(Int(p.r) - Int(theme.rgba.accent.r)) <= 6 && abs(Int(p.g) - Int(theme.rgba.accent.g)) <= 6 && abs(Int(p.b) - Int(theme.rgba.accent.b)) <= 6 { accent += 1 }
            } }
            XCTAssertGreaterThan(nonPage, bitmap.width * bitmap.height / 9 / 50, "\(themeId): panes drawn")
            XCTAssertGreaterThan(accent, 20, "\(themeId): accent-filled rows and badges present")
            let corner = bitmap.pixel(bitmap.width - 3, bitmap.height - 3)
            XCTAssertLessThan(abs(Int(corner.r) - Int(theme.rgba.background.r)), 12, "\(themeId) page colour at the corner")
            seen[themeId] = bitmap
        }
        XCTAssertNotNil(RenderMetrics.pixelMismatch(seen["sevilla"]!, seen["charcoal"]!))
        XCTAssertGreaterThan(RenderMetrics.pixelMismatch(seen["sevilla"]!, seen["charcoal"]!)!, 0.5, "the themes differ in colour, not in structure")
    }
}
