// ChromeModel — C-18 / K-16: every chrome metric, opacity, state and menu rule as theme-independent data (I-015). The
// only file that draws a pane (`SidebarViews.swift`) reads these; the window (`DocumentRootView.swift`) reads the
// title, colour-scheme and toolbar rules. Colours come only from the `MDVTheme` passed in.
import Foundation
import AppKit
import SwiftUI

/// K-16 / C-18 sizes in points.
public enum ChromeMetrics {
    // C-18.3 section headers
    public static let headerFontSize: CGFloat = 11
    public static let headerTracking: CGFloat = 0.6
    public static let headerPaddingHorizontal: CGFloat = 14
    public static let headerPaddingTop: CGFloat = 14
    public static let headerPaddingBottom: CGFloat = 6
    public static let bookmarksHeaderHeight: CGFloat = 32
    public static let chevronFontSize: CGFloat = 9
    public static let chevronWidth: CGFloat = 10
    public static let countCapsuleFontSize: CGFloat = 10
    public static let countCapsulePadding: (horizontal: CGFloat, vertical: CGFloat) = (5, 1)
    // C-18.4 reveal-on-click search
    public static let searchButtonFontSize: CGFloat = 11
    public static let searchButtonHitSize: CGFloat = 18
    public static let revealDuration: TimeInterval = 0.20
    public static let revealFocusDelay: TimeInterval = 0.05
    public static let searchFieldFontSize: CGFloat = 12        // not pinned by K-16
    public static let snippetFontSize: CGFloat = 11            // not pinned by K-16
    // C-18.5 history rows
    public static let historyGlyphSize: CGFloat = 13
    public static let historyGlyphWidth: CGFloat = 16
    public static let historyNameFontSize: CGFloat = 13
    public static let historyPathFontSize: CGFloat = 11
    public static let historyRowVerticalPadding: CGFloat = 2
    public static let emptyTrayGlyphSize: CGFloat = 24
    public static let emptyTextFontSize: CGFloat = 12
    // C-18.7 article affordances
    public static let findButtonSize: CGFloat = 28
    public static let findButtonStroke: CGFloat = 0.5
    public static let findButtonGlyph: CGFloat = 13
    public static let stripeWidth: CGFloat = 3
    // C-18.8 TOC rows
    public static let tocFontSize: CGFloat = 12
    public static let tocIndentPerLevel: CGFloat = 14
    public static let tocRowPadding: (horizontal: CGFloat, vertical: CGFloat) = (8, 5)
    public static let tocRowCornerRadius: CGFloat = 4
    public static let tocRowMaxLines = 2
    // C-18.9 bookmark rows
    public static let bookmarkGlyphSize: CGFloat = 11
    public static let bookmarkGlyphWidth: CGFloat = 16
    public static let bookmarkTitleFontSize: CGFloat = 13
    public static let bookmarkFileFontSize: CGFloat = 10
    public static let badgeCommandFontSize: CGFloat = 9
    public static let badgeDigitFontSize: CGFloat = 10
    public static let badgeCornerRadius: CGFloat = 4
    public static let badgePadding: (horizontal: CGFloat, vertical: CGFloat) = (5, 1)
    public static let bookmarkRowPadding: (horizontal: CGFloat, vertical: CGFloat) = (8, 5)
    public static let bookmarkRowCornerRadius: CGFloat = 5
    public static let placeholderGlyphSize: CGFloat = 12
    public static let placeholderDividerInset: (horizontal: CGFloat, vertical: CGFloat) = (8, 2)
    public static let placeholderStroke: CGFloat = 0.5
    // C-18.1 panes
    public static let handleWidth: CGFloat = 8
    public static let dividerWidth: CGFloat = 1
    public static let collapseChevronSize: CGFloat = 11
}

/// C-18 opacities of the theme's colours.
public enum ChromeOpacity {
    public static let hover = 0.06                 // history hits, bookmark rows: text.opacity(0.06)
    public static let tocHover = 0.08              // TOC rows: text.opacity(0.08)
    public static let dropTarget = 0.18            // accent.opacity(0.18)
    public static let badge = 0.85                 // accent.opacity(0.85)
    public static let bookmarkGlyph = 0.70         // accent at 70 %
    public static let placeholderTint = 0.08       // accent.opacity(0.08)
    public static let placeholderStroke = 0.25     // accent.opacity(0.25)
    public static let missing = 0.60               // missing-file row at 60 %
    public static let countCapsule = 0.06          // text.opacity(0.06)
}

/// C-18.9: what a bookmark or placeholder row draws in each state.
public struct RowStyle: Equatable {
    public let fill: Color?
    public let fillOpacity: Double
    public let text: Color
    public let glyph: Color
    public let badgeForeground: Color
    public let badgeBackground: Color
    public let badgeBackgroundOpacity: Double
    public let opacity: Double
    public let stroke: Color?
}

public struct ToolbarItemSpec: Equatable {
    public let systemImage: String
    public let tooltip: String
    public let shortcut: String
}

public enum ChromeRules {
    // MARK: C-18.1

    /// The displayed file's last path component, or the product name when the window is `EMPTY`.
    public static func windowTitle(fileName: String?) -> String { fileName ?? "mdv6" }

    /// The window (title bar included) takes the theme's colour scheme so the title stays legible on the strip.
    public static func colorScheme(for theme: MDVTheme) -> ColorScheme { theme.isDark ? .dark : .light }

    // MARK: C-18.2

