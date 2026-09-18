// WindowAccessor — E-30 / C-18.1 / E-26: captures a SwiftUI window's `NSWindow`, marks it non-restorable, registers
// its session with the model, applies the theme's colour scheme to the whole window (title bar included) and reports
// the window's close and appearance changes to the session.
import SwiftUI
import AppKit

public struct WindowAccessor: NSViewRepresentable {
    public let session: DocumentSession
    public let isDark: Bool
    @Binding public var window: NSWindow?

    public init(session: DocumentSession, isDark: Bool, window: Binding<NSWindow?>) { self.session = session; self.isDark = isDark; _window = window }

    /// E-30: never restorable; no tabs.
    public static func configure(_ window: NSWindow) {
        window.isRestorable = false
        window.tabbingMode = .disallowed
    }

    public func makeNSView(context: Context) -> NSView {
        let v = HookView()
        let binding = $window
        v.onWindow = { [session] window in
            DispatchQueue.main.async { binding.wrappedValue = window }
            WindowAccessor.configure(window)
            DispatchQueue.main.async {                                       // never publish inside a view update
                session.model.register(session: session, window: window)
                session.backingScale = window.backingScaleFactor
            }
            context.coordinator.observe(window: window, session: session)
        }
        return v
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        // C-18.1: the window takes the theme's colour scheme (the application-wide appearance is not changed, R-29)
        nsView.window?.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator {
        private var observers: [NSObjectProtocol] = []
        private var snapshotObserver: NSObjectProtocol?

        /// Observation aid (plan §6 stand-in for a locked screen): with `MDV6_SNAPSHOT_DIR` set, a distributed
        /// notification `mdv6.snapshot` (userInfo `name`) writes the window's rendered content to `<dir>/<name>.png`.
        func installSnapshotHook(window: NSWindow) {
            guard let dir = ProcessInfo.processInfo.environment["MDV6_SNAPSHOT_DIR"], !dir.isEmpty else { return }
            snapshotObserver = DistributedNotificationCenter.default().addObserver(forName: Notification.Name("mdv6.snapshot"), object: nil, queue: .main) { note in
                // the frame view includes the title bar and toolbar (C-18.1/C-18.2 are observable), else the content view
                guard window.isKeyWindow || NSApp.keyWindow == nil, let view = window.contentView?.superview ?? window.contentView else { return }
                let name = (note.userInfo?["name"] as? String) ?? "window"
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
            }
        }

        func observe(window: NSWindow, session: DocumentSession) {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
            installSnapshotHook(window: window)
            observers = [
                NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
                    Task { @MainActor in
                        session.windowWillClose()
                        session.model.unregister(window: window)
                    }
                },
                NotificationCenter.default.addObserver(forName: NSWindow.didChangeBackingPropertiesNotification, object: window, queue: .main) { _ in
                    Task { @MainActor in session.backingScale = window.backingScaleFactor }
                },
            ]
        }
        deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
    }

    final class HookView: NSView {
        var onWindow: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindow?(window) }
        }
    }
}
