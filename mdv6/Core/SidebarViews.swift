// SidebarViews — the only file that draws a pane: the history sidebar (C-18.3, C-18.4, C-18.5, C-18.6) and the
// inspector (C-18.3, C-18.4, C-18.8, C-18.9). Every size comes from `ChromeMetrics`, every opacity from `ChromeOpacity`,
// every state and menu from `ChromeRules`; only the colours come from the theme (I-015). Reference: `reference/*.png`.
import SwiftUI
import AppKit

// MARK: - C-18.3 section header

struct SectionHeader: View {
    let title: String
    let theme: MDVTheme
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: ChromeMetrics.headerFontSize, weight: .semibold))
                .tracking(ChromeMetrics.headerTracking)
                .foregroundStyle(theme.tertiaryText)
            Spacer(minLength: 0)
            if let trailing { trailing }
        }
        .padding(.horizontal, ChromeMetrics.headerPaddingHorizontal)
        .padding(.top, ChromeMetrics.headerPaddingTop)
        .padding(.bottom, ChromeMetrics.headerPaddingBottom)
    }
}

// MARK: - C-18.3 + C-18.4 header with reveal-on-click search

/// A section header whose trailing `magnifyingglass` button is replaced by a search field beneath the header
/// (0.20 s ease-out, focused after 0.05 s); Esc, or clearing and blurring, hides it again (C-18.4).
struct SearchableHeader: View {
    let title: String
    let theme: MDVTheme
    let tooltip: String
    let prompt: String
    @Binding var text: String
    @Binding var revealed: Bool
    var focusRequest: Int = 0
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: title, theme: theme, trailing: revealed ? nil : AnyView(button))
            if revealed {
                TextField(prompt, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: ChromeMetrics.searchFieldFontSize))
                    .focused($focused)
                    .padding(.horizontal, ChromeMetrics.headerPaddingHorizontal - 4)
                    .padding(.bottom, 6)
                    .onExitCommand { hide() }
                    .onChange(of: focused) { isFocused in if !isFocused && text.isEmpty { hide() } }
                    .transition(.opacity)
            }
        }
        .onChange(of: focusRequest) { _ in reveal() }
    }

    private var button: some View {
        Button { reveal() } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: ChromeMetrics.searchButtonFontSize, weight: .semibold))
                .foregroundStyle(theme.tertiaryText)
                .frame(width: ChromeMetrics.searchButtonHitSize, height: ChromeMetrics.searchButtonHitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func reveal() {
        withAnimation(.easeOut(duration: ChromeMetrics.revealDuration)) { revealed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + ChromeMetrics.revealFocusDelay) { focused = true }
    }

    private func hide() {
        text = ""
        withAnimation(.easeOut(duration: ChromeMetrics.revealDuration)) { revealed = false }
    }
}

// MARK: - History sidebar (C-18.5, C-18.6)

/// A view whose `NSView` ancestry defines "the sidebar has focus" (R-24, E-18).
struct SidebarMarker: NSViewRepresentable {
    let onView: (NSView) -> Void
    func makeNSView(context: Context) -> NSView { let v = NSView(); DispatchQueue.main.async { onView(v) }; return v }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

public struct HistorySidebar: View {
    @ObservedObject var session: DocumentSession
    @ObservedObject var history: HistoryManager
    let theme: MDVTheme
    @Binding var searchText: String
    @Binding var searchRevealed: Bool
    let searchFocusRequest: Int
    let onSidebarView: (NSView) -> Void

    @State private var selection: UUID? = nil
    @State private var hoveredHit: String? = nil

    public init(session: DocumentSession, history: HistoryManager, theme: MDVTheme, searchText: Binding<String>, searchRevealed: Binding<Bool>,
                searchFocusRequest: Int, onSidebarView: @escaping (NSView) -> Void) {
        self.session = session; self.history = history; self.theme = theme; _searchText = searchText; _searchRevealed = searchRevealed
        self.searchFocusRequest = searchFocusRequest; self.onSidebarView = onSidebarView
    }

