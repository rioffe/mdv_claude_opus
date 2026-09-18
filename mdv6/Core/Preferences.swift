// Preferences — C-04: every `UserDefaults` key, its default and its invalid-value fallback (R-32, K-04).
import Foundation

public final class Preferences: ObservableObject {
    public enum Key {
        public static let themeId = "mdv6_theme_id"
        public static let fontScale = "mdv6_font_scale"
        public static let smartTypography = "mdv6_smart_typography"
        public static let loadRemoteImages = "mdv6_load_remote_images"
        public static let sidebarCollapsed = "mdv6_sidebar_collapsed"
        public static let inspectorVisible = "mdv6_inspector_visible"
        public static let inspectorWidth = "mdv6_inspector_width"
        public static let bookmarksExpanded = "mdv6_bookmarks_expanded"
        public static let bookmarksHeight = "mdv6_bookmarks_height"
        public static let editorAppPath = "mdv6_editor_app_path"
        public static let history = "mdv6_history"
        public static let mermaidStyle = "mdv6.mermaid.style"
    }

    /// K-04: inspector width, persisted, clamped to [180, 520].
    public static let inspectorWidthRange: ClosedRange<Double> = 180...520
    /// K-04: bookmarks pane ≥ 120 pt (clamped at use).
    public static let minimumBookmarksHeight: Double = 120
    /// K-04: sidebar width [180, 400] (not persisted, D-10).
    public static let sidebarWidthRange: ClosedRange<Double> = 180...400

    public let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
        themeId = (defaults.object(forKey: Key.themeId) as? String) ?? ThemeCatalog.defaultId
        fontScale = Preferences.readScale(defaults)
        smartTypography = Preferences.readBool(defaults, Key.smartTypography, default: true)
        loadRemoteImages = Preferences.readBool(defaults, Key.loadRemoteImages, default: false)
        sidebarCollapsed = Preferences.readBool(defaults, Key.sidebarCollapsed, default: false)
        inspectorVisible = Preferences.readBool(defaults, Key.inspectorVisible, default: false)
        inspectorWidth = Preferences.clampWidth(Preferences.readDouble(defaults, Key.inspectorWidth) ?? 240)
        bookmarksExpanded = Preferences.readBool(defaults, Key.bookmarksExpanded, default: false)
        bookmarksHeight = Preferences.clampHeight(Preferences.readDouble(defaults, Key.bookmarksHeight) ?? 240)
        editorAppPath = (defaults.object(forKey: Key.editorAppPath) as? String) ?? ""
        let style = (defaults.object(forKey: Key.mermaidStyle) as? String) ?? "document"
        mermaidStyle = Preferences.mermaidStyles.contains(style) ? style : "document"
    }

    /// Theme id or `system`; an unknown value is kept as stored and resolves to `high-contrast` at use (C-04, ThemeCatalog).
    @Published public var themeId: String { didSet { defaults.set(themeId, forKey: Key.themeId) } }
    /// R-30, clamped on read.
    @Published public var fontScale: Double { didSet { defaults.set(fontScale, forKey: Key.fontScale) } }
    @Published public var smartTypography: Bool { didSet { defaults.set(smartTypography, forKey: Key.smartTypography) } }
    @Published public var loadRemoteImages: Bool { didSet { defaults.set(loadRemoteImages, forKey: Key.loadRemoteImages) } }
    @Published public var sidebarCollapsed: Bool { didSet { defaults.set(sidebarCollapsed, forKey: Key.sidebarCollapsed) } }
    @Published public var inspectorVisible: Bool { didSet { defaults.set(inspectorVisible, forKey: Key.inspectorVisible) } }
    @Published public var inspectorWidth: Double { didSet { defaults.set(Preferences.clampWidth(inspectorWidth), forKey: Key.inspectorWidth) } }
    @Published public var bookmarksExpanded: Bool { didSet { defaults.set(bookmarksExpanded, forKey: Key.bookmarksExpanded) } }
    @Published public var bookmarksHeight: Double { didSet { defaults.set(Preferences.clampHeight(bookmarksHeight), forKey: Key.bookmarksHeight) } }
    @Published public var editorAppPath: String { didSet { defaults.set(editorAppPath, forKey: Key.editorAppPath) } }
    /// R-09: `document`, `light`, `dark`, `tokyoNight`, `catppuccin`; unknown reads as `document`.
    @Published public var mermaidStyle: String { didSet { defaults.set(mermaidStyle, forKey: Key.mermaidStyle) } }

    public static let mermaidStyles = ["document", "light", "dark", "tokyoNight", "catppuccin"]

    /// C-15 (read-only here; `HistoryManager` owns writes).
    public var history: [HistoryEntry] { HistoryCodec.decode(defaults.data(forKey: Key.history)) }

    // MARK: typed reads with fallbacks (C-04)

    static func readBool(_ d: UserDefaults, _ key: String, default value: Bool) -> Bool {
        guard let n = d.object(forKey: key) as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { return value }
        return n.boolValue
    }

    static func readDouble(_ d: UserDefaults, _ key: String) -> Double? {
        guard let n = d.object(forKey: key) as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
        return n.doubleValue
    }

    static func readScale(_ d: UserDefaults) -> Double {
        guard let v = readDouble(d, Key.fontScale) else { return ZoomStep.default }
        return ZoomStep.clampOnRead(v)
    }

    static func clampWidth(_ w: Double) -> Double { w.isFinite ? min(max(w, inspectorWidthRange.lowerBound), inspectorWidthRange.upperBound) : 240 }
    static func clampHeight(_ h: Double) -> Double { h.isFinite ? max(h, minimumBookmarksHeight) : 240 }
}
