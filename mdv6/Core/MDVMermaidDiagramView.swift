// MDVMermaidDiagramView + MermaidCodeBlockChrome — R-09, R-10, R-11: a ` ```mermaid ` fence rendered natively at the
// §7.2 width and the screen's backing scale (I-005, K-07), with the style menu (persisted in `mdv6.mermaid.style`),
// *Show Mermaid source*, *Export diagram as PNG*, copy, pinch-to-zoom [0.5, 4]; the R-10/E-02/E-28 fallback; in-flight
// layout cancelled when the document changes (E-25).
import SwiftUI
import AppKit

/// The prepared-or-failed state of one diagram.
public enum MermaidOutcome {
    case prepared(MDVMermaidPrepared)
    case fallback(message: String)
}

public struct MDVMermaidDiagramView: View {
    public let source: String
    public let documentTheme: MDVTheme
    public let style: MermaidStyle
    public let columnWidth: CGFloat
    public let backingScale: CGFloat
    public let generation: Int
    public let onOutcome: ((MermaidOutcome) -> Void)?

    @State private var outcome: MermaidOutcome? = nil
    @State private var image: NSImage? = nil
    @State private var committedZoom: CGFloat = 1
    @State private var liveZoom: CGFloat = 1

    public init(source: String, documentTheme: MDVTheme, style: MermaidStyle, columnWidth: CGFloat, backingScale: CGFloat,
                generation: Int, onOutcome: ((MermaidOutcome) -> Void)? = nil) {
        self.source = source; self.documentTheme = documentTheme; self.style = style; self.columnWidth = columnWidth
        self.backingScale = backingScale; self.generation = generation; self.onOutcome = onOutcome
    }

    /// R-11: the raster width from the §7.2 formula, times the committed zoom (K-07).
    var rasterWidth: CGFloat {
        guard case .prepared(let p) = outcome else { return 1 }
        let base = ColumnWidth.rasterWidth(natural: p.naturalSize.width, column: columnWidth)
        return max(1, floor(min(p.naturalSize.width, base * committedZoom)))
    }

    var themeKey: String { "\(style.rawValue)/\(documentTheme.id)" }

    public var body: some View {
        Group {
            switch outcome {
            case .none:
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: 60)
            case .fallback(let message):
                MermaidFallbackView(message: message, source: source, theme: documentTheme)
            case .prepared(let p):
                let size = MDVMermaidPipeline.displaySize(for: p, width: rasterWidth)
                ScrollView([.horizontal, .vertical], showsIndicators: committedZoom > 1) {
                    Group {
                        if let image {
                            Image(nsImage: image).frame(width: size.width, height: size.height)     // I-005: exactly its own point size
                        } else {
                            Color.clear.frame(width: size.width, height: size.height)
                        }
                    }
                    .scaleEffect(liveZoom / committedZoom, anchor: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxHeight: committedZoom > 1 ? min(size.height, MermaidZoom.maxContainerHeight) : nil)
                .gesture(MagnificationGesture()                                                  // K-07: [0.5, 4], committed on end
                    .onChanged { liveZoom = MermaidZoom.clamp(committedZoom * $0) }
                    .onEnded { _ in committedZoom = MermaidZoom.clamp(liveZoom); liveZoom = committedZoom })
            }
        }
        .task(id: "\(generation)|\(themeKey)|\(source.hashValue)") { await prepare() }
        .task(id: "\(rasterWidth)|\(backingScale)|\(themeKey)|\(source.hashValue)|\(outcome == nil)") { await raster() }
    }

    private func prepare() async {
        let key = MermaidCaches.LayoutKey(source: source, themeId: themeKey)
        if let cached = MermaidCaches.shared.layout(key) { outcome = .prepared(cached); onOutcome?(.prepared(cached)); return }
        let src = source, theme = MDVMermaidPipeline.theme(for: style, document: documentTheme)
        let result: MermaidOutcome = await Task.detached(priority: .userInitiated) {
            do { return .prepared(try MDVMermaidPipeline.prepare(source: src, theme: theme)) }
            catch MermaidPrepareError.exceedsLimit { return .fallback(message: ContentLimits.exceededMessage) }        // E-28
            catch { return .fallback(message: "Mermaid diagram could not be rendered") }                                // E-02
        }.value
        if Task.isCancelled { return }                                                                                // E-25
        if case .prepared(let p) = result { MermaidCaches.shared.store(p, for: key) }
        outcome = result
        onOutcome?(result)
    }

