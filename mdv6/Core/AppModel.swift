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

    /// E-26: the key window's session; with no key window yet (cold start), the first registered session.
    @MainActor
    public var keySession: DocumentSession? { session(for: keyWindowProvider()) ?? mainSession ?? sessions.first?.session }

    /// R-01 / E-26: an open event (Finder, `open -a`, `bin/mdv6 FILE`) goes to the key window only.
    @MainActor
    public func handleOpenEvent(urls: [URL]) {
        keySession?.open(urls: urls)
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
