// AppModel — the injected store (§9.0 `AppModel.bootstrap`), the §10 isolation variables, and the services.
// `startup/register` (R-40, E-26) are added by W5.
import Foundation

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
