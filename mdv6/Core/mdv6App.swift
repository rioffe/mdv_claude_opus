// mdv6App — the application: the §5.1 menus and shortcuts (each command addressed to the key window, E-26), the
// windows (`WindowGroup`, non-restorable, E-30; ⌘⇧O is the only way to a second window), LaunchServices open events
// (R-01) and the R-40 cold-start rule, the CLI installer (§5.1, C-14 alerts), and the Help menu (R-31).
import SwiftUI
import AppKit

public enum mdv6Main {
    public static func run() {
        FontRegistration.registerBundledFonts()
        Mdv6App.main()
    }
}

/// The process-wide model, created once before the SwiftUI app starts.
@MainActor
public final class AppEnvironment: ObservableObject {
    public static let shared = AppEnvironment()
    public let model: AppModel
    /// R-40: URLs handed over by LaunchServices before the main window restored its history head.
    var pendingOpen: [URL] = []
    var launched = false

    private init() { model = AppModel.bootstrap() }
}

public final class mdv6AppDelegate: NSObject, NSApplicationDelegate {
    /// E-30: no state restoration.
    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { false }
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    public func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false, "ApplePersistenceIgnoreState": true])
    }

    /// R-01 / R-40: an open event goes to the key window; before the main window has started, it is the cold-start argument.
    public func application(_ application: NSApplication, open urls: [URL]) {
        let env = AppEnvironment.shared
        if env.launched { env.model.handleOpenEvent(urls: urls) } else { env.pendingOpen += urls }
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct Mdv6App: App {
    @NSApplicationDelegateAdaptor(mdv6AppDelegate.self) private var delegate
    @StateObject private var environment = AppEnvironment.shared
    @StateObject private var preferences = AppEnvironment.shared.model.preferences
    @StateObject private var bookmarks = AppEnvironment.shared.model.bookmarks
    @StateObject private var placeholder = AppEnvironment.shared.model.placeholder

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindowContent()
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1280, height: 820)
        .commands { commands }

        // ⌘⇧O: a second window with its own session (the only way to get one, E-26/E-30)
        WindowGroup(id: "document", for: URL.self) { $url in
            SecondaryWindowContent(url: url)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1280, height: 820)
    }

    // MARK: §5.1 menus

    @CommandsBuilder private var commands: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Install Command Line Tool…") { CLIInstaller.install() }
        }
        CommandGroup(replacing: .newItem) {
            Button("Open…") { CommandCenter.post(.openFile) }.keyboardShortcut("o", modifiers: .command)
            Button("Open in New Window…") { CommandCenter.post(.openInNewWindow) }.keyboardShortcut("o", modifiers: [.command, .shift])
            Menu("Edit") {
                Button("Edit Current File") { CommandCenter.post(.editCurrentFile) }.keyboardShortcut("e", modifiers: .command)
                Button("Choose Editor…") { CLIInstaller.chooseEditor(preferences) }
                Button("Forget Editor") { preferences.editorAppPath = "" }.disabled(preferences.editorAppPath.isEmpty)
            }
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Find…") { CommandCenter.post(.find) }.keyboardShortcut("f", modifiers: .command)
            Button("Search History…") { CommandCenter.post(.searchHistory) }.keyboardShortcut("f", modifiers: [.command, .shift])
        }
        CommandMenu("Navigate") {
            Button("Back") { CommandCenter.post(.back) }.keyboardShortcut(.leftArrow, modifiers: .command)
            Button("Forward") { CommandCenter.post(.forward) }.keyboardShortcut(.rightArrow, modifiers: .command)
        }
        CommandGroup(replacing: .sidebar) {
            Button(preferences.sidebarCollapsed ? "Show Sidebar" : "Hide Sidebar") { CommandCenter.post(.toggleSidebar) }.keyboardShortcut("s", modifiers: [.control, .command])
            Button(preferences.inspectorVisible ? "Hide Inspector" : "Show Inspector") { CommandCenter.post(.toggleInspector) }.keyboardShortcut("0", modifiers: [.option, .command])
            Divider()
            Button("Zoom In") { CommandCenter.post(.zoomIn) }.keyboardShortcut("=", modifiers: .command).disabled(preferences.fontScale >= ZoomStep.maximum - 1e-9)
            Button("Zoom Out") { CommandCenter.post(.zoomOut) }.keyboardShortcut("-", modifiers: .command).disabled(preferences.fontScale <= ZoomStep.minimum + 1e-9)
            Button("Actual Size") { CommandCenter.post(.actualSize) }.disabled(abs(preferences.fontScale - 1.0) < 1e-9)
            Divider()
            let allowed = ThemeCatalog.resolve(id: preferences.themeId, isDarkAppearance: NSApp?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua).smartTypographyAllowed
            Toggle(allowed ? "Smart Typography" : "Smart Typography (off for this theme)", isOn: $preferences.smartTypography).disabled(!allowed)
            Toggle("Load Remote Images", isOn: $preferences.loadRemoteImages)
        }
        CommandMenu("Bookmarks") {
            Button("Bookmark Current Spot") { CommandCenter.post(.bookmarkCurrentSpot) }.keyboardShortcut("d", modifiers: .command)
            Divider()
            Button("Set Placeholder") { CommandCenter.post(.setPlaceholder) }.keyboardShortcut("0", modifiers: [.command, .shift])
            Button("Jump to Placeholder") { CommandCenter.post(.jumpToPlaceholder) }.keyboardShortcut("0", modifiers: .command)
            Divider()
            ForEach(1...BookmarksManager.slotCount, id: \.self) { n in
                let row = bookmarks.slot(n)
                Button(row.map { "\(n). \($0.title)" } ?? "\(n). (empty)") { CommandCenter.post([.slot1, .slot2, .slot3, .slot4, .slot5][n - 1]) }
                    .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
                    .disabled(row == nil)
            }
        }
        CommandGroup(replacing: .help) {
            Button("mdv6 Help") { CommandCenter.post(.help) }.keyboardShortcut("?", modifiers: .command)
        }
    }
}

