import XCTest
import SwiftUI
import AppKit
@testable import mdv6Core

/// C-18 / K-16 / I-015 as rules (the rule half of T-44, the scripted half of T-48, T-47's title rule, E-30, E-18).
@MainActor
final class ChromeModelTests: XCTestCase {

    /// T-48, C-18.9: the bookmark context menu is exactly *Go to Bookmark · Reveal in Finder · | · Move Up · Move Down ·
    /// Move to Top · Move to Bottom · | · Remove Bookmark*; the moves up are disabled on the first row, the moves down on the
    /// last, *Reveal* when the file is missing; the placeholder menu is exactly *Clear Placeholder*. R-27, R-28.
    func testBookmarkMenuOrderAndEnablement() {
        let items = ChromeRules.bookmarkMenu(rowIndex: 2, count: 5, fileExists: true)
        XCTAssertEqual(items.map(\.item.rawValue), ["Go to Bookmark", "Reveal in Finder", "Move Up", "Move Down", "Move to Top", "Move to Bottom", "Remove Bookmark"])
        XCTAssertTrue(items.allSatisfy(\.enabled))
        XCTAssertEqual(ChromeRules.bookmarkMenuSeparatorsAfter, [.revealInFinder, .moveToBottom])
        XCTAssertEqual(items.count + ChromeRules.bookmarkMenuSeparatorsAfter.count, 9)
        let first = ChromeRules.bookmarkMenu(rowIndex: 0, count: 5, fileExists: true)
        XCTAssertEqual(first.filter { !$0.enabled }.map(\.item), [.moveUp, .moveToTop])
        let last = ChromeRules.bookmarkMenu(rowIndex: 4, count: 5, fileExists: true)
        XCTAssertEqual(last.filter { !$0.enabled }.map(\.item), [.moveDown, .moveToBottom])
        let missing = ChromeRules.bookmarkMenu(rowIndex: 2, count: 5, fileExists: false)
        XCTAssertEqual(missing.filter { !$0.enabled }.map(\.item), [.revealInFinder])
        XCTAssertEqual(ChromeRules.placeholderMenu, ["Clear Placeholder"])
    }

