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
    /// E-38: what a window created on demand does first, and how to create one (captured from the commands' environment).
    var pendingWindowActions: [(DocumentSession) -> Void] = []
    var openWindow: OpenWindowAction?

    private init() {
        model = AppModel.bootstrap()
        let m = model
        CommandCenter.targetWindow = { m.targetWindow }                   // R-01
    }

    /// E-38 (F-178): with no document window, create one only when the action has a file, then run the action in it;
    /// otherwise beep (a missing bookmark or placeholder) or do nothing (a cancelled panel).
    func onDemand(_ action: AppModel.DemandAction, beepIfNot: Bool = false, _ run: @escaping (DocumentSession) -> Void) {
        guard model.needsWindow(for: action) else { if beepIfNot { NSSound.beep() }; return }
        pendingWindowActions.append(run)
        openWindow?(id: "blank")
    }

    /// §5.1 with E-38: a command reaches the target window, or — with no document window — creates one when it has a file.
    func dispatch(_ command: AppCommand) {
        if model.hasDocumentWindow { CommandCenter.post(command); return }
        switch command {
        case .openFile, .openInNewWindow:
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true; panel.allowsMultipleSelection = true; panel.allowsOtherFileTypes = true
            let urls = panel.runModal() == .OK ? panel.urls : []
            onDemand(.openURLs(urls)) { $0.open(urls: urls) }
        case .jumpToPlaceholder: onDemand(.placeholder, beepIfNot: true) { $0.jumpToPlaceholder() }
        case .slot1, .slot2, .slot3, .slot4, .slot5:
            let n = [AppCommand.slot1, .slot2, .slot3, .slot4, .slot5].firstIndex(of: command)! + 1
            guard let row = model.bookmarks.slot(n) else { return }
            onDemand(.bookmark(row), beepIfNot: true) { $0.openBookmark(row) }
        case .help: onDemand(.help) { HelpManager.openHelp(in: $0) }
        default: break                                                    // window-scoped: disabled with no window
        }
    }
}

