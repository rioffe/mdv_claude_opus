// DocumentRootView — one window: title (C-18.1), toolbar (C-18.2), the three panes with their 8 pt handles and 1 pt
// dividers, the collapse chevron, the article with the floating find button (C-18.7), the find bar (R-24), the zoom
// HUD (R-30), the `EMPTY` drop target, and the command handlers that act only when addressed to this window (E-26).
import SwiftUI
import AppKit

/// §5.1 commands, posted with the key window in `userInfo` (E-26) and handled by that window only.
public enum AppCommand: String, Sendable {
    case openFile, openInNewWindow, editCurrentFile, find, searchHistory, back, forward, toggleSidebar, toggleInspector,
         zoomIn, zoomOut, actualSize, bookmarkCurrentSpot, setPlaceholder, jumpToPlaceholder, slot1, slot2, slot3, slot4, slot5, help
}

public enum CommandCenter {
    public static let name = Notification.Name("mdv6.command")
    /// E-26: the target window is captured when the command is posted.
    @MainActor
    public static func post(_ command: AppCommand, window: NSWindow? = NSApp.keyWindow) {
        NotificationCenter.default.post(name: name, object: nil, userInfo: ["command": command.rawValue, "window": window as Any])
    }
}

public struct DocumentRootView: View {
    @ObservedObject var session: DocumentSession
    @ObservedObject var preferences: Preferences
    @ObservedObject var history: HistoryManager
    @ObservedObject var bookmarks: BookmarksManager
    @ObservedObject var placeholderStore: PlaceholderStore
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.openWindow) private var openWindow

    @State private var window: NSWindow? = nil
    @State private var sidebarWidth: CGFloat = 240                 // K-04: 180…400, not persisted (D-10)
    @State private var handleHovered = false
    @State private var sidebarDragStart: CGFloat? = nil
    @State private var inspectorDragStart: CGFloat? = nil
    @State private var searchText = ""
    @State private var searchRevealed = false
    @State private var searchFocusRequest = 0
    @State private var sidebarView: NSView? = nil
    @State private var hud: Int? = nil
    @State private var hudTimer: DispatchWorkItem? = nil
    @State private var editorAlert: String? = nil
    @State private var dropTargeted = false

    public init(session: DocumentSession) {
        self.session = session
        self.preferences = session.model.preferences
        self.history = session.model.history
        self.bookmarks = session.model.bookmarks
        self.placeholderStore = session.model.placeholder
    }

    private var theme: MDVTheme { session.theme }

    public var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if !preferences.sidebarCollapsed {
                    HistorySidebar(session: session, history: history, theme: theme, searchText: $searchText, searchRevealed: $searchRevealed,
                                   searchFocusRequest: searchFocusRequest, onSidebarView: { sidebarView = $0 })
                        .frame(width: sidebarWidth)
                    sidebarHandle
                }
                article(areaWidth: articleWidth(total: geo.size.width))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if preferences.inspectorVisible {
                    inspectorHandle
                    InspectorView(session: session, bookmarks: bookmarks, placeholderStore: placeholderStore, preferences: preferences, theme: theme)
                        .frame(width: CGFloat(preferences.inspectorWidth))
                }
            }
        }
        .background(theme.background)
        .background(WindowAccessor(session: session, isDark: theme.isDark, window: $window))
        .navigationTitle(session.windowTitle)                                                    // C-18.1
        .toolbarBackground(theme.background, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar { toolbar }
        .onReceive(NotificationCenter.default.publisher(for: CommandCenter.name)) { handle($0) }
        .onReceive(NotificationCenter.default.publisher(for: .mdv6RevealRemoteImageSetting)) { _ in preferences.loadRemoteImages = true }
        .onChange(of: systemScheme) { s in session.isDarkAppearance = (s == .dark) }                     // R-29 live switch
        .onAppear { session.isDarkAppearance = (systemScheme == .dark) }
        .onChange(of: preferences.fontScale) { s in showHUD(ZoomStep.hudPercent(s)) }
        .onChange(of: preferences.loadRemoteImages) { on in if !on { session.remoteLoader?.cancelAll() } }
        .alert("Couldn't open in external editor", isPresented: Binding(get: { editorAlert != nil }, set: { if !$0 { editorAlert = nil } })) {
            Button("Choose Different Editor…") { chooseEditor() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(editorAlert ?? "") }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in drop(providers) }
    }

    // MARK: layout (§7.2)

    private func articleWidth(total: CGFloat) -> CGFloat {
        var w = total
        if !preferences.sidebarCollapsed { w -= sidebarWidth + ChromeMetrics.handleWidth }
        if preferences.inspectorVisible { w -= CGFloat(preferences.inspectorWidth) + ChromeMetrics.handleWidth }
        return max(w, 1)
    }

    /// C-18.1: a 1 pt divider inside an 8 pt drag handle; the collapse chevron shows only while the pointer is over the handle.
    private var sidebarHandle: some View {
        ZStack {
            Rectangle().fill(theme.border).frame(width: ChromeMetrics.dividerWidth)
            if handleHovered {
                Button { preferences.sidebarCollapsed = true } label: {
                    Image(systemName: "chevron.left").font(.system(size: ChromeMetrics.collapseChevronSize)).foregroundStyle(theme.tertiaryText)
                }
                .buttonStyle(.plain).help("Hide Sidebar (⌃⌘S)")
            }
        }
        .frame(width: ChromeMetrics.handleWidth)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { handleHovered = $0; if $0 { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
        .gesture(DragGesture(minimumDistance: 1).onChanged { v in
            if sidebarDragStart == nil { sidebarDragStart = sidebarWidth }
            sidebarWidth = ChromeRules.clampSidebarWidth(sidebarDragStart! + v.translation.width)
        }.onEnded { _ in sidebarDragStart = nil })
    }

    private var inspectorHandle: some View {
        Rectangle().fill(theme.border).frame(width: ChromeMetrics.dividerWidth)
            .frame(width: ChromeMetrics.handleWidth).frame(maxHeight: .infinity).contentShape(Rectangle())
            .onHover { if $0 { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() } }
            .gesture(DragGesture(minimumDistance: 1).onChanged { v in
                if inspectorDragStart == nil { inspectorDragStart = CGFloat(preferences.inspectorWidth) }
                preferences.inspectorWidth = Double(ChromeRules.clampInspectorWidth(inspectorDragStart! - v.translation.width))
            }.onEnded { _ in inspectorDragStart = nil })
    }

    // MARK: article

    @ViewBuilder private func article(areaWidth: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            if session.state == .empty {
                emptyPanel
            } else {
                ArticleScroller(session: session, areaWidth: areaWidth)
            }
            if session.state != .empty && session.findState == nil {
                Button { session.openFind() } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: ChromeMetrics.findButtonGlyph, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: ChromeMetrics.findButtonSize, height: ChromeMetrics.findButtonSize)
                        .background(Circle().fill(theme.secondaryBackground))
                        .overlay(Circle().stroke(theme.border, lineWidth: ChromeMetrics.findButtonStroke))
                }
                .buttonStyle(.plain).help("Find (⌘F)")
                .padding(12)
            }
            if preferences.sidebarCollapsed {
                HStack {
                    Button { preferences.sidebarCollapsed = false } label: {
                        Image(systemName: "chevron.right").font(.system(size: ChromeMetrics.collapseChevronSize)).foregroundStyle(theme.tertiaryText)
                    }
                    .buttonStyle(.plain).help("Show Sidebar (⌃⌘S)")
                    Spacer()
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .padding(.leading, 4)
                .allowsHitTesting(true)
            }
            VStack(spacing: 0) {
                if session.findState != nil { FindBar(session: session, theme: theme) }
                Spacer()
            }
            if let hud {
                Text("\(hud) %").font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(theme.background)
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(theme.text.opacity(0.75)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
            }
        }
    }

    /// §3.1 `EMPTY`: the drop target / Open… prompt.
    private var emptyPanel: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text").font(.system(size: 40, weight: .light)).foregroundStyle(theme.tertiaryText)
            Text("Drop a Markdown file here").font(.system(size: 15)).foregroundStyle(theme.secondaryText)
            Button("Open…") { CommandCenter.post(.openFile, window: window) }.keyboardShortcut("o")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(dropTargeted ? theme.accent : Color.clear, lineWidth: 2).padding(24))
    }

    private func drop(_ providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()
        for p in providers {
            group.enter()
            p.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) { urls.append(url) }
                else if let url = item as? URL { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) { _ = session.handleDrop(urls) }
        return true
    }

    // MARK: toolbar (C-18.2)

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { CommandCenter.post(.openFile, window: window) } label: { Image(systemName: "plus") }.help("Open… (⌘O)")
            Button { CommandCenter.post(.editCurrentFile, window: window) } label: { Image(systemName: "pencil") }.help("Edit in External Editor (⌘E)")
            Menu {
                ForEach(MDVTheme.all) { t in
                    Button { preferences.themeId = t.id } label: { preferences.themeId == t.id ? Label(t.name, systemImage: "checkmark") : Label(t.name, systemImage: "") }
                }
                Divider()
                Button { preferences.themeId = ThemeCatalog.systemId } label: { preferences.themeId == ThemeCatalog.systemId ? Label("System", systemImage: "checkmark") : Label("System", systemImage: "") }
            } label: { Image(systemName: "paintpalette") }
            .menuIndicator(.hidden).help("Theme")
            Button { CommandCenter.post(.bookmarkCurrentSpot, window: window) } label: {
                Image(systemName: session.hasBookmarkForCurrentFile ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(session.hasBookmarkForCurrentFile ? theme.accent : Color.primary)
            }
            .help("Bookmark Current Spot (⌘D)").disabled(session.document == nil)
            Button { preferences.inspectorVisible.toggle() } label: {
                Image(systemName: "sidebar.right").foregroundStyle(preferences.inspectorVisible ? theme.accent : Color.primary)
            }
            .help("Toggle Inspector (⌥⌘0)")
        }
    }

    // MARK: commands (E-26)

    private func handle(_ note: Notification) {
        guard let raw = note.userInfo?["command"] as? String, let command = AppCommand(rawValue: raw) else { return }
        let target = note.userInfo?["window"] as? NSWindow
        guard let window, target === window else { return }                            // addressed to another window
        switch command {
        case .openFile: openPanel { session.open(urls: $0) }
        case .openInNewWindow: openPanel { urls in if let u = urls.first { openWindow(id: "document", value: u) } }
        case .editCurrentFile:
            switch session.openInEditor() {
            case .opened: break
            case .needsChooser: chooseEditor()
            case .failed(let message): editorAlert = message
            }
        case .find:
            let focused = ChromeRules.sidebarHasFocus(firstResponder: window.firstResponder, sidebarView: sidebarView)
            if session.findCommandTarget(sidebarHasFocus: focused) == .globalSearch { focusGlobalSearch() } else { session.openFind() }
        case .searchHistory: focusGlobalSearch()
        case .back: session.goBack()
        case .forward: session.goForward()
        case .toggleSidebar: preferences.sidebarCollapsed.toggle()
        case .toggleInspector: preferences.inspectorVisible.toggle()
        case .zoomIn: preferences.fontScale = ZoomStep.apply(stored: preferences.fontScale, delta: ZoomStep.step)
        case .zoomOut: preferences.fontScale = ZoomStep.apply(stored: preferences.fontScale, delta: -ZoomStep.step)
        case .actualSize: preferences.fontScale = 1.0
        case .bookmarkCurrentSpot: session.bookmarkCurrentSpot()
        case .setPlaceholder: session.setPlaceholder()
        case .jumpToPlaceholder: session.jumpToPlaceholder()
        case .slot1: session.openSlot(1)
        case .slot2: session.openSlot(2)
        case .slot3: session.openSlot(3)
        case .slot4: session.openSlot(4)
        case .slot5: session.openSlot(5)
        case .help: HelpManager.openHelp(in: session)
        }
    }

    private func focusGlobalSearch() {
        if preferences.sidebarCollapsed { preferences.sidebarCollapsed = false }
        searchRevealed = true
        searchFocusRequest += 1
    }

    private func showHUD(_ percent: Int) {
        hudTimer?.cancel()
        withAnimation(.easeOut(duration: 0.1)) { hud = percent }
        let item = DispatchWorkItem { withAnimation(.easeOut(duration: 0.2)) { hud = nil } }
        hudTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + ZoomStep.hudDuration, execute: item)
    }

    private func openPanel(_ completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText, .text, .directory]
        panel.allowsOtherFileTypes = true
        guard let window else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            completion(panel.urls)
        }
    }

    private func chooseEditor() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose Editor"
        guard let window else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            preferences.editorAppPath = url.path
            _ = session.openInEditor()
        }
    }
}