    /// T-48, R-27: the moves change the persisted order and the ⌘1…⌘5 slots follow (third → *Move Up* → second and ⌘2;
    /// *Move to Bottom* → last and ⌘5 opens what was fourth); a fresh manager on the same store reads the same order.
    func testReorderFollowsSlots() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-chrome-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let db = Database(url: dir.appendingPathComponent("mdv6.db"))
        let bm = BookmarksManager(database: db, fileSystem: .fake(files: ["/x.md": "x"], mtime: 1))
        let doc = ParsedDocument(raw: "# H\n\np1\n\np2\n\np3\n\np4\n\np5")
        for i in 1...5 { bm.add(path: "/x.md", document: doc, index: i) }
        let ids = bm.bookmarks.map(\.id)
        bm.moveUp(id: ids[2])
        XCTAssertEqual(bm.bookmarks[1].id, ids[2]); XCTAssertEqual(bm.slot(2)?.id, ids[2])
        bm.moveToBottom(id: ids[2])
        XCTAssertEqual(bm.bookmarks.last?.id, ids[2]); XCTAssertEqual(bm.slot(5)?.id, ids[2]); XCTAssertEqual(bm.slot(4)?.id, ids[4])
        bm.remove(id: ids[0])
        XCTAssertEqual(BookmarksManager(database: Database(url: dir.appendingPathComponent("mdv6.db"))).bookmarks.map(\.id), bm.bookmarks.map(\.id))
    }

    /// K-16, C-18.3–C-18.9: the chrome metrics are the spec's numbers.
    func testMetricsTable() {
        XCTAssertEqual(ChromeMetrics.headerFontSize, 11); XCTAssertEqual(ChromeMetrics.headerTracking, 0.6)
        XCTAssertEqual(ChromeMetrics.headerPaddingHorizontal, 14); XCTAssertEqual(ChromeMetrics.headerPaddingTop, 14); XCTAssertEqual(ChromeMetrics.headerPaddingBottom, 6)
        XCTAssertEqual(ChromeMetrics.bookmarksHeaderHeight, 32); XCTAssertEqual(ChromeMetrics.chevronFontSize, 9); XCTAssertEqual(ChromeMetrics.chevronWidth, 10)
        XCTAssertEqual(ChromeMetrics.countCapsuleFontSize, 10)
        XCTAssertEqual(ChromeMetrics.searchButtonFontSize, 11); XCTAssertEqual(ChromeMetrics.searchButtonHitSize, 18)
        XCTAssertEqual(ChromeMetrics.revealDuration, 0.20); XCTAssertEqual(ChromeMetrics.revealFocusDelay, 0.05)
        XCTAssertEqual(ChromeMetrics.historyGlyphSize, 13); XCTAssertEqual(ChromeMetrics.historyGlyphWidth, 16)
        XCTAssertEqual(ChromeMetrics.historyNameFontSize, 13); XCTAssertEqual(ChromeMetrics.historyPathFontSize, 11); XCTAssertEqual(ChromeMetrics.historyRowVerticalPadding, 2)
        XCTAssertEqual(ChromeMetrics.emptyTrayGlyphSize, 24); XCTAssertEqual(ChromeMetrics.emptyTextFontSize, 12)
        XCTAssertEqual(ChromeMetrics.findButtonSize, 28); XCTAssertEqual(ChromeMetrics.findButtonStroke, 0.5); XCTAssertEqual(ChromeMetrics.findButtonGlyph, 13)
        XCTAssertEqual(ChromeMetrics.stripeWidth, 3)
        XCTAssertEqual(ChromeMetrics.tocFontSize, 12); XCTAssertEqual(ChromeMetrics.tocIndentPerLevel, 14); XCTAssertEqual(ChromeMetrics.tocRowCornerRadius, 4)
        XCTAssertEqual(ChromeMetrics.tocRowPadding.horizontal, 8); XCTAssertEqual(ChromeMetrics.tocRowPadding.vertical, 5); XCTAssertEqual(ChromeMetrics.tocRowMaxLines, 2)
        XCTAssertEqual(ChromeMetrics.bookmarkGlyphSize, 11); XCTAssertEqual(ChromeMetrics.bookmarkTitleFontSize, 13); XCTAssertEqual(ChromeMetrics.bookmarkFileFontSize, 10)
        XCTAssertEqual(ChromeMetrics.badgeCommandFontSize, 9); XCTAssertEqual(ChromeMetrics.badgeDigitFontSize, 10); XCTAssertEqual(ChromeMetrics.badgeCornerRadius, 4)
        XCTAssertEqual(ChromeMetrics.bookmarkRowPadding.horizontal, 8); XCTAssertEqual(ChromeMetrics.bookmarkRowPadding.vertical, 5); XCTAssertEqual(ChromeMetrics.bookmarkRowCornerRadius, 5)
        XCTAssertEqual(ChromeMetrics.placeholderGlyphSize, 12); XCTAssertEqual(ChromeMetrics.placeholderDividerInset.horizontal, 8); XCTAssertEqual(ChromeMetrics.placeholderDividerInset.vertical, 2)
        XCTAssertEqual(ChromeMetrics.handleWidth, 8); XCTAssertEqual(ChromeMetrics.dividerWidth, 1); XCTAssertEqual(ChromeMetrics.collapseChevronSize, 11)
        XCTAssertEqual(ChromeOpacity.hover, 0.06); XCTAssertEqual(ChromeOpacity.tocHover, 0.08); XCTAssertEqual(ChromeOpacity.dropTarget, 0.18)
        XCTAssertEqual(ChromeOpacity.badge, 0.85); XCTAssertEqual(ChromeOpacity.bookmarkGlyph, 0.70); XCTAssertEqual(ChromeOpacity.placeholderTint, 0.08)
        XCTAssertEqual(ChromeOpacity.placeholderStroke, 0.25); XCTAssertEqual(ChromeOpacity.missing, 0.60); XCTAssertEqual(ChromeOpacity.countCapsule, 0.06)
    }

    /// I-015, C-18.9, F-109 (T-44 rule half): under every theme a *current* row is the accent fill with page-background
    /// text and an inverted badge; hovered rows use the text colour at 6 %; missing rows sit at 60 %; the placeholder at
    /// rest carries the accent tint and stroke — the structure never varies by theme.
    func testRowStyleOverAllThemes() {
        for t in MDVTheme.all {
            let current = ChromeRules.rowStyle(current: true, hovered: true, missing: true, dropTarget: false, placeholder: false, theme: t)
            XCTAssertEqual(current.fill, t.accent, t.id); XCTAssertEqual(current.text, t.background, t.id); XCTAssertEqual(current.glyph, t.background, t.id)
            XCTAssertEqual(current.badgeForeground, t.accent, t.id); XCTAssertEqual(current.badgeBackground, t.background, t.id); XCTAssertEqual(current.opacity, 1, t.id)
            let hovered = ChromeRules.rowStyle(current: false, hovered: true, missing: false, dropTarget: false, placeholder: false, theme: t)
            XCTAssertEqual(hovered.fill, t.text, t.id); XCTAssertEqual(hovered.fillOpacity, 0.06, t.id); XCTAssertEqual(hovered.text, t.text, t.id)
            XCTAssertEqual(hovered.badgeForeground, t.background, t.id); XCTAssertEqual(hovered.badgeBackground, t.accent, t.id); XCTAssertEqual(hovered.badgeBackgroundOpacity, 0.85, t.id)
            let missing = ChromeRules.rowStyle(current: false, hovered: false, missing: true, dropTarget: false, placeholder: false, theme: t)
            XCTAssertEqual(missing.opacity, 0.60, t.id); XCTAssertEqual(missing.glyph, Color.orange, t.id); XCTAssertNil(missing.fill, t.id)
            let drop = ChromeRules.rowStyle(current: false, hovered: true, missing: false, dropTarget: true, placeholder: false, theme: t)
            XCTAssertEqual(drop.fill, t.accent, t.id); XCTAssertEqual(drop.fillOpacity, 0.18, t.id)
            let placeholder = ChromeRules.rowStyle(current: false, hovered: false, missing: false, dropTarget: false, placeholder: true, theme: t)
            XCTAssertEqual(placeholder.fill, t.accent, t.id); XCTAssertEqual(placeholder.fillOpacity, 0.08, t.id); XCTAssertEqual(placeholder.stroke, t.accent.opacity(0.25), t.id)
            XCTAssertEqual(placeholder.glyph, t.accent.opacity(1), t.id)
            XCTAssertEqual(ChromeRules.colorScheme(for: t), t.isDark ? .dark : .light, t.id)
        }
    }

    /// C-18.1, T-47: the title is the file name or the product name; the colour scheme follows `isDark`.
    func testWindowTitleAndScheme() {
        XCTAssertEqual(ChromeRules.windowTitle(fileName: "syntax.md"), "syntax.md")
        XCTAssertEqual(ChromeRules.windowTitle(fileName: nil), "mdv6")
        XCTAssertEqual(ChromeRules.colorScheme(for: .charcoal), .dark); XCTAssertEqual(ChromeRules.colorScheme(for: .sevilla), .light)
    }

    /// C-18.5: the path shows the home directory as `~`; C-18.8: rows indent 14 pt per level, level 1 semibold in the text
    /// colour, deeper levels regular in the secondary colour; C-18.9 badges `⌘1`…`⌘5` only.
    func testRowRules() {
        XCTAssertEqual(ChromeRules.historyPathDisplay("/Users/me/docs/a.md", home: "/Users/me"), "~/docs/a.md")
        XCTAssertEqual(ChromeRules.historyPathDisplay("/private/tmp/x.md", home: "/Users/me"), "/private/tmp/x.md")
        XCTAssertEqual(ChromeRules.historyPathDisplay("/Users/me", home: "/Users/me"), "~")
        XCTAssertEqual(ChromeRules.tocIndent(level: 1), 0); XCTAssertEqual(ChromeRules.tocIndent(level: 3), 28)
        XCTAssertEqual(ChromeRules.tocFontWeight(level: 1), .semibold); XCTAssertEqual(ChromeRules.tocFontWeight(level: 2), .regular)
        XCTAssertEqual(ChromeRules.tocTextColor(level: 1, theme: .sevilla), MDVTheme.sevilla.text)
        XCTAssertEqual(ChromeRules.tocTextColor(level: 3, theme: .sevilla), MDVTheme.sevilla.secondaryText)
        XCTAssertEqual(ChromeRules.badge(slot: 1), "⌘1"); XCTAssertEqual(ChromeRules.badge(slot: 5), "⌘5"); XCTAssertNil(ChromeRules.badge(slot: 6)); XCTAssertNil(ChromeRules.badge(slot: nil))
    }

    /// C-18.2, §5.1: the toolbar is exactly five icon buttons in order with tooltips naming the shortcut.
    func testToolbarSpec() {
        let items = ChromeRules.toolbarItems()
        XCTAssertEqual(items.map(\.systemImage), ["plus", "pencil", "paintpalette", "bookmark", "sidebar.right"])
        XCTAssertEqual(items.map(\.shortcut), ["⌘O", "⌘E", "", "⌘D", "⌥⌘0"])
        XCTAssertTrue(items[0].tooltip.contains("⌘O")); XCTAssertTrue(items[4].tooltip.contains("⌥⌘0"))
    }

    /// R-24, E-18, C-18.4: the sidebar has focus when the first responder is a view inside the sidebar view.
    func testSidebarFocusRule() {
        let sidebar = NSView(), inner = NSView(), field = NSTextField(), other = NSTextField()
        sidebar.addSubview(inner); inner.addSubview(field)
        XCTAssertTrue(ChromeRules.sidebarHasFocus(firstResponder: field, sidebarView: sidebar))
        XCTAssertTrue(ChromeRules.sidebarHasFocus(firstResponder: sidebar, sidebarView: sidebar))
        XCTAssertFalse(ChromeRules.sidebarHasFocus(firstResponder: other, sidebarView: sidebar))
        XCTAssertFalse(ChromeRules.sidebarHasFocus(firstResponder: nil, sidebarView: sidebar))
        XCTAssertFalse(ChromeRules.sidebarHasFocus(firstResponder: field, sidebarView: nil))
    }

    /// K-04, R-20, R-21, T-31: sidebar 180…400 (not persisted), inspector 180…520, bookmarks pane ≥ 120 with the TOC ≥ 80.
    func testPaneClamps() {
        XCTAssertEqual(ChromeRules.clampSidebarWidth(50), 180); XCTAssertEqual(ChromeRules.clampSidebarWidth(900), 400); XCTAssertEqual(ChromeRules.clampSidebarWidth(250), 250)
        XCTAssertEqual(ChromeRules.clampInspectorWidth(10), 180); XCTAssertEqual(ChromeRules.clampInspectorWidth(999), 520)
        XCTAssertEqual(ChromeRules.clampBookmarksHeight(50, inspectorHeight: 600), 120)
        XCTAssertEqual(ChromeRules.clampBookmarksHeight(590, inspectorHeight: 600), 520)
        XCTAssertEqual(ChromeRules.clampBookmarksHeight(300, inspectorHeight: 600), 300)
    }

    /// C-18.1, F-003 (regression): applying the theme's colour scheme to a window is idempotent — a second application
    /// with the same scheme schedules nothing, so the view hierarchy cannot re-render forever under a dark theme.
    func testAppearanceAssignmentIsIdempotent() {
        let w = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        XCTAssertTrue(WindowAccessor.applyAppearance(w, isDark: true))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(w.appearance?.name, .darkAqua)
        XCTAssertFalse(WindowAccessor.applyAppearance(w, isDark: true))
        XCTAssertFalse(WindowAccessor.applyAppearance(w, isDark: true))
        XCTAssertTrue(WindowAccessor.applyAppearance(w, isDark: false))
    }

    /// E-30, R-40, T-28: windows are never restorable and the app opts out of state restoration, so quitting with two windows
    /// open (⌘⇧O) and launching again yields exactly one window that follows R-40 — the history head — with the second
    /// window's document reachable through history.
    func testOneWindowAfterQuitWithTwoWindows() {
        let w1 = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let w2 = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        WindowAccessor.configure(w1); WindowAccessor.configure(w2)
        XCTAssertFalse(w1.isRestorable); XCTAssertFalse(w2.isRestorable)
        XCTAssertEqual(w1.tabbingMode, .disallowed)
        let delegate = mdv6AppDelegate()
        XCTAssertFalse(delegate.applicationSupportsSecureRestorableState(NSApplication.shared))
        delegate.applicationWillFinishLaunching(Notification(name: NSApplication.willFinishLaunchingNotification))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "NSQuitAlwaysKeepsWindows"))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "ApplePersistenceIgnoreState"))
        // two windows, two documents, then "quit" (both closed) and a fresh launch
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-e30-\(UUID().uuidString)")
        let suite = "mdv6.e30.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: dir) }
        let fs = FileSystem.fake(files: ["/a.md": "# A", "/b.md": "# B"], mtime: 1)
        let model = AppModel.bootstrap(supportDir: dir, defaultsSuite: suite, fileSystem: fs)
        let s1 = DocumentSession(model: model, watcherFactory: { _, _ in NoWatch() }, pasteboard: { _ in }, systemOpener: { _ in }, beeper: {})
        let s2 = DocumentSession(model: model, watcherFactory: { _, _ in NoWatch() }, pasteboard: { _ in }, systemOpener: { _ in }, beeper: {})
        model.register(session: s1, window: w1); model.register(session: s2, window: w2)
        s1.open(urls: [URL(fileURLWithPath: "/a.md")]); s2.open(urls: [URL(fileURLWithPath: "/b.md")])
        s1.windowWillClose(); s2.windowWillClose(); model.unregister(window: w1); model.unregister(window: w2)
        let relaunched = AppModel.bootstrap(supportDir: dir, defaultsSuite: suite, fileSystem: fs)
        let only = DocumentSession(model: relaunched, watcherFactory: { _, _ in NoWatch() }, pasteboard: { _ in }, systemOpener: { _ in }, beeper: {})
        relaunched.startup(arguments: [], session: only)
        XCTAssertEqual(only.currentEntry?.path, "/b.md", "the head, per R-40")
        XCTAssertEqual(relaunched.history.entries.map(\.path), ["/b.md", "/a.md"], "the other window's document is reachable through history")
        XCTAssertTrue(relaunched.keySession === only, "exactly one session after launch")
    }

    /// R-29, C-18.1: *System* follows the application's effective appearance (`SystemAppearance`), not the window's colour
    /// scheme — every window takes its theme's scheme through `.preferredColorScheme` (F-006), so the SwiftUI environment
    /// inside a window cannot be the source of the macOS appearance.
    func testSystemAppearanceReadsTheApplicationNotTheWindow() {
        XCTAssertTrue(SystemAppearance.isDark(NSAppearance(named: .darkAqua)))
        XCTAssertFalse(SystemAppearance.isDark(NSAppearance(named: .aqua)))
        XCTAssertFalse(SystemAppearance.isDark(nil))
        XCTAssertEqual(ChromeRules.colorScheme(for: .twilight), .dark)
        XCTAssertEqual(ChromeRules.colorScheme(for: .sevilla), .light)
        let sys = SystemAppearance(application: NSApplication.shared)
        XCTAssertEqual(sys.isDark, SystemAppearance.isDark(NSApplication.shared.effectiveAppearance))
    }

    final class NoWatch: FileWatching { func cancel() {} }
}
