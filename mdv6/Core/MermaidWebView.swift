// MermaidWebView — R-46 / C-06.5: Mermaid types the native library lacks, drawn by the bundled, SHA-pinned mermaid.js
// (C-13, K-19) in a `WKWebView` that loads nothing but its own page (I-001, I-003, D-46): a content rule list blocks
// every load, a navigation delegate refuses every navigation after the page, mermaid runs with
// `securityLevel: 'strict'` and `logLevel: 'fatal'`, and the view is not inspectable. Host integration (F-151): the
// block's menu instead of WebKit's, wheel events to the article, no first responder, no selection.
import SwiftUI
import AppKit
import WebKit

public enum MermaidWebPage {
    /// K-19: the block's minimum height while and after it measures.
    public static let minimumHeight: CGFloat = 60
    /// K-19: reports within this many points of the last are ignored.
    public static let reportTolerance: CGFloat = 0.5
    /// K-19: 12 px top + 12 px bottom padding added to the SVG height.
    public static let verticalPadding: CGFloat = 24

    /// The pinned script: flat in the app's `Resources/` (C-13), else at its repository path (tests, harness — F-183).
    public static let script: String? = {
        if let url = Resources.flatURL(file: "mermaid.min.js"), let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Vendor/mermaid/mermaid.min.js").standardizedFileURL
        return try? String(contentsOf: repo, encoding: .utf8)
    }()

    /// C-06.5: the generated page — charset, the background as CSS, the escaped source, the script inline, and the
    /// run-and-report script (two animation frames plus a `ResizeObserver`; unpadded pages, used by print, also poll
    /// every 50 ms until three equal reads or 3 s, because an unshown window may get no animation frames).
    public static func html(source: String, theme: MDVTheme, padded: Bool) -> String {
        let escaped = source.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        let bg = theme.rgba.secondaryBackground
        let css = "rgb(\(bg.r),\(bg.g),\(bg.b))"
        let pad = padded ? Int(verticalPadding) : 0
        let poll = padded ? "" : """
          var t0 = Date.now(), last = -1, same = 0;
          var timer = setInterval(function () {
            var h = svg.getBoundingClientRect().height;
            if (h === last) { same++; } else { same = 0; last = h; }
            if (same >= 3 || Date.now() - t0 > 3000) { clearInterval(timer); report(); }
          }, 50);
        """
        return """
        <!DOCTYPE html>
        <html><head><meta charset="UTF-8">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          html, body { background: \(css); }
          .mermaid { padding: \(padded ? "12px 18px" : "0"); }
          .mermaid svg { max-width: 100%; height: auto; display: block; }
        </style></head>
        <body>
        <div class="mermaid">\(escaped)</div>
        <script>\(script ?? "")</script>
        <script>
          mermaid.initialize({ startOnLoad: false, theme: '\(theme.isDark ? "dark" : "default")', securityLevel: 'strict', logLevel: 'fatal' });
          mermaid.run().then(function () {
            var svg = document.querySelector('.mermaid svg');
            if (!svg) { window.webkit.messageHandlers.mermaidHeight.postMessage({ ok: false, error: 'no SVG' }); return; }
            function report() { window.webkit.messageHandlers.mermaidHeight.postMessage({ ok: true, height: svg.getBoundingClientRect().height + \(pad) }); }
            requestAnimationFrame(function () { requestAnimationFrame(report); });
            if (typeof ResizeObserver !== 'undefined') { new ResizeObserver(report).observe(svg); }
            \(poll)
          }).catch(function (e) { window.webkit.messageHandlers.mermaidHeight.postMessage({ ok: false, error: String(e) }); });
        </script>
        </body></html>
        """
    }

    /// I-001 / D-46: one compiled rule list that blocks every URL, awaited before the first page loads.
    @MainActor private static var ruleList: WKContentRuleList?

