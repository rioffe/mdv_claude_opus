// mdv6App — application entry (W0 stub; W6 replaces the body with the §5.1 menus and window).
import AppKit

public enum mdv6Main {
    public static func run() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "mdv6"
        w.isRestorable = false          // E-30
        w.center()
        w.makeKeyAndOrderFront(nil)
        window = w
        NSApp.activate(ignoringOtherApps: true)
    }

    // E-30: no window-state restoration.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
