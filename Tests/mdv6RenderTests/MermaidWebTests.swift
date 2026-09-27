import XCTest
import AppKit
import WebKit
@testable import mdv6Core

/// R-46 / C-06.5 / K-19 / E-34 / I-001 / I-003: the Mermaid web path — the pinned script renders a web-dispatched diagram
/// offscreen, nothing leaves the page, a rejected source fails, and the host integration (F-151) holds. T-54.
@MainActor
final class MermaidWebTests: XCTestCase {

    override func setUp() async throws {
        guard MermaidWebPage.script != nil else {
            throw XCTSkip("mermaid.min.js not fetched — run `bash tools/fetch-mermaid.sh ensure` (C-13, F-183)")
        }
    }

    /// C-06.5, R-46, K-19: `gantt.md`'s chart renders; the reported height is above the 60 pt minimum. T-54.
    func testGanttRendersOffscreen() async throws {
        let fixture = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../test-docs/gantt.md").standardizedFileURL, encoding: .utf8)
        let source = try XCTUnwrap(FenceParts.mermaidSources(in: fixture).first)
        XCTAssertFalse(MermaidDispatch.isNative(source))
        let result = await MermaidWebRenderer.measure(source: source, theme: .highContrast, width: 760, padded: true, timeout: 10)
        guard case .height(let h) = result else { return XCTFail("gantt did not render: \(result)") }
        XCTAssertGreaterThan(h, MermaidWebPage.minimumHeight)
    }

    /// E-34, C-06.5: a source mermaid.js rejects reports a failure (the R-10 fallback), never a height.
    func testRejectedSourceFails() async {
        let result = await MermaidWebRenderer.measure(source: "gantt\n  this is not :: a gantt ::: chart\n  )))", theme: .highContrast, width: 760, padded: true, timeout: 10)
        guard case .failed = result else { return XCTFail("expected a failure, got \(result)") }
    }

    /// I-001, I-003, D-46, E-34: a web-dispatched diagram whose labels reference a local server and carry a `click`
    /// directive causes zero requests; the page carries `strict` and `logLevel: 'fatal'`; the source is HTML-escaped.
    func testNothingLeavesThePage() async throws {
        let server = try ImageLoadingTests.RecordingServer(image: Data([0x89, 0x50, 0x4E, 0x47]))
        defer { server.stop() }
        let base = "http:" + ImageLoadingTests.RecordingServer.slashes + "127.0.0.1:\(server.port)"
        let source = "flowchart-elk TD\n  A[\"<img src='\(base)/img.png'>\"] --> B\n  click A \"\(base)/click\"\n"
        _ = await MermaidWebRenderer.measure(source: source, theme: .highContrast, width: 600, padded: true, timeout: 8)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(server.requests.count, 0, server.requests.map(\.path).joined(separator: ", "))
        let html = MermaidWebPage.html(source: "a < b & c", theme: .highContrast, padded: true)
        XCTAssertTrue(html.contains("a &lt; b &amp; c"))
        XCTAssertTrue(html.contains("securityLevel: 'strict'"))
        XCTAssertTrue(html.contains("logLevel: 'fatal'"))
        XCTAssertTrue(html.contains("theme: 'default'"))
        XCTAssertTrue(MermaidWebPage.html(source: "pie", theme: .twilight, padded: true).contains("theme: 'dark'"))
    }

    /// D-46, I-001: the content rule list is what refuses loads — a page that loads an image and calls `fetch` reaches
    /// the server without it and never with it (the page itself still loads: the gantt case renders under the same rules).
    func testRuleListBlocksEveryLoad() async throws {
        let server = try ImageLoadingTests.RecordingServer(image: Data([0x89, 0x50]))
        defer { server.stop() }
        let url = "http:" + ImageLoadingTests.RecordingServer.slashes + "127.0.0.1:\(server.port)/img.png"
        let html = "<html><body><img src='\(url)'><script>fetch('\(url)?f')</script></body></html>"
        func load(rules: WKContentRuleList?) async {
            let c = MermaidWebCoordinator()
            let web = LockedWebView(frame: NSRect(x: 0, y: 0, width: 300, height: 300), configuration: MermaidWebPage.configuration(handler: c, rules: rules))
            web.navigationDelegate = c
            let w = NSWindow(contentRect: NSRect(x: -30000, y: -30000, width: 300, height: 300), styleMask: [.borderless], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false; w.contentView = web
            web.loadHTMLString(html, baseURL: nil)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            w.close()
        }
        await load(rules: nil)
        XCTAssertGreaterThan(server.requests.count, 0, "control: without the rules the page does reach the server")
        let before = server.requests.count
        await load(rules: await MermaidWebPage.blockAllRules())
        XCTAssertEqual(server.requests.count, before, "with the rules nothing leaves the page")
    }

    /// C-06.5 host integration (F-151): no first responder, the block menu (never WebKit's), wheel events forwarded to
    /// the enclosing view, and clicks hit the web view itself (no selection inside the diagram).
    func testHostIntegration() {
        let web = LockedWebView(frame: NSRect(x: 0, y: 0, width: 200, height: 100), configuration: WKWebViewConfiguration())
        XCTAssertFalse(web.acceptsFirstResponder)
        web.blockMenuItems = [("Copy Code", {}), ("Show Mermaid Source", {})]
        let menu = web.menu(for: NSEvent())
        XCTAssertEqual(menu?.items.map(\.title), ["Copy Code", "Show Mermaid Source"])
        let host = WheelRecorder(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
        host.addSubview(web)
        XCTAssertTrue(web.hitTest(NSPoint(x: 10, y: 10)) === web)
        web.forwardWheel = { host.received += 1 }
        web.scrollWheel(with: NSEvent())
        XCTAssertEqual(host.received, 1)
    }

    final class WheelRecorder: NSView { var received = 0 }
}
