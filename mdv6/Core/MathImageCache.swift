// MathImageCache — C-07.2: registers the extra symbols once, applies the rewrites, typesets with the vendored
// SwiftMath and bakes the result to a bitmap (I-008, K-15); 2048 entries keyed by the URL. Fallbacks per R-14/E-10,
// and the K-14 LaTeX ceiling before the parser (R-41, E-28).
import Foundation
import AppKit
import SwiftMath

/// R-14: a typeset bitmap with its baseline metrics, or the source (delimiters included) plus the parser's message.
public enum MathResult {
    case image(NSImage, ascent: CGFloat, descent: CGFloat)
    case fallback(source: String, message: String?)
}

public final class MathImageCache {
    public static let shared = MathImageCache()
    /// C-07.2, K-08: 2048 images.
    public static let cacheLimit = 2048

    private var cache: [String: MathResult] = [:]
    private var order: [String] = []
    private let lock = NSLock()

    public init() {}

    /// C-07.2 (a): register once, process-wide (MTMathAtomFactory is global).
    nonisolated(unsafe) private static var registered = false
    private static let registrationLock = NSLock()

    public static func registerSymbols() {
        registrationLock.lock(); defer { registrationLock.unlock() }
        if registered { return }
        registered = true
        for s in MathSymbols.registeredSymbols {
            let atom: MTMathAtom
            switch s.kind {
            case .relation: atom = MTMathAtom(type: .relation, value: s.codepoint)
            case .ordinary: atom = MTMathAtom(type: .ordinary, value: s.codepoint)
            case .binary: atom = MTMathAtom(type: .binaryOperator, value: s.codepoint)
            case .largeOperator: atom = MTMathAtomFactory.operatorWithName(s.codepoint, limits: true)
            }
            MTMathAtomFactory.add(latexSymbol: s.name, value: atom)
        }
    }

    /// C-07.2: cached typesetting keyed by the `mdv6-math://` URL (which carries latex, size, colour and mode).
    public func rendered(for spec: MathSpec, scale: CGFloat) -> MathResult {
        let key = MathMarkdown.url(latex: spec.latex, display: spec.display, size: spec.fontSize, color: spec.color) + "@\(scale)"
        lock.lock()
        if let hit = cache[key] { lock.unlock(); return hit }
        lock.unlock()
        let result = typeset(spec, scale: scale)
        lock.lock()
        if cache.count >= MathImageCache.cacheLimit, let oldest = order.first { cache.removeValue(forKey: oldest); order.removeFirst() }
        cache[key] = result
        order.append(key)
        lock.unlock()
        return result
    }

    /// R-41/K-14 first, then registration, rewrites, `MathImage`, and the bitmap bake.
    public func typeset(_ spec: MathSpec, scale: CGFloat) -> MathResult {
        let delimiter = spec.display ? "$$" : "$"
        let source = delimiter + spec.latex + delimiter
        guard ContentLimits.admits(spec.latex.utf8.count, kind: .latex) else {
            return .fallback(source: source, message: ContentLimits.exceededMessage)            // E-28
        }
        MathImageCache.registerSymbols()
        let latex = MathSymbols.preprocess(spec.latex)
        PipelineProbe.enter("math")
        var image = MathImage(latex: latex, fontSize: spec.fontSize, textColor: spec.color.nsColor,
                              labelMode: spec.display ? .display : .text)
        let (error, mtImage, layout) = image.asImage()
        if let error {
            return .fallback(source: source, message: error.localizedDescription)
        }
        guard let mtImage, mtImage.size.width > 0, mtImage.size.height > 0 else {
            return .fallback(source: source, message: "empty result")
        }
        return .image(bake(mtImage, scale: scale), ascent: layout?.ascent ?? 0, descent: layout?.descent ?? 0)
    }

    /// I-008: an `NSBitmapImageRep`-backed image at the screen scale — never a drawing-handler-backed one.
    public func bake(_ image: NSImage, scale: CGFloat) -> NSImage {
        let size = image.size
        let pw = max(1, Int((size.width * scale).rounded()))
        let ph = max(1, Int((size.height * scale).rounded()))
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return image }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let baked = NSImage(size: size)
        baked.addRepresentation(rep)
        return baked
    }
}