    public var body: some View {
        VStack(spacing: 0) {
            SearchableHeader(title: "History", theme: theme, tooltip: "Search history", prompt: "Search history",
                             text: $searchText, revealed: $searchRevealed, focusRequest: searchFocusRequest)
            if !searchText.isEmpty {
                hits
            } else if history.entries.isEmpty {
                emptyState
            } else {
                rows
            }
        }
        .background(SidebarMarker(onView: onSidebarView))
        .background(theme.background)
        .onChange(of: session.currentEntry?.id) { id in selection = id }
        .onAppear { selection = session.currentEntry?.id }
    }

    /// C-18.5: `List(selection:)` with the `.sidebar` style, so the displayed row carries the system selection fill.
    private var rows: some View {
        List(selection: $selection) {
            ForEach(history.entries) { entry in
                HistoryRow(entry: entry, theme: theme)
                    .tag(entry.id)
                    .listRowInsets(EdgeInsets(top: ChromeMetrics.historyRowVerticalPadding, leading: 8, bottom: ChromeMetrics.historyRowVerticalPadding, trailing: 8))
                    .swipeActions(edge: .trailing) { Button(role: .destructive) { session.deleteHistoryRow(entry) } label: { Label("Delete", systemImage: "trash") } }
                    .contextMenu { Button("Remove from History") { session.deleteHistoryRow(entry) } }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .onChange(of: selection) { id in
            guard let id, id != session.currentEntry?.id, let entry = history.entries.first(where: { $0.id == id }) else { return }
            session.selectHistoryRow(entry)
        }
    }

    /// C-18.5: a centred `tray` glyph over *No files yet*.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray").font(.system(size: ChromeMetrics.emptyTrayGlyphSize, weight: .light)).foregroundStyle(theme.tertiaryText)
            Text("No files yet").font(.system(size: ChromeMetrics.emptyTextFontSize)).foregroundStyle(theme.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// C-18.6: hit rows with the C-03 snippet; the displayed file's row is filled with the accent.
    private var hits: some View {
        let results = session.model.database.search(searchText)
        return ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(results, id: \.path) { hit in
                    SearchHitRow(hit: hit, theme: theme, isCurrent: hit.path == session.currentPath, isHovered: hoveredHit == hit.path)
                        .onHover { hoveredHit = $0 ? hit.path : (hoveredHit == hit.path ? nil : hoveredHit) }
                        .onTapGesture { session.openHit(path: hit.path) }
                }
                if results.isEmpty {
                    Text("No results").font(.system(size: ChromeMetrics.searchFieldFontSize)).foregroundStyle(theme.secondaryText).padding(.top, 12)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

/// C-18.5: `doc.text` glyph · file name (13 pt, middle-truncated) over the `~`-abbreviated, head-truncated path (11 pt).
struct HistoryRow: View {
    let entry: HistoryEntry
    let theme: MDVTheme

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: ChromeMetrics.historyGlyphSize))
                .foregroundStyle(theme.secondaryText)
                .frame(width: ChromeMetrics.historyGlyphWidth)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.filename).font(.system(size: ChromeMetrics.historyNameFontSize)).foregroundStyle(theme.text).lineLimit(1).truncationMode(.middle)
                Text(ChromeRules.historyPathDisplay(entry.path)).font(.system(size: ChromeMetrics.historyPathFontSize)).foregroundStyle(theme.secondaryText).lineLimit(1).truncationMode(.head)
            }
        }
        .padding(.vertical, ChromeMetrics.historyRowVerticalPadding)
    }
}

/// C-18.6: name and path like a history row plus the snippet; U+0002/U+0003 bracket the highlighted terms.
struct SearchHitRow: View {
    let hit: Database.SearchHit
    let theme: MDVTheme
    let isCurrent: Bool
    let isHovered: Bool