    /// §5.1 toolbar: five icon-only buttons, trailing, in this order, with `.help` tooltips naming the shortcut.
    public static func toolbarItems() -> [ToolbarItemSpec] {
        [ToolbarItemSpec(systemImage: "plus", tooltip: "Open… (⌘O)", shortcut: "⌘O"),
         ToolbarItemSpec(systemImage: "pencil", tooltip: "Edit in External Editor (⌘E)", shortcut: "⌘E"),
         ToolbarItemSpec(systemImage: "paintpalette", tooltip: "Theme", shortcut: ""),
         ToolbarItemSpec(systemImage: "bookmark", tooltip: "Bookmark Current Spot (⌘D)", shortcut: "⌘D"),
         ToolbarItemSpec(systemImage: "sidebar.right", tooltip: "Toggle Inspector (⌥⌘0)", shortcut: "⌥⌘0")]
    }

    // MARK: C-18.5

    /// The path with the home directory abbreviated to `~` (head truncation is the view's `.truncationMode(.head)`).
    public static func historyPathDisplay(_ path: String, home: String = NSHomeDirectory()) -> String {
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    // MARK: C-18.8

    public static func tocIndent(level: Int) -> CGFloat { ChromeMetrics.tocIndentPerLevel * CGFloat(max(level - 1, 0)) }
    public static func tocFontWeight(level: Int) -> Font.Weight { level == 1 ? .semibold : .regular }
    public static func tocTextColor(level: Int, theme: MDVTheme) -> Color { level == 1 ? theme.text : theme.secondaryText }

    // MARK: C-18.9

    public enum BookmarkMenuItem: String, CaseIterable, Equatable {
        case goTo = "Go to Bookmark"
        case revealInFinder = "Reveal in Finder"
        case moveUp = "Move Up"
        case moveDown = "Move Down"
        case moveToTop = "Move to Top"
        case moveToBottom = "Move to Bottom"
        case remove = "Remove Bookmark"
    }

    /// C-18.9: the nine-entry menu (seven items and two separators, after `revealInFinder` and before `remove`) with
    /// its enablement: the moves up are disabled on the first row, the moves down on the last, *Reveal* when the file is missing.
    public static func bookmarkMenu(rowIndex: Int, count: Int, fileExists: Bool) -> [(item: BookmarkMenuItem, enabled: Bool)] {
        let first = rowIndex == 0, last = rowIndex == count - 1
        return [(.goTo, true), (.revealInFinder, fileExists), (.moveUp, !first), (.moveDown, !last), (.moveToTop, !first), (.moveToBottom, !last), (.remove, true)]
    }

    /// Where the two separators sit (after these items).
    public static let bookmarkMenuSeparatorsAfter: [BookmarkMenuItem] = [.revealInFinder, .moveToBottom]

    /// C-18.9: right-clicking the placeholder row shows exactly one item.
    public static let placeholderMenu: [String] = ["Clear Placeholder"]

    /// The hotkey badge for slot 1…5, nil otherwise; the placeholder's is `⌘0`.
    public static func badge(slot: Int?) -> String? {
        guard let slot, slot >= 1, slot <= BookmarksManager.slotCount else { return nil }
        return "⌘\(slot)"
    }

    /// C-18.9 states: current → accent fill with page-background text/glyph and an inverted badge; drop target →
    /// accent 0.18; hovered → text 0.06; missing → 60 % opacity unless current; the placeholder at rest is tinted
    /// accent 0.08 with a 0.5 pt accent 0.25 stroke.
    public static func rowStyle(current: Bool, hovered: Bool, missing: Bool, dropTarget: Bool, placeholder: Bool, theme: MDVTheme) -> RowStyle {
        if current {
            return RowStyle(fill: theme.accent, fillOpacity: 1, text: theme.background, glyph: theme.background,
                            badgeForeground: theme.accent, badgeBackground: theme.background, badgeBackgroundOpacity: 1, opacity: 1, stroke: nil)
        }
        let glyph = missing ? Color.orange : theme.accent.opacity(placeholder ? 1 : ChromeOpacity.bookmarkGlyph)
        var fill: Color? = nil
        var fillOpacity = 1.0
        var stroke: Color? = nil
        if dropTarget { fill = theme.accent; fillOpacity = ChromeOpacity.dropTarget }
        else if hovered { fill = theme.text; fillOpacity = ChromeOpacity.hover }
        else if placeholder { fill = theme.accent; fillOpacity = ChromeOpacity.placeholderTint; stroke = theme.accent.opacity(ChromeOpacity.placeholderStroke) }
        return RowStyle(fill: fill, fillOpacity: fillOpacity, text: theme.text, glyph: glyph,
                        badgeForeground: theme.background, badgeBackground: theme.accent, badgeBackgroundOpacity: ChromeOpacity.badge,
                        opacity: missing ? ChromeOpacity.missing : 1, stroke: stroke)
    }

    // MARK: R-24 / E-18 / C-18.4

    /// *The sidebar has focus* when the window's first responder is a view inside the history sidebar.
    public static func sidebarHasFocus(firstResponder: NSResponder?, sidebarView: NSView?) -> Bool {
        guard let sidebarView, var view = firstResponder as? NSView else { return false }
        while true {
            if view === sidebarView { return true }
            guard let superview = view.superview else { return false }
            view = superview
        }
    }

    // MARK: K-04

    public static func clampSidebarWidth(_ w: CGFloat) -> CGFloat { min(max(w, 180), 400) }
    public static func clampInspectorWidth(_ w: CGFloat) -> CGFloat { min(max(w, 180), 520) }
    /// K-04: bookmarks pane ≥ 120 pt with the TOC keeping ≥ 80 pt of the inspector's height.
    public static func clampBookmarksHeight(_ h: CGFloat, inspectorHeight: CGFloat) -> CGFloat {
        let upper = max(120, inspectorHeight - 80)
        return min(max(h, 120), upper)
    }
}