/// The scrolling article: scroll requests (`scrollTarget`), the topmost visible block (R-27 anchor, R-06 position).
struct ArticleScroller: View {
    @ObservedObject var session: DocumentSession
    let areaWidth: CGFloat

    struct BlockFrame: Equatable { let index: Int; let minY: CGFloat }
    struct BlockFramesKey: PreferenceKey {
        static let defaultValue: [BlockFrame] = []
        static func reduce(value: inout [BlockFrame], nextValue: () -> [BlockFrame]) { value += nextValue() }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                ArticleView(host: session, areaWidth: areaWidth, lazy: true)
                    .background(GeometryReader { _ in Color.clear })
                    .overlay(alignment: .top) { visibilityProbe }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            }
            .coordinateSpace(name: "article")
            .onChange(of: session.scrollTarget) { target in
                if let target { withAnimation(nil) { proxy.scrollTo(target.block, anchor: .top) } }
            }
            .onPreferenceChange(BlockFramesKey.self) { frames in
                if let top = frames.filter({ $0.minY >= -2 }).min(by: { $0.minY < $1.minY }) ?? frames.max(by: { $0.minY < $1.minY }) {
                    if session.topVisibleBlock != top.index { session.topVisibleBlock = top.index }
                }
            }
        }
    }

    private var visibilityProbe: some View { Color.clear.frame(height: 0) }
}