    var body: some View {
        let fg = isCurrent ? theme.background : theme.text
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text").font(.system(size: ChromeMetrics.historyGlyphSize)).frame(width: ChromeMetrics.historyGlyphWidth).foregroundStyle(isCurrent ? theme.background : theme.secondaryText)
                Text(hit.filename).font(.system(size: ChromeMetrics.historyNameFontSize)).lineLimit(1).truncationMode(.middle)
            }
            Text(ChromeRules.historyPathDisplay(hit.path)).font(.system(size: ChromeMetrics.historyPathFontSize)).lineLimit(1).truncationMode(.head).foregroundStyle(isCurrent ? theme.background.opacity(0.85) : theme.secondaryText)
            Text(SearchHitRow.snippetText(hit.snippet, highlight: isCurrent ? theme.background : theme.accent))
                .font(.system(size: ChromeMetrics.snippetFontSize)).lineLimit(2).foregroundStyle(isCurrent ? theme.background.opacity(0.9) : theme.secondaryText)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 5).fill(isCurrent ? theme.accent : (isHovered ? theme.text.opacity(ChromeOpacity.hover) : Color.clear)))
        .contentShape(Rectangle())
    }

    /// C-03: char(2)…char(3) → bold in the highlight colour.
    static func snippetText(_ s: String, highlight: Color) -> AttributedString {
        var out = AttributedString()
        var inside = false
        var run = ""
        func flush() {
            var a = AttributedString(run)
            if inside { a.foregroundColor = highlight; a.font = .system(size: ChromeMetrics.snippetFontSize, weight: .semibold) }
            out += a; run = ""
        }
        for ch in s {
            if ch == "\u{2}" { flush(); inside = true } else if ch == "\u{3}" { flush(); inside = false } else { run.append(ch) }
        }
        flush()
        return out
    }
}

// MARK: - Inspector (C-18.8, C-18.9)

public struct InspectorView: View {
    @ObservedObject var session: DocumentSession
    @ObservedObject var bookmarks: BookmarksManager
    @ObservedObject var placeholderStore: PlaceholderStore
    @ObservedObject var preferences: Preferences
    let theme: MDVTheme

    @State private var filter = ""
    @State private var filterRevealed = false
    @State private var hoveredTOC: Int? = nil
    @State private var hoveredBookmark: Int64? = nil
    @State private var hoveredPlaceholder = false
    @State private var dragStartHeight: CGFloat? = nil

    public init(session: DocumentSession, bookmarks: BookmarksManager, placeholderStore: PlaceholderStore, preferences: Preferences, theme: MDVTheme) {
        self.session = session; self.bookmarks = bookmarks; self.placeholderStore = placeholderStore; self.preferences = preferences; self.theme = theme
    }

    public var body: some View {
        GeometryReader { geo in
            let paneHeight = ChromeRules.clampBookmarksHeight(CGFloat(preferences.bookmarksHeight), inspectorHeight: geo.size.height)
            VStack(spacing: 0) {
                tocPane
                if preferences.bookmarksExpanded {
                    bookmarksDragHandle(paneHeight: paneHeight, inspectorHeight: geo.size.height)
                }
                bookmarksHeader
                if preferences.bookmarksExpanded {
                    bookmarksPane.frame(height: paneHeight - ChromeMetrics.bookmarksHeaderHeight)
                }
            }
        }
        .background(theme.background)
    }

    // MARK: TOC (C-18.8)