    @MainActor static func blockAllRules() async -> WKContentRuleList? {
        if let ruleList { return ruleList }
        let json = #"[{"trigger":{"url-filter":".*"},"action":{"type":"block"}}]"#
        let list = try? await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "mdv6-mermaid-block-all", encodedContentRuleList: json)
        ruleList = list
        return list
    }

    /// C-06.5: the configuration every mermaid web view uses — the message handler and the blocking rules.
    @MainActor static func configuration(handler: WKScriptMessageHandler, rules: WKContentRuleList?) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.userContentController.add(handler, name: "mermaidHeight")
        if let rules { config.userContentController.add(rules) }
        config.websiteDataStore = .nonPersistent()
        return config
    }
}

/// F-151: a web view that takes no first responder, shows the block's menu instead of WebKit's, forwards wheel
/// events to the article, and is the hit target for its whole frame (so nothing inside the diagram is selectable).
public final class LockedWebView: WKWebView {
    public var blockMenuItems: [(String, () -> Void)] = []
    /// The wheel forwarder; defaults to the enclosing scroll view.
    public var forwardWheel: (() -> Void)? = nil
    private var lastWheel: NSEvent?

    public override var acceptsFirstResponder: Bool { false }
    public override func becomeFirstResponder() -> Bool { false }
    public override func hitTest(_ point: NSPoint) -> NSView? { frame.contains(point) ? self : nil }
    public override func mouseDown(with event: NSEvent) {}
    public override func mouseDragged(with event: NSEvent) {}

    public override func scrollWheel(with event: NSEvent) {
        if let forwardWheel { forwardWheel(); return }
        enclosingScrollView?.scrollWheel(with: event)
    }

    public override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        for (title, action) in blockMenuItems { menu.addItem(ClosureMenuItem(title: title, action: action)) }
        return menu
    }
    public override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {}
}

final class ClosureMenuItem: NSMenuItem {
    private let run: () -> Void
    init(title: String, action run: @escaping () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError("unused") }
    @objc private func fire() { run() }
}

/// What a page reported.
public enum MermaidWebResult: Equatable { case height(CGFloat), failed(String), timeout }

/// C-06.5: receives the page's reports, and refuses every navigation after the page's own (D-46).
final class MermaidWebCoordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    var onReport: (MermaidWebResult) -> Void = { _ in }
    private var loadedPage = false
    private var lastHeight: CGFloat?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "mermaidHeight", let body = message.body as? [String: Any] else { return }
        guard (body["ok"] as? Bool) == true, let h = body["height"] as? Double, h > 0 else {
            onReport(.failed((body["error"] as? String) ?? "no positive height")); return
        }
        let height = CGFloat(h)
        if let last = lastHeight, abs(last - height) < MermaidWebPage.reportTolerance { return }
        lastHeight = height
        onReport(.height(height))
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let isPage = !loadedPage && action.navigationType == .other && (action.request.url?.absoluteString ?? "about:blank") == "about:blank"
        if isPage { loadedPage = true; decisionHandler(.allow) } else { decisionHandler(.cancel) }
    }

    func reset() { loadedPage = false; lastHeight = nil }
}

/// C-06.5 on screen: one locked web view per web-dispatched block.
struct MermaidWebDiagram: NSViewRepresentable {
    let source: String
    let theme: MDVTheme
    let menuItems: [(String, () -> Void)]
    let onResult: (MermaidWebResult) -> Void

    func makeCoordinator() -> MermaidWebCoordinator { MermaidWebCoordinator() }

    func makeNSView(context: Context) -> LockedWebView {
        let coordinator = context.coordinator
        let web = LockedWebView(frame: .zero, configuration: MermaidWebPage.configuration(handler: coordinator, rules: nil))
        web.navigationDelegate = coordinator
        if #available(macOS 13.3, *) { web.isInspectable = false }
        return web
    }

    func updateNSView(_ web: LockedWebView, context: Context) {
        web.blockMenuItems = menuItems
        let coordinator = context.coordinator
        coordinator.onResult = onResult
        let key = "\(theme.id)|\(theme.isDark)|\(source.hashValue)"                   // C-06.5: reload only on change
        guard web.loadKey != key else { return }
        web.loadKey = key
        coordinator.reset()
        let html = MermaidWebPage.html(source: source, theme: theme, padded: true)
        Task { @MainActor in
            if let rules = await MermaidWebPage.blockAllRules() {                     // D-46: the rules before the page
                web.configuration.userContentController.removeAllContentRuleLists()
                web.configuration.userContentController.add(rules)
            }
            web.loadHTMLString(html, baseURL: nil)
        }
    }