/// The main window: its session restores the history head (R-40) unless a cold-start argument arrived first.
struct MainWindowContent: View {
    @StateObject private var session = DocumentSession(model: AppEnvironment.shared.model)

    var body: some View {
        DocumentRootView(session: session)
            .frame(minWidth: 640, minHeight: 400)
            .onAppear {
                let env = AppEnvironment.shared
                guard !env.launched else { return }
                env.launched = true
                let arguments = env.pendingOpen + CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }.map { URL(fileURLWithPath: $0) }
                env.pendingOpen = []
                // LaunchServices may deliver the cold-start argument a moment after the window appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    let late = env.pendingOpen
                    env.pendingOpen = []
                    env.model.startup(arguments: arguments + late, session: session)
                }
            }
    }
}

struct SecondaryWindowContent: View {
    let url: URL?
    @StateObject private var session = DocumentSession(model: AppEnvironment.shared.model)

    var body: some View {
        DocumentRootView(session: session)
            .frame(minWidth: 640, minHeight: 400)
            .onAppear { if let url { session.open(urls: [url]) } }
    }
}

/// §5.1 mdv6 · Install Command Line Tool…: an unprivileged symlink first, then an AppleScript *with administrator
/// privileges*; every outcome is an `NSAlert` (C-14), except cancelling the authorisation dialog.
enum CLIInstaller {
    static let link = "/usr/local/bin/mdv6"

    @MainActor
    static func install() {
        guard let helper = Bundle.main.url(forResource: "mdv6", withExtension: nil), FileManager.default.fileExists(atPath: helper.path) else {
            alert("CLI helper missing", "The bundled command-line helper was not found in this build."); return
        }
        if let existing = try? FileManager.default.destinationOfSymbolicLink(atPath: link), existing == helper.path {
            alert("Already installed", "\(link) already points at this application's command-line tool."); return
        }
        do {
            try? FileManager.default.removeItem(atPath: link)
            try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: helper.path)
            alert("Command line tool installed", "\(link) → \(helper.path)"); return
        } catch {}
        let script = "do shell script \"mkdir -p /usr/local/bin && ln -sf '\(helper.path)' '\(link)'\" with administrator privileges"
        var error: NSDictionary? = nil
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? Int) == -128 { return }          // cancelled: no alert
            alert("Install failed", (error[NSAppleScript.errorMessage] as? String) ?? "unknown error"); return
        }
        alert("Command line tool installed", "\(link) → \(helper.path)")
    }

    @MainActor
    static func chooseEditor(_ preferences: Preferences) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose Editor"
        if panel.runModal() == .OK, let url = panel.url { preferences.editorAppPath = url.path }
    }

    @MainActor
    static func alert(_ title: String, _ message: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.runModal()
    }
}