    private var tocPane: some View {
        VStack(spacing: 0) {
            SearchableHeader(title: "On this page", theme: theme, tooltip: "Filter headings", prompt: "Filter headings", text: $filter, revealed: $filterRevealed)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filteredHeadings, id: \.blockIndex) { h in
                        TOCRow(heading: h, theme: theme, selected: session.tocSelectedBlock == h.blockIndex, hovered: hoveredTOC == h.blockIndex)
                            .onHover { hoveredTOC = $0 ? h.blockIndex : (hoveredTOC == h.blockIndex ? nil : hoveredTOC) }
                            .onTapGesture { session.selectTOC(blockIndex: h.blockIndex) }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private var filteredHeadings: [TOCHeading] {
        let all = session.document?.tocHeadings ?? []
        guard !filter.isEmpty else { return all }
        return all.filter { $0.text.localizedCaseInsensitiveContains(filter) }
    }

    // MARK: bookmarks header (C-18.3)

    /// A 32 pt row that is itself the collapse toggle, with the chevron leading the label and a count capsule.
    private var bookmarksHeader: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { preferences.bookmarksExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: preferences.bookmarksExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: ChromeMetrics.chevronFontSize, weight: .semibold))
                    .frame(width: ChromeMetrics.chevronWidth)
                    .foregroundStyle(theme.tertiaryText)
                Text("BOOKMARKS")
                    .font(.system(size: ChromeMetrics.headerFontSize, weight: .semibold))
                    .tracking(ChromeMetrics.headerTracking)
                    .foregroundStyle(theme.tertiaryText)
                Spacer()
                if !bookmarks.bookmarks.isEmpty {
                    Text("\(bookmarks.bookmarks.count)")
                        .font(.system(size: ChromeMetrics.countCapsuleFontSize, weight: .medium).monospacedDigit())
                        .foregroundStyle(theme.tertiaryText)
                        .padding(.horizontal, ChromeMetrics.countCapsulePadding.horizontal).padding(.vertical, ChromeMetrics.countCapsulePadding.vertical)
                        .background(Capsule().fill(theme.text.opacity(ChromeOpacity.countCapsule)))
                }
            }
            .padding(.horizontal, ChromeMetrics.headerPaddingHorizontal)
            .frame(height: ChromeMetrics.bookmarksHeaderHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// R-21: the pane height is draggable (K-04 clamps).
    private func bookmarksDragHandle(paneHeight: CGFloat, inspectorHeight: CGFloat) -> some View {
        Rectangle().fill(theme.border).frame(height: ChromeMetrics.dividerWidth)
            .frame(height: ChromeMetrics.handleWidth).contentShape(Rectangle())
            .onHover { if $0 { NSCursor.resizeUpDown.push() } else { NSCursor.pop() } }
            .gesture(DragGesture(minimumDistance: 1).onChanged { v in
                if dragStartHeight == nil { dragStartHeight = paneHeight }
                preferences.bookmarksHeight = ChromeRules.clampBookmarksHeight(dragStartHeight! - v.translation.height, inspectorHeight: inspectorHeight)
            }.onEnded { _ in dragStartHeight = nil })
    }

    // MARK: bookmark rows (C-18.9)

    private var bookmarksPane: some View {
        List {
            if let p = placeholderStore.placeholder {
                PlaceholderRow(placeholder: p, theme: theme, current: session.placeholderIsCurrent, hovered: hoveredPlaceholder,
                               missing: !FileManager.default.fileExists(atPath: p.path))
                    .onHover { hoveredPlaceholder = $0 }
                    .onTapGesture { session.jumpToPlaceholder() }
                    .contextMenu { ForEach(ChromeRules.placeholderMenu, id: \.self) { item in Button(item) { session.clearPlaceholder() } } }
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 0, trailing: 8))
                    .listRowSeparator(.hidden)
                Rectangle().fill(theme.border).frame(height: ChromeMetrics.dividerWidth)
                    .padding(.horizontal, ChromeMetrics.placeholderDividerInset.horizontal)
                    .padding(.vertical, ChromeMetrics.placeholderDividerInset.vertical)
                    .listRowInsets(EdgeInsets()).listRowSeparator(.hidden)
            }
            ForEach(Array(bookmarks.bookmarks.enumerated()), id: \.element.id) { index, row in
                let missing = bookmarks.isMissing(row)
                BookmarkRowView(row: row, slot: index < BookmarksManager.slotCount ? index + 1 : nil, theme: theme,
                                current: session.currentBookmarkID == row.id, hovered: hoveredBookmark == row.id, missing: missing)
                    .onHover { hoveredBookmark = $0 ? row.id : (hoveredBookmark == row.id ? nil : hoveredBookmark) }
                    .onTapGesture { session.openBookmark(row) }
                    .contextMenu { bookmarkMenu(row: row, index: index, missing: missing) }
                    .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
                    .listRowSeparator(.hidden)
            }
            .onMove { from, to in bookmarks.move(fromOffsets: from, toOffset: to) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// C-18.9: the nine-entry menu in order with the `ChromeRules` enablement.
    @ViewBuilder private func bookmarkMenu(row: Database.BookmarkRow, index: Int, missing: Bool) -> some View {
        let items = ChromeRules.bookmarkMenu(rowIndex: index, count: bookmarks.bookmarks.count, fileExists: !missing)
        ForEach(Array(items.enumerated()), id: \.offset) { _, entry in
            Button(entry.item.rawValue) { perform(entry.item, row: row) }.disabled(!entry.enabled)
            if ChromeRules.bookmarkMenuSeparatorsAfter.contains(entry.item) { Divider() }
        }
    }

    private func perform(_ item: ChromeRules.BookmarkMenuItem, row: Database.BookmarkRow) {
        switch item {
        case .goTo: session.openBookmark(row)
        case .revealInFinder: NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: row.path)])
        case .moveUp: bookmarks.moveUp(id: row.id)
        case .moveDown: bookmarks.moveDown(id: row.id)
        case .moveToTop: bookmarks.moveToTop(id: row.id)
        case .moveToBottom: bookmarks.moveToBottom(id: row.id)
        case .remove: bookmarks.remove(id: row.id)
        }
    }
}

