// MathViews — R-12 / C-07.1 / C-18.10: the inline image provider for `$…$` and mid-line `$$…$$`, the centred
// `MathDisplayView` for own-paragraph `$$…$$` (with *Copy LaTeX*), and the block image provider that routes
// `mdv6-math://display/…` there and every other image to `ImageProviders` (R-16). E-16: an image-only paragraph inside a
// list item or table cell takes the same block path but stays leading-aligned.
import SwiftUI
import AppKit
import MarkdownUI

/// Tracks in-flight inline image loads so an offscreen renderer can wait for them (C-17 determinism).
public enum PendingImageLoads {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var count = 0
    public static var pending: Int { lock.lock(); defer { lock.unlock() }; return count }
    static func begin() { lock.lock(); count += 1; lock.unlock() }
    static func end() { lock.lock(); count -= 1; lock.unlock() }
}

/// C-07.1: `$…$` and mid-line `$$…$$` are inline images (D-02: no baseline hook through MarkdownUI).
public struct MathInlineImageProvider: InlineImageProvider {
    public let scale: CGFloat
    public init(scale: CGFloat) { self.scale = scale }

    public func image(with url: URL, label: String) async throws -> Image {
        PendingImageLoads.begin()
        defer { PendingImageLoads.end() }
        guard let spec = MathMarkdown.decode(url: url) else { throw URLError(.badURL) }
        switch MathImageCache.shared.rendered(for: spec, scale: scale) {
        case .image(let img, _, _):
            return Image(nsImage: img)
        case .fallback(let source, _):
            // R-14 / E-10: the source in monospace at 0.9× (rendered as an image so it stays inline)
            return Image(nsImage: MathFallbackImage.make(source: source, fontSize: spec.fontSize * 0.9, color: spec.color, scale: scale))
        }
    }
}

/// R-12: an own-paragraph `$$…$$` — centred in the column, `.display` mode, context menu *Copy LaTeX* (C-07.1, C-18.10).
public struct MathDisplayView: View {
    public let spec: MathSpec
    public let scale: CGFloat
    public let centred: Bool
    public let theme: MDVTheme

    public var body: some View {
        Group {
            switch MathImageCache.shared.rendered(for: spec, scale: scale) {
            case .image(let img, _, _):
                Image(nsImage: img)
                    .contextMenu { Button("Copy LaTeX") { Pasteboard.copy(spec.latex) } }
            case .fallback(let source, let message):
                VStack(alignment: .leading, spacing: 4) {
                    Text(source).font(.system(size: spec.fontSize * 0.9, design: .monospaced))
                    if let message { Text(message).font(.system(size: 11)).foregroundStyle(theme.secondaryText) }
                }
                .foregroundStyle(theme.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
    }
}

/// R-16 / C-07.1: the block image provider — `mdv6-math://display/…` → `MathDisplayView`, `data:` → inline decode,
/// `http(s)` → the remote gate, everything else → a local file relative to the document.
public struct ArticleImageProvider: ImageProvider {
    public let theme: MDVTheme
    public let scale: CGFloat
    public let baseURL: URL?
    public let loadRemote: Bool
    public let remoteLoader: RemoteImageLoader?
    public let onRevealRemoteSetting: (() -> Void)?

    public init(theme: MDVTheme, scale: CGFloat, baseURL: URL?, loadRemote: Bool, remoteLoader: RemoteImageLoader?, onRevealRemoteSetting: (() -> Void)? = nil) {
        self.theme = theme; self.scale = scale; self.baseURL = baseURL; self.loadRemote = loadRemote
        self.remoteLoader = remoteLoader; self.onRevealRemoteSetting = onRevealRemoteSetting
    }

    @ViewBuilder
    public func makeImage(url: URL?) -> some View {
        if let url, url.scheme == MathMarkdown.scheme, let spec = MathMarkdown.decode(url: url) {
            MathDisplayView(spec: spec, scale: scale, centred: spec.display && MathMarkdown.isOwnParagraph(url: url), theme: theme)
        } else if let url {
            DocumentImageView(url: url, theme: theme, baseURL: baseURL, loadRemote: loadRemote, remoteLoader: remoteLoader, onRevealRemoteSetting: onRevealRemoteSetting)
        } else {
            ImagePlaceholder(text: "image not found", theme: theme)
        }
    }
}

/// R-14: the inline fallback rendered as a bitmap so it can travel through `InlineImageProvider`.
enum MathFallbackImage {
    static func make(source: String, fontSize: CGFloat, color: RGBA, scale: CGFloat) -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular), .foregroundColor: color.nsColor]
        let s = NSAttributedString(string: source, attributes: attrs)
        let size = s.size()
        let pw = max(1, Int((size.width * scale).rounded(.up))), ph = max(1, Int((size.height * scale).rounded(.up)))
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: CGFloat(pw) / scale, height: CGFloat(ph) / scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        s.draw(at: .zero)
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}

/// The system pasteboard (R-22 copy, *Copy LaTeX*, *Copy Code*).
public enum Pasteboard {
    nonisolated(unsafe) public static var writer: (String) -> Void = { s in
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
    public static func copy(_ s: String) { writer(s) }
}