public final class mdv6AppDelegate: NSObject, NSApplicationDelegate {
    /// E-30: no state restoration.
    public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { false }
    /// R-47 / E-38: closing the last window leaves the application running.
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    public func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["NSQuitAlwaysKeepsWindows": false, "ApplePersistenceIgnoreState": true])
    }

    /// R-01 / R-40: an open event goes to the target window; before the main window has started, it is the cold-start
    /// argument; with no document window, a window is created for it (E-38). The application is never activated here:
    /// LaunchServices activates it for an ordinary open, and `open -g` must leave the frontmost application frontmost;
    /// only an already-active application brings the target window forward.
    public func application(_ application: NSApplication, open urls: [URL]) {
        let env = AppEnvironment.shared
        guard env.launched else { env.pendingOpen += urls; return }
        guard env.model.hasDocumentWindow else { env.onDemand(.openURLs(urls)) { $0.open(urls: urls) }; return }
        env.model.handleOpenEvent(urls: urls)
        if NSApp.isActive, let w = env.model.targetWindow { w.makeKeyAndOrderFront(nil) }
    }

    /// E-38: a Dock click with no window creates one that follows R-40 (the history head, or `EMPTY`).
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let env = AppEnvironment.shared
        guard env.launched, !env.model.hasDocumentWindow else { return true }
        env.onDemand(.dockReopen) { $0.restoreOnLaunch() }
        return false
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)                                  // R-01: no explicit activation (open -g)
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
        .handlesExternalEvents(matching: [])          // F-010: a LaunchServices open is the delegate's (R-01), never a new window
        .commands { commands }

        // ⌘⇧O: a second window with its own session (the only way to get one, E-26/E-30)
        WindowGroup(id: "document", for: URL.self) { $url in
            SecondaryWindowContent(url: url)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1280, height: 820)
        .handlesExternalEvents(matching: [])

        // E-38: a window created on demand when none exists; it runs the pending action (open, bookmark, ⌘0, Help, Dock).
        WindowGroup(id: "blank") {
            BlankWindowContent()
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1280, height: 820)
        .handlesExternalEvents(matching: [])
    }

    // MARK: §5.1 menus

    @CommandsBuilder private var commands: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Install Command Line Tool…") { CLIInstaller.install() }
        }
        CommandGroup(replacing: .newItem) {
            Button("Open…") { environment.dispatch(.openFile) }.keyboardShortcut("o", modifiers: .command)
            Button("Open in New Window…") { environment.dispatch(.openInNewWindow) }.keyboardShortcut("o", modifiers: [.command, .shift])
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
        DocumentCommands(history: environment.model.history)
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
            Toggle("Show Frontmatter", isOn: $preferences.showFrontmatter)                   // R-44, C-04
        }
        CommandMenu("Bookmarks") {
            Button("Bookmark Current Spot") { CommandCenter.post(.bookmarkCurrentSpot) }.keyboardShortcut("d", modifiers: .command)
            Divider()
            Button("Set Placeholder") { CommandCenter.post(.setPlaceholder) }.keyboardShortcut("0", modifiers: [.command, .shift])
            Button("Jump to Placeholder") { environment.dispatch(.jumpToPlaceholder) }.keyboardShortcut("0", modifiers: .command)
            Divider()
            ForEach(1...BookmarksManager.slotCount, id: \.self) { n in
                let row = bookmarks.slot(n)
                Button(row.map { "\(n). \($0.title)" } ?? "\(n). (empty)") { environment.dispatch([.slot1, .slot2, .slot3, .slot4, .slot5][n - 1]) }
                    .keyboardShortcut(KeyEquivalent(Character("\(n)")), modifiers: .command)
                    .disabled(row == nil)
            }
        }
        CommandGroup(replacing: .help) {
            Button("mdv6 Help") { environment.dispatch(.help) }.keyboardShortcut("?", modifiers: .command)
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

/// §5.1 File · Close File / Close Window / Close All (R-47) and Navigate · Back / Forward / Next File / Previous File
/// (R-18, R-48), enabled from the key window's session; also captures `openWindow` for E-38's windows on demand.
struct DocumentCommands: Commands {
    @ObservedObject var history: HistoryManager
    @FocusedObject private var session: DocumentSession?
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        let _ = { AppEnvironment.shared.openWindow = openWindow }()
        CommandGroup(replacing: .saveItem) {
            Button("Close File") { CommandCenter.post(.closeFile) }.keyboardShortcut("w", modifiers: .command)
                .disabled(!(session?.canCloseFile ?? false))
            Button("Close Window") { CommandCenter.targetWindow()?.performClose(nil) }.keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(session == nil)
            Divider()
            Button("Close All") { CommandCenter.post(.closeAll) }.keyboardShortcut("w", modifiers: [.command, .option])
                .disabled(history.entries.isEmpty || session == nil)
        }
        CommandMenu("Navigate") {
            Button("Back") { CommandCenter.post(.back) }.keyboardShortcut(.leftArrow, modifiers: .command)
            Button("Forward") { CommandCenter.post(.forward) }.keyboardShortcut(.rightArrow, modifiers: .command)
            Divider()
            Button("Next File") { CommandCenter.post(.nextFile) }.keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(!(session?.hasNextFile ?? false))
            Button("Previous File") { CommandCenter.post(.previousFile) }.keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(!(session?.hasPreviousFile ?? false))
        }
    }
}

/// E-38: a window created on demand runs the pending action once its session exists.
struct BlankWindowContent: View {
    @StateObject private var session = DocumentSession(model: AppEnvironment.shared.model)

    var body: some View {
        DocumentRootView(session: session)
            .frame(minWidth: 640, minHeight: 400)
            .onAppear {
                let env = AppEnvironment.shared
                guard !env.pendingWindowActions.isEmpty else { return }
                let action = env.pendingWindowActions.removeFirst()
                DispatchQueue.main.async { action(session) }
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
