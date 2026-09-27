// ImageProviders — R-16 image views: local files relative to the document, `data:` URIs, and the remote gate
// ("Remote image blocked" until View → Load Remote Images; E-11 failure placeholder; in-flight loads cancelled when the
// preference turns off). Every image obeys K-14 and is never scaled above its intrinsic size.
import SwiftUI
import AppKit
import MarkdownUI

public struct ImagePlaceholder: View {
    public let text: String
    public let theme: MDVTheme
    public var action: (() -> Void)? = nil

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo").foregroundStyle(theme.tertiaryText)
            Text(text).font(.system(size: 12)).foregroundStyle(theme.secondaryText)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(theme.secondaryBackground, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture { action?() }
    }
}

public struct DocumentImageView: View {
    public let url: URL
    public let theme: MDVTheme
    public let baseURL: URL?
    public let loadRemote: Bool
    public let remoteLoader: RemoteImageLoader?
    public let onRevealRemoteSetting: (() -> Void)?
    /// C-22.2: an `<img>` tag's size caps; nil for a Markdown image (drawn at its intrinsic size at most).
    public var sizing: HTMLImageSpec? = nil

    public init(url: URL, theme: MDVTheme, baseURL: URL?, loadRemote: Bool, remoteLoader: RemoteImageLoader?,
                onRevealRemoteSetting: (() -> Void)?, sizing: HTMLImageSpec? = nil) {
        self.url = url; self.theme = theme; self.baseURL = baseURL; self.loadRemote = loadRemote
        self.remoteLoader = remoteLoader; self.onRevealRemoteSetting = onRevealRemoteSetting; self.sizing = sizing
    }

    @State private var remoteResult: ImageLoadResult? = nil

    private var isRemote: Bool { let s = url.scheme?.lowercased(); return s == "http" || s == "https" }

    public var body: some View {
        Group {
            if isRemote {
                remoteBody
            } else if url.scheme == "data" {
                render(ImageDecoding.dataURI(url))
            } else {
                render(ImageDecoding.local(url: url, base: baseURL))
            }
        }
    }

    @ViewBuilder private var remoteBody: some View {
        if !loadRemote {
            ImagePlaceholder(text: "Remote image blocked", theme: theme, action: onRevealRemoteSetting)   // R-16, E-11
        } else if let remoteResult {
            render(remoteResult)
        } else {
            ProgressView().controlSize(.small)
                .task(id: url) {
                    guard let loader = remoteLoader else { remoteResult = .failed(reason: "no loader"); return }
                    let r = await loader.load(url)
                    if !Task.isCancelled { remoteResult = r }
                }
        }
    }

    @ViewBuilder private func render(_ result: ImageLoadResult) -> some View {
        switch result {
        case .image(let img):
            HTMLImageBlockView.sized(img, spec: sizing)                         // never above intrinsic size (or the C-22.2 caps)
        case .blocked:
            ImagePlaceholder(text: "Remote image blocked", theme: theme, action: onRevealRemoteSetting)
        case .notFound(let name):
            ImagePlaceholder(text: "image not found: \(name)", theme: theme)
        case .failed(let reason):
            ImagePlaceholder(text: "image failed: \(reason)", theme: theme)
        }
    }
}

// MARK: - v0.14: `mdv6-img` (C-22.2) and inline images (R-16)

/// C-22.2 on the block path: the `<img>` tag's image at its display size (caps, aspect-fit, shrunk by the column); a local
/// image that cannot be loaded shows its `alt`, or `Missing image: <src>`; remote goes through the R-16 gate.
public struct HTMLImageBlockView: View {
    public let spec: HTMLImageSpec
    public let theme: MDVTheme
    public let baseURL: URL?
    public let loadRemote: Bool
    public let remoteLoader: RemoteImageLoader?
    public let onRevealRemoteSetting: (() -> Void)?

    public var body: some View {
        let target = spec.resolvedURL(baseURL: baseURL)
        let scheme = target.scheme?.lowercased()
        if scheme == "http" || scheme == "https" {
            DocumentImageView(url: target, theme: theme, baseURL: baseURL, loadRemote: loadRemote, remoteLoader: remoteLoader,
                              onRevealRemoteSetting: onRevealRemoteSetting, sizing: spec)
        } else {
            switch scheme == "data" ? ImageDecoding.dataURI(target) : ImageDecoding.local(url: target, base: baseURL) {
            case .image(let img): HTMLImageBlockView.sized(img, spec: spec).accessibilityLabel(spec.alt.isEmpty ? spec.src : spec.alt)
            default:
                Text(spec.alt.isEmpty ? "Missing image: \(spec.src)" : spec.alt)
                    .font(.system(size: 12)).foregroundStyle(theme.secondaryText)
            }
        }
    }

    /// Aspect-fit inside the C-22.2 caps; the column shrinks it further like any image.
    static func sized(_ img: NSImage, spec: HTMLImageSpec?) -> some View {
        let caps = spec?.displaySize(natural: img.size) ?? img.size
        return Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).frame(maxWidth: caps.width, maxHeight: caps.height)
    }
}

/// What the inline provider produced for one URL (tests compare these).
public enum InlineImageResolution: Equatable {
    case image(NSImage)
    case text(String)
    case empty

    public static func == (a: Self, b: Self) -> Bool {
        switch (a, b) {
        case (.image(let x), .image(let y)): return x === y || x.size == y.size
        case (.text(let x), .text(let y)): return x == y
        case (.empty, .empty): return true
        default: return false
        }
    }
}