/// C-18.8: indented 14 pt × (level − 1), 12 pt, semibold level 1, up to two lines, 8/5 padding, 4 pt radius.
struct TOCRow: View {
    let heading: TOCHeading
    let theme: MDVTheme
    let selected: Bool
    let hovered: Bool

    var body: some View {
        Text(heading.text)
            .font(.system(size: ChromeMetrics.tocFontSize, weight: ChromeRules.tocFontWeight(level: heading.level)))
            .foregroundStyle(selected ? theme.background : ChromeRules.tocTextColor(level: heading.level, theme: theme))
            .lineLimit(ChromeMetrics.tocRowMaxLines)
            .padding(.leading, ChromeRules.tocIndent(level: heading.level))
            .padding(.horizontal, ChromeMetrics.tocRowPadding.horizontal).padding(.vertical, ChromeMetrics.tocRowPadding.vertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: ChromeMetrics.tocRowCornerRadius)
                .fill(selected ? theme.accent : (hovered ? theme.text.opacity(ChromeOpacity.tocHover) : Color.clear)))
            .contentShape(Rectangle())
    }
}

/// C-18.9: the hotkey badge — `⌘` 9 pt bold rounded + digit 10 pt bold rounded, 4 pt continuous radius, 5/1 padding.
struct HotkeyBadge: View {
    let text: String
    let style: RowStyle

    var body: some View {
        HStack(spacing: 0) {
            Text("⌘").font(.system(size: ChromeMetrics.badgeCommandFontSize, weight: .bold, design: .rounded))
            Text(text.dropFirst()).font(.system(size: ChromeMetrics.badgeDigitFontSize, weight: .bold, design: .rounded))
        }
        .foregroundStyle(style.badgeForeground)
        .padding(.horizontal, ChromeMetrics.badgePadding.horizontal).padding(.vertical, ChromeMetrics.badgePadding.vertical)
        .background(RoundedRectangle(cornerRadius: ChromeMetrics.badgeCornerRadius, style: .continuous).fill(style.badgeBackground.opacity(style.badgeBackgroundOpacity)))
    }
}