    private func raster() async {
        guard case .prepared(let p) = outcome else { image = nil; return }
        let width = rasterWidth, scale = backingScale
        let key = MermaidCaches.RasterKey(source: source, themeId: themeKey, width: width, zoom: committedZoom, scale: scale)
        if let cached = MermaidCaches.shared.raster(key) { image = cached; return }
        let rendered = await Task.detached(priority: .userInitiated) { MDVMermaidPipeline.rasterize(p, width: width, scale: scale) }.value
        if Task.isCancelled { return }
        if let rendered { MermaidCaches.shared.store(rendered, for: key) }
        image = rendered
    }
}

/// R-10 / E-02 / E-28: "Mermaid diagram could not be rendered" (or "input exceeds limit") and the source in monospace.
public struct MermaidFallbackView: View {
    public let message: String
    public let source: String
    public let theme: MDVTheme

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.secondaryText)
            Text(source).font(.system(size: 12, design: .monospaced)).foregroundStyle(theme.text).textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

/// R-09 / §5.1 in-block controls for a Mermaid fence.
public struct MermaidCodeBlockChrome: View {
    public let source: String
    public let documentTheme: MDVTheme
    public let style: MermaidStyle
    public let columnWidth: CGFloat
    public let backingScale: CGFloat
    public let generation: Int
    public let onStyleChange: (MermaidStyle) -> Void

    @State private var showSource = false
    @State private var hovering = false
    @State private var lastOutcome: MermaidOutcome? = nil

    public init(source: String, documentTheme: MDVTheme, style: MermaidStyle, columnWidth: CGFloat, backingScale: CGFloat,
                generation: Int, onStyleChange: @escaping (MermaidStyle) -> Void) {
        self.source = source; self.documentTheme = documentTheme; self.style = style; self.columnWidth = columnWidth
        self.backingScale = backingScale; self.generation = generation; self.onStyleChange = onStyleChange
    }

    static let styleNames: [MermaidStyle: String] = [.document: "Document", .light: "Light", .dark: "Dark", .tokyoNight: "Tokyo Night", .catppuccin: "Catppuccin"]

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if showSource {
                    // no Mermaid grammar exists: the source is plain monospace (R-09)
                    Text(source).font(.system(size: 0.85 * documentTheme.baseFontSize, design: .monospaced))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16).background(documentTheme.secondaryBackground).clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    MDVMermaidDiagramView(source: source, documentTheme: documentTheme, style: style, columnWidth: columnWidth,
                                          backingScale: backingScale, generation: generation) { lastOutcome = $0 }
                        .padding(.vertical, 8)
                }
            }
            if hovering {
                HStack(spacing: 8) {
                    Menu {
                        ForEach(MermaidStyle.allCases, id: \.self) { s in
                            Button { onStyleChange(s) } label: { if s == style { Label(Self.styleNames[s]!, systemImage: "checkmark") } else { Text(Self.styleNames[s]!) } }
                        }
                    } label: { Image(systemName: "paintpalette") }.help("Diagram Style")
                    Button { showSource.toggle() } label: { Image(systemName: showSource ? "photo" : "chevron.left.forwardslash.chevron.right") }
                        .help(showSource ? "Show Diagram" : "Show Mermaid Source")
                    Button { export() } label: { Image(systemName: "square.and.arrow.up") }.help("Export Diagram as PNG")
                    Button { Pasteboard.copy(source) } label: { Image(systemName: "doc.on.doc") }.help("Copy Code")
                }
                .buttonStyle(.plain).menuStyle(.borderlessButton).menuIndicator(.hidden)
                .font(.system(size: 11)).foregroundStyle(documentTheme.secondaryText)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(documentTheme.secondaryBackground, in: Capsule())
                .overlay(Capsule().stroke(documentTheme.border, lineWidth: 0.5))
                .padding(6)
            }
        }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy Code") { Pasteboard.copy(source) }
            Button(showSource ? "Show Diagram" : "Show Mermaid Source") { showSource.toggle() }
            Menu("Diagram Style") {
                ForEach(MermaidStyle.allCases, id: \.self) { s in Button(Self.styleNames[s]!) { onStyleChange(s) } }
            }
            Button("Export Diagram as PNG") { export() }
        }
    }

    /// §5.1: PNG export at natural size, 2× pixel density, to a user-chosen path; failure beeps.
    private func export() {
        guard case .prepared(let p) = lastOutcome, let image = MDVMermaidPipeline.rasterize(p, width: p.naturalSize.width, scale: 2),
              let rep = image.representations.first as? NSBitmapImageRep, let png = rep.representation(using: .png, properties: [:]) else {
            NSSound.beep(); return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "diagram.png"
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try png.write(to: url) } catch { NSSound.beep() }
    }
}