/// R-24: the find bar — query, "n of m" / "No matches", previous/next (⌘G / ⇧⌘G), close (Esc).
struct FindBar: View {
    @ObservedObject var session: DocumentSession
    let theme: MDVTheme
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(theme.secondaryText)
            TextField("Find in document", text: Binding(get: { session.findState?.query ?? "" }, set: { session.setFindQuery($0) }))
                .textFieldStyle(.plain).font(.system(size: 13)).focused($focused)
                .onSubmit { session.findNext() }
                .onExitCommand { session.closeFind() }
            Text(session.findState?.label ?? "").font(.system(size: 11).monospacedDigit()).foregroundStyle(theme.secondaryText)
            Button { session.findPrevious() } label: { Image(systemName: "chevron.up") }.keyboardShortcut("g", modifiers: [.command, .shift]).disabled(!(session.findState?.canStep ?? false))
            Button { session.findNext() } label: { Image(systemName: "chevron.down") }.keyboardShortcut("g", modifiers: .command).disabled(!(session.findState?.canStep ?? false))
            Button { session.closeFind() } label: { Image(systemName: "xmark.circle.fill") }.keyboardShortcut(.escape, modifiers: [])
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.text)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(theme.secondaryBackground)
        .overlay(Rectangle().fill(theme.border).frame(height: 1), alignment: .bottom)
        .onAppear { focused = true }
    }
}