struct BookmarkRowView: View {
    let row: Database.BookmarkRow
    let slot: Int?
    let theme: MDVTheme
    let current: Bool
    let hovered: Bool
    let missing: Bool

    var body: some View {
        let style = ChromeRules.rowStyle(current: current, hovered: hovered, missing: missing, dropTarget: false, placeholder: false, theme: theme)
        HStack(spacing: 6) {
            Image(systemName: missing ? "exclamationmark.triangle.fill" : "bookmark.fill")
                .font(.system(size: ChromeMetrics.bookmarkGlyphSize))
                .foregroundStyle(style.glyph)
                .frame(width: ChromeMetrics.bookmarkGlyphWidth)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title).font(.system(size: ChromeMetrics.bookmarkTitleFontSize)).lineLimit(1).truncationMode(.tail)
                Text((row.path as NSString).lastPathComponent).font(.system(size: ChromeMetrics.bookmarkFileFontSize)).lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(current ? theme.background.opacity(0.85) : theme.secondaryText)
            }
            .foregroundStyle(style.text)
            Spacer(minLength: 4)
            if let badge = ChromeRules.badge(slot: slot) { HotkeyBadge(text: badge, style: style) }
        }
        .padding(.horizontal, ChromeMetrics.bookmarkRowPadding.horizontal).padding(.vertical, ChromeMetrics.bookmarkRowPadding.vertical)
        .background(RoundedRectangle(cornerRadius: ChromeMetrics.bookmarkRowCornerRadius, style: .continuous).fill((style.fill ?? Color.clear).opacity(style.fill == nil ? 0 : style.fillOpacity)))
        .opacity(style.opacity)
        .contentShape(Rectangle())
    }
}

/// C-18.9 / R-28: the placeholder is the first row — `pin.fill`, the R-27 title (13 pt medium, middle-truncated) over the
/// file name, the `⌘0` badge; tinted at rest, accent-filled while current.
struct PlaceholderRow: View {
    let placeholder: Placeholder
    let theme: MDVTheme
    let current: Bool
    let hovered: Bool
    let missing: Bool

    var body: some View {
        let style = ChromeRules.rowStyle(current: current, hovered: hovered, missing: missing, dropTarget: false, placeholder: true, theme: theme)
        HStack(spacing: 6) {
            Image(systemName: "pin.fill")
                .font(.system(size: ChromeMetrics.placeholderGlyphSize))
                .foregroundStyle(style.glyph)
                .frame(width: ChromeMetrics.bookmarkGlyphWidth)
            VStack(alignment: .leading, spacing: 1) {
                Text(placeholder.title).font(.system(size: ChromeMetrics.bookmarkTitleFontSize, weight: .medium)).lineLimit(1).truncationMode(.middle)
                Text((placeholder.path as NSString).lastPathComponent).font(.system(size: ChromeMetrics.bookmarkFileFontSize)).lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(current ? theme.background.opacity(0.85) : theme.secondaryText)
            }
            .foregroundStyle(style.text)
            Spacer(minLength: 4)
            HotkeyBadge(text: "⌘0", style: style)
        }
        .padding(.horizontal, ChromeMetrics.bookmarkRowPadding.horizontal).padding(.vertical, ChromeMetrics.bookmarkRowPadding.vertical)
        .background(RoundedRectangle(cornerRadius: ChromeMetrics.bookmarkRowCornerRadius, style: .continuous).fill((style.fill ?? Color.clear).opacity(style.fill == nil ? 0 : style.fillOpacity)))
        .overlay(RoundedRectangle(cornerRadius: ChromeMetrics.bookmarkRowCornerRadius, style: .continuous).stroke(style.stroke ?? Color.clear, lineWidth: ChromeMetrics.placeholderStroke))
        .opacity(style.opacity)
        .contentShape(Rectangle())
    }
}
