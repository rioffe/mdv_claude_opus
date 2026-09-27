// AppModel — the injected store (§9.0 `AppModel.bootstrap`), the §10 isolation variables, the services, the R-40
// startup and the E-26 window↔session registry (only the key window's session acts on commands and open events).
import Foundation
import AppKit

public final class AppModel {
    public let supportDirectory: URL
    public let defaultsSuite: String?
    public let defaults: UserDefaults
    public let database: Database
    public let preferences: Preferences
    public let history: HistoryManager
    public let bookmarks: BookmarksManager
    public let placeholder: PlaceholderStore
    public let fileSystem: FileSystem

    /// §10: `~/Library/Application Support/mdv6`.
    public static var defaultSupportDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/mdv6")
    }

    /// §10 precedence: explicit arguments (the test bootstrap) → `MDV6_SUPPORT_DIR` / `MDV6_DEFAULTS_SUITE` (non-empty)
    /// → the standard locations.
    public static func resolveStore(supportDir: URL?, defaultsSuite: String?, environment: [String: String]) -> (supportDir: URL, defaultsSuite: String?) {
        let dir: URL
        if let supportDir { dir = supportDir }
        else if let env = environment["MDV6_SUPPORT_DIR"], !env.isEmpty { dir = URL(fileURLWithPath: env) }
        else { dir = defaultSupportDirectory }
        let suite: String?
        if let defaultsSuite { suite = defaultsSuite }
        else if let env = environment["MDV6_DEFAULTS_SUITE"], !env.isEmpty { suite = env }
        else { suite = nil }
        return (dir, suite)
    }

    public static func bootstrap(supportDir: URL? = nil, defaultsSuite: String? = nil,
                                 environment: [String: String] = ProcessInfo.processInfo.environment,
                                 fileSystem: FileSystem = .live) -> AppModel {
        let store = resolveStore(supportDir: supportDir, defaultsSuite: defaultsSuite, environment: environment)
        try? FileManager.default.createDirectory(at: store.supportDir, withIntermediateDirectories: true)
        let defaults = store.defaultsSuite.flatMap { UserDefaults(suiteName: $0) } ?? UserDefaults.standard
        return AppModel(supportDirectory: store.supportDir, defaultsSuite: store.defaultsSuite, defaults: defaults, fileSystem: fileSystem)
    }

    // MARK: sessions and windows (E-26, R-40)

    private var sessions: [(window: NSWindow, session: DocumentSession)] = []
    private var mainSession: DocumentSession?
    /// Test hook: what counts as the key window (`NSApp.keyWindow` in the app).
    public var keyWindowProvider: () -> NSWindow? = { NSApp?.keyWindow }

    @MainActor
    public func register(session: DocumentSession, window: NSWindow) {
        sessions.removeAll { $0.window === window }
        sessions.append((window, session))
        if mainSession == nil { mainSession = session }
    }

    @MainActor
    public func unregister(window: NSWindow) {
        sessions.removeAll { $0.window === window }
        if let m = mainSession, !sessions.contains(where: { $0.session === m }) { mainSession = sessions.first?.session }
    }

    @MainActor
    public func session(for window: NSWindow?) -> DocumentSession? {
        guard let window else { return nil }
        return sessions.first { $0.window === window }?.session
    }

    /// Test hooks: the application's windows front to back, and whether a window is visible.
    public var orderedWindowsProvider: () -> [NSWindow] = { NSApp?.orderedWindows ?? [] }
    public var visibility: (NSWindow) -> Bool = { $0.isVisible }

    /// R-01: the key window when it is a document window, else the frontmost visible document window, else any.
    @MainActor
    public var targetWindow: NSWindow? {
        if let key = keyWindowProvider(), session(for: key) != nil { return key }
        if let front = orderedWindowsProvider().first(where: { w in visibility(w) && sessions.contains { $0.window === w } }) { return front }
        return sessions.first?.window
    }

    /// R-01 / E-26: the session of the target window; with no window registered yet (cold start), the main session.
    @MainActor
    public var targetSession: DocumentSession? { session(for: targetWindow) ?? mainSession ?? sessions.first?.session }

    /// E-26 (unchanged name): the session commands and open events address.
    @MainActor
    public var keySession: DocumentSession? { targetSession }

    /// E-38: whether any document window is open.
    @MainActor
    public var hasDocumentWindow: Bool { !sessions.isEmpty }

    /// R-01 / E-26: an open event (Finder, `open -a`, `bin/mdv6 FILE`) goes to the target window only.
    @MainActor
    public func handleOpenEvent(urls: [URL]) {
        targetSession?.open(urls: urls)
    }

    /// R-47 / E-36: *Close All* — every row (index rows and scroll positions with them; bookmarks kept) and every window's
    /// stacks go, and every window enters `EMPTY`; E-26's one exception, since history is shared.
    @MainActor
    public func closeAll() {
        history.clear()
        for s in sessions.map(\.session) + [mainSession].compactMap({ $0 }) { s.resetForCloseAll() }
    }

    /// E-38: what a window would be created for when none exists.
    public enum DemandAction { case openURLs([URL]), bookmark(Database.BookmarkRow), placeholder, help, dockReopen }

    /// E-38 (F-178): create a window only once the action has a file to load.
    public func needsWindow(for action: DemandAction) -> Bool {
        switch action {
        case .openURLs(let urls): return !urls.isEmpty
        case .bookmark(let row): return fileSystem.exists(row.path)
        case .placeholder: return placeholder.placeholder.map { fileSystem.exists($0.path) } ?? false
        case .help, .dockReopen: return true
        }
    }

    /// R-40: the main window's launch — a cold-start argument pre-empts restoring the history head.
    @MainActor
    @discardableResult
    public func startup(arguments: [URL], session: DocumentSession) -> DocumentSession {
        mainSession = session
        if arguments.isEmpty { session.restoreOnLaunch() } else { session.coldStart(arguments) }
        history.reindexOnLaunch()
        return session
    }

    init(supportDirectory: URL, defaultsSuite: String?, defaults: UserDefaults, fileSystem: FileSystem) {
        self.supportDirectory = supportDirectory
        self.defaultsSuite = defaultsSuite
        self.defaults = defaults
        self.fileSystem = fileSystem
        database = Database(url: supportDirectory.appendingPathComponent("mdv6.db"))
        preferences = Preferences(defaults: defaults)
        history = HistoryManager(defaults: defaults, database: database, fileSystem: fileSystem)
        bookmarks = BookmarksManager(database: database, fileSystem: fileSystem)
        placeholder = PlaceholderStore()
    }
}