/// R-16 / C-22.2 on the inline path: math → the math provider (R-12 placement, F-173); `mdv6-img` and local / `data:`
/// images → loaded against the document's directory, an `<img>` given its C-22.2 point size; `http(s)` → C-16 only with
/// Load Remote Images on, else the non-clickable *Remote image blocked* text image (*Image failed to load* on failure);
/// a missing local image → an empty image, so it is left out of the line without dropping its siblings. MarkdownUI draws
/// an inline image as a glyph on the text baseline, and the line grows to hold it (C-22.2 inline placement).
public struct ArticleInlineImageProvider: InlineImageProvider {
    public let theme: MDVTheme
    public let scale: CGFloat
    public let baseURL: URL?
    public let loadRemote: Bool
    public let remoteLoader: RemoteImageLoader?

    public init(theme: MDVTheme, scale: CGFloat, baseURL: URL?, loadRemote: Bool, remoteLoader: RemoteImageLoader?) {
        self.theme = theme; self.scale = scale; self.baseURL = baseURL; self.loadRemote = loadRemote; self.remoteLoader = remoteLoader
    }

    public func image(with url: URL, label: String) async throws -> Image {
        if url.scheme == MathMarkdown.scheme { return try await MathInlineImageProvider(scale: scale).image(with: url, label: label) }
        PendingImageLoads.begin()
        defer { PendingImageLoads.end() }
        switch try await resolve(url: url) {
        case .image(let img): return Image(nsImage: img)
        case .text(let t): return Image(nsImage: textImage(t))
        case .empty: return Image(nsImage: Self.nothing)
        }
    }

    /// A missing inline image on the `.task` path: upstream drops every inline image of the paragraph when one load
    /// throws, so the provider returns a transparent image of negligible width instead (C-22.2: left out of the line).
    static let nothing: NSImage = {
        let img = NSImage(size: NSSize(width: 0.01, height: 0.01))
        img.addRepresentation(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4,
                                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!)
        return img
    }()

    public func resolve(url: URL) async throws -> InlineImageResolution {
        let spec = HTMLImageSpec(url: url)
        let target = spec?.resolvedURL(baseURL: baseURL) ?? url
        let scheme = target.scheme?.lowercased()
        if scheme == "http" || scheme == "https" {
            guard loadRemote, let loader = remoteLoader else { return .text("Remote image blocked") }   // R-16, D-51
            return classify(await loader.load(target), spec: spec, remote: true)
        }
        return resolveLocal(url: url)
    }

    /// The synchronous half: local files, `data:` URIs, `mdv6-img` tags, and a remote source only as its placeholder
    /// text (an offscreen render or print never fetches, R-45).
    public func resolveLocal(url: URL) -> InlineImageResolution {
        let spec = HTMLImageSpec(url: url)
        let target = spec?.resolvedURL(baseURL: baseURL) ?? url
        let scheme = target.scheme?.lowercased()
        if scheme == "http" || scheme == "https" { return .text("Remote image blocked") }
        return classify(scheme == "data" ? ImageDecoding.dataURI(target) : ImageDecoding.local(url: target, base: baseURL), spec: spec, remote: false)
    }

    /// Every inline image source of a rewritten Markdown block, resolved synchronously — math through the typesetting
    /// cache, pictures through `resolveLocal` — keyed by source string, for `markdownResolvedInlineImages` (I-016).
    public func resolvedImages(markdown: String) -> [String: Image] {
        var out: [String: Image] = [:]
        for source in InlineImageSources.sources(in: markdown) {
            guard let url = URL(string: source, relativeTo: baseURL) else { continue }
            if url.scheme == MathMarkdown.scheme, let spec = MathMarkdown.decode(url: url) {
                switch MathImageCache.shared.rendered(for: spec, scale: scale) {
                case .image(let img, _, _): out[source] = Image(nsImage: img)
                case .fallback(let src, _): out[source] = Image(nsImage: MathFallbackImage.make(source: src, fontSize: spec.fontSize * 0.9, color: spec.color, scale: scale))
                }
                continue
            }
            switch resolveLocal(url: url) {
            case .image(let img): out[source] = Image(nsImage: img)
            case .text(let t): out[source] = Image(nsImage: textImage(t))
            case .empty: continue                       // absent key: MarkdownUI draws nothing (C-22.2)
            }
        }
        return out
    }

    private func classify(_ result: ImageLoadResult, spec: HTMLImageSpec?, remote: Bool) -> InlineImageResolution {
        switch result {
        case .image(let img):
            if let spec { img.size = spec.displaySize(natural: img.size) }   // point size only; pixels untouched
            return .image(img)
        case .notFound: return .empty
        case .blocked: return .text("Remote image blocked")
        case .failed: return remote ? .text("Image failed to load") : .empty
        }
    }

    /// The inline placeholder text as an image at the body size, in the secondary colour.
    private func textImage(_ text: String) -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: theme.baseFontSize),
                                                    .foregroundColor: theme.rgba.secondaryText.nsColor]
        let s = NSAttributedString(string: text, attributes: attrs)
        let size = s.size()
        return NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)), flipped: false) { _ in s.draw(at: .zero); return true }
    }
}

/// The `![alt](source)` sources of a Markdown string, in order (the keys MarkdownUI's `InlineText` uses).
public enum InlineImageSources {
    public static func sources(in markdown: String) -> [String] {
        var out: [String] = []
        var rest = Substring(markdown)
        while let open = rest.range(of: "![") {
            guard let mid = rest[open.upperBound...].range(of: "]("),
                  let close = rest[mid.upperBound...].firstIndex(of: ")") else { break }
            out.append(String(rest[mid.upperBound ..< close]))
            rest = rest[rest.index(after: close)...]
        }
        return out
    }
}
