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

    /// C-18.1: the window takes the theme's colour scheme. Idempotent (F-003): assigning a fresh `NSAppearance` on every
    /// view update re-rendered the hierarchy forever under dark themes, so the appearance changes only when its name differs.
    /// Returns whether an assignment was scheduled.
    @discardableResult
    public static func applyAppearance(_ window: NSWindow, isDark: Bool) -> Bool {
        let wanted: NSAppearance.Name = isDark ? .darkAqua : .aqua
        guard window.appearance?.name != wanted else { return false }
        DispatchQueue.main.async { window.appearance = NSAppearance(named: wanted) }
        return true
    }

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
        // C-18.1: the window's appearance is owned by `.preferredColorScheme` on the root view (F-006); an assignment here
        // raced it — `applyAppearance` stays for the F-003 contract and is no longer called from the update path.
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
                let every = (note.userInfo?["all"] as? String) == "1"                   // one file per window, suffixed by its title
                guard every || window.isKeyWindow || NSApp.keyWindow == nil, let view = window.contentView?.superview ?? window.contentView else { return }
                var name = (note.userInfo?["name"] as? String) ?? "window"
                if every { name += "-" + window.title.replacingOccurrences(of: "/", with: "_") }
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
            }
        }

        private var driveObserver: NSObjectProtocol?

        /// Observation aid (same guard): `mdv6.drive` with userInfo `command` (an `AppCommand` raw value) posts that §5.1
        /// command addressed to this window — the path a menu item takes — and `action`/`index` calls a session entry point
        /// (`selectTOC`, `hover`, `clearPlaceholder`, `moveUp` … the handlers the pane's controls call).
        func installDriveHook(window: NSWindow, session: DocumentSession) {
            guard let dir = ProcessInfo.processInfo.environment["MDV6_SNAPSHOT_DIR"], !dir.isEmpty else { return }
            driveObserver = DistributedNotificationCenter.default().addObserver(forName: Notification.Name("mdv6.drive"), object: nil, queue: .main) { note in
                guard window.isKeyWindow || NSApp.keyWindow == nil || NSApp.keyWindow === window else { return }
                if let raw = note.userInfo?["command"] as? String, let command = AppCommand(rawValue: raw) {
                    Task { @MainActor in CommandCenter.post(command, window: window) }
                    return
                }
                guard let action = note.userInfo?["action"] as? String else { return }
                let index = Int((note.userInfo?["index"] as? String) ?? "") ?? 0
                Task { @MainActor in
                    let bookmarks = session.model.bookmarks
                    switch action {
                    case "selectTOC": session.selectTOC(blockIndex: index)
                    case "hover": session.hoverChanged(index)
                    case "unhover": session.hoverChanged(nil)
                    case "clearPlaceholder": session.clearPlaceholder()
                    case "moveUp": if let r = bookmarks.slot(index) { bookmarks.moveUp(id: r.id) }
                    case "moveDown": if let r = bookmarks.slot(index) { bookmarks.moveDown(id: r.id) }
                    case "moveToTop": if let r = bookmarks.slot(index) { bookmarks.moveToTop(id: r.id) }
                    case "moveToBottom": if let r = bookmarks.slot(index) { bookmarks.moveToBottom(id: r.id) }
                    case "removeBookmark": if let r = bookmarks.slot(index) { bookmarks.remove(id: r.id) }
                    case "scrollTo": session.topVisibleBlock = index
                    case "deleteHistoryRow": if index < session.model.history.entries.count { session.deleteHistoryRow(session.model.history.entries[index]) }
                    case "toggleBookmarks": session.model.preferences.bookmarksExpanded.toggle()
                    case "toggleInspector": session.model.preferences.inspectorVisible.toggle()
                    case "newWindow": if let path = note.userInfo?["path"] as? String { NotificationCenter.default.post(name: .mdv6OpenInNewWindow, object: nil, userInfo: ["path": path, "window": window]) }
                    case "openHit": if let path = note.userInfo?["path"] as? String { session.openHit(path: path) }
                    case "collapseSidebar": session.model.preferences.sidebarCollapsed = true
                    case "expandSidebar": session.model.preferences.sidebarCollapsed = false
                    default: break
                    }
                }
            }
        }

        func observe(window: NSWindow, session: DocumentSession) {
            installDriveHook(window: window, session: session)
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

extension Notification.Name {
    /// Observation aid: opens `userInfo["path"]` in a second window through the ⌘⇧O path (`openWindow`).
    public static let mdv6OpenInNewWindow = Notification.Name("mdv6.openInNewWindow")
}
