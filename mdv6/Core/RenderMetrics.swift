// RenderMetrics — the spec's measurable oracles as code: §7.1 ink weight (I-009, T-17), the C-17 pixel-mismatch
// fraction q (T-13, T-19), and the K-16 ink-row gap and band for the vertical-rhythm invariant (I-014, T-45, T-46).
import Foundation
import CoreGraphics

/// A straight RGBA8 bitmap (row-major, 4 bytes per pixel).
public struct Bitmap: Equatable {
    public let width: Int
    public let height: Int
    public var rgba: [UInt8]

    public init(width: Int, height: Int, rgba: [UInt8]) {
        precondition(rgba.count == width * height * 4)
        self.width = width; self.height = height; self.rgba = rgba
    }

    public func pixel(_ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let o = (y * width + x) * 4
        return (rgba[o], rgba[o + 1], rgba[o + 2], rgba[o + 3])
    }

    /// Rec. 601 luminance of a pixel, in [0, 255].
    public func luminance(_ x: Int, _ y: Int) -> Double {
        let p = pixel(x, y)
        return 0.299 * Double(p.r) + 0.587 * Double(p.g) + 0.114 * Double(p.b)
    }
}

public enum RenderMetrics {
    // MARK: §7.1 ink weight

    /// §7.1: D = { p : g(p) < 200 }.
    public static let inkThreshold: Double = 200
    /// §7.1: I-009 holds when ink(node) ≥ 0.9 · ink(doc).
    public static let inkRatio = 0.9

    /// §7.1: ink(P) = (1/|D|) Σ_{p∈D} (255 − g(p)); 0 when D is empty.
    public static func ink(_ crop: Bitmap) -> Double {
        var sum = 0.0
        var count = 0
        for y in 0..<crop.height { for x in 0..<crop.width {
            let g = crop.luminance(x, y)
            if g < inkThreshold { sum += 255 - g; count += 1 }
        } }
        return count == 0 ? 0 : sum / Double(count)
    }

    public static func inkedPixelCount(_ crop: Bitmap) -> Int {
        var count = 0
        for y in 0..<crop.height { for x in 0..<crop.width where crop.luminance(x, y) < inkThreshold { count += 1 } }
        return count
    }

    /// §7.1: an empty D on either side is a failure.
    public static func inkWeightHolds(node: Bitmap, document: Bitmap) -> Bool {
        guard inkedPixelCount(node) > 0, inkedPixelCount(document) > 0 else { return false }
        return ink(node) >= inkRatio * ink(document)
    }

    // MARK: C-17 pixel comparison

    /// C-17: a pixel is in D when at least one 8-bit RGBA channel differs by more than 8.
    public static let channelThreshold = 8
    /// C-17: pass when q ≤ 0.001.
    public static let mismatchTolerance = 0.001

    /// C-17: q = |D| / N; nil (a failure) for N = 0 or unequal dimensions.
    public static func pixelMismatch(_ a: Bitmap, _ b: Bitmap) -> Double? {
        guard a.width == b.width, a.height == b.height else { return nil }
        let n = a.width * a.height
        guard n > 0 else { return nil }
        var d = 0
        var o = 0
        while o < a.rgba.count {
            if abs(Int(a.rgba[o]) - Int(b.rgba[o])) > channelThreshold
                || abs(Int(a.rgba[o + 1]) - Int(b.rgba[o + 1])) > channelThreshold
                || abs(Int(a.rgba[o + 2]) - Int(b.rgba[o + 2])) > channelThreshold
                || abs(Int(a.rgba[o + 3]) - Int(b.rgba[o + 3])) > channelThreshold {
                d += 1
            }
            o += 4
        }
        return Double(d) / Double(n)
    }

    public static func pixelsMatch(_ a: Bitmap, _ b: Bitmap) -> Bool {
        guard let q = pixelMismatch(a, b) else { return false }
        return q <= mismatchTolerance
    }

    // MARK: K-16 rhythm

    /// K-16 / T-45: a row is ink when any pixel differs from the page colour by more than 8/255 on any channel.
    public static func isInkRow(_ image: Bitmap, y: Int, page: RGBA) -> Bool {
        for x in 0..<image.width {
            let p = image.pixel(x, y)
            if abs(Int(p.r) - Int(page.r)) > channelThreshold || abs(Int(p.g) - Int(page.g)) > channelThreshold
                || abs(Int(p.b) - Int(page.b)) > channelThreshold { return true }
        }
        return false
    }

    /// Consecutive runs of ink rows, top to bottom.
    public static func inkBands(_ image: Bitmap, page: RGBA) -> [ClosedRange<Int>] {
        var bands: [ClosedRange<Int>] = []
        var start: Int? = nil
        for y in 0..<image.height {
            let ink = isInkRow(image, y: y, page: page)
            if ink, start == nil { start = y }
            if !ink, let s = start { bands.append(s...(y - 1)); start = nil }
        }
        if let s = start { bands.append(s...(image.height - 1)) }
        return bands
    }

    /// The gap between consecutive bands (rows strictly between them) in points at the given scale.
    public static func gaps(between bands: [ClosedRange<Int>], scale: CGFloat) -> [CGFloat] {
        guard bands.count >= 2 else { return [] }
        return zip(bands, bands.dropFirst()).map { CGFloat($1.lowerBound - $0.upperBound - 1) / scale }
    }

    /// K-16: the inter-block ink gap g must satisfy v ≤ g ≤ v + 0.6 f.
    public static func rhythmBand(margin v: CGFloat, fontSize f: CGFloat) -> ClosedRange<CGFloat> { v...(v + 0.6 * f) }
    /// K-16: the per-block rendering's g must be within ±2 pt of the single-view rendering's g.
    public static let perBlockTolerance: CGFloat = 2

    // MARK: T-46 centring

    /// The bounding box of every pixel that differs from the page colour by more than 8/255; nil when none does.
    public static func inkBounds(_ image: Bitmap, page: RGBA) -> CGRect? {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0..<image.height { for x in 0..<image.width {
            let p = image.pixel(x, y)
            if abs(Int(p.r) - Int(page.r)) > channelThreshold || abs(Int(p.g) - Int(page.g)) > channelThreshold
                || abs(Int(p.b) - Int(page.b)) > channelThreshold {
                minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
            }
        } }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// Signed distance between the box's horizontal centre and the column's centre (0 when centred).
    public static func horizontalCentreOffset(of box: CGRect, in width: CGFloat) -> CGFloat { box.midX - width / 2 }
}