    static func dismantleNSView(_ web: LockedWebView, coordinator: MermaidWebCoordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "mermaidHeight")
    }
}

extension MermaidWebCoordinator {
    var onResult: (MermaidWebResult) -> Void { get { onReport } set { onReport = newValue } }
}

private var loadKeyAssociation = 0
extension LockedWebView {
    var loadKey: String? {
        get { objc_getAssociatedObject(self, &loadKeyAssociation) as? String }
        set { objc_setAssociatedObject(self, &loadKeyAssociation, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }
}

/// R-46: the block — a spinner at 60 pt until the first report, then the measured height; the R-10 fallback on failure;
/// one accessibility element labelled *Mermaid diagram*.
public struct MermaidWebContainer: View {
    public let source: String
    public let theme: MDVTheme
    public let menuItems: [(String, () -> Void)]

    @State private var height: CGFloat = MermaidWebPage.minimumHeight
    @State private var measured = false
    @State private var failed = false

    public var body: some View {
        Group {
            if failed || MermaidWebPage.script == nil {
                MermaidFallbackView(message: "Mermaid diagram could not be rendered", source: source, theme: theme)
            } else {
                MermaidWebDiagram(source: source, theme: theme, menuItems: menuItems) { result in
                    switch result {
                    case .height(let h): height = max(h, MermaidWebPage.minimumHeight); measured = true
                    case .failed, .timeout: failed = true
                    }
                }
                .frame(height: height)
                .overlay { if !measured { ProgressView().controlSize(.small) } }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mermaid diagram")
        .accessibilityHint("Use Show Mermaid Source to view the diagram code.")
    }
}

/// C-06.5 offscreen (tests) and C-21.3 (print): one render in a borderless window that is never ordered front.
@MainActor
public enum MermaidWebRenderer {
    public static func measure(source: String, theme: MDVTheme, width: CGFloat, padded: Bool, timeout: TimeInterval) async -> MermaidWebResult {
        let session = await Session(width: width, source: source, theme: theme, padded: padded)
        defer { session.close() }
        return await session.result(timeout: timeout)
    }

    /// One offscreen page. Kept alive while its result is awaited (a `CGPDFPage` or snapshot is taken from it by print).
    @MainActor final class Session {
        let window: NSWindow
        let web: LockedWebView
        let coordinator = MermaidWebCoordinator()
        private var continuation: CheckedContinuation<MermaidWebResult, Never>?
        private var settled: MermaidWebResult?

        init(width: CGFloat, source: String, theme: MDVTheme, padded: Bool) async {
            let rules = await MermaidWebPage.blockAllRules()
            window = NSWindow(contentRect: NSRect(x: -30_000, y: -30_000, width: width, height: 400), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            web = LockedWebView(frame: NSRect(x: 0, y: 0, width: width, height: 400),
                                configuration: MermaidWebPage.configuration(handler: coordinator, rules: rules))
            web.navigationDelegate = coordinator
            if #available(macOS 13.3, *) { web.isInspectable = false }
            window.contentView = web
            coordinator.onReport = { [weak self] r in self?.deliver(r) }
            web.loadHTMLString(MermaidWebPage.html(source: source, theme: theme, padded: padded), baseURL: nil)
        }

        private func deliver(_ r: MermaidWebResult) {
            if case .height = r, case .height = settled { settled = r; return }
            settled = r
            continuation?.resume(returning: r); continuation = nil
        }

        func result(timeout: TimeInterval) async -> MermaidWebResult {
            if let settled { return settled }
            return await withCheckedContinuation { c in
                continuation = c
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                    guard let self, let c = self.continuation else { return }
                    self.continuation = nil
                    c.resume(returning: .timeout)
                }
            }
        }

        func close() {
            web.configuration.userContentController.removeScriptMessageHandler(forName: "mermaidHeight")
            window.close()
        }
    }
}
