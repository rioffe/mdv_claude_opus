import XCTest
@testable import mdv6Core

/// The spec's own metrics as code: §7.1 ink weight, C-17 pixel mismatch q, K-16 ink-row gaps and band (I-014).
final class MetricsTests: XCTestCase {

    private func bitmap(_ w: Int, _ h: Int, fill: (Int, Int) -> (UInt8, UInt8, UInt8, UInt8)) -> Bitmap {
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h { for x in 0..<w {
            let (r, g, b, a) = fill(x, y); let o = (y * w + x) * 4
            rgba[o] = r; rgba[o + 1] = g; rgba[o + 2] = b; rgba[o + 3] = a
        } }
        return Bitmap(width: w, height: h, rgba: rgba)
    }

    /// §7.1: ink(P) = mean over D = {p : luminance < 200} of (255 − g(p)); ink = 0 when D is empty. I-009, T-17.
    func testInkMetric() {
        let white = bitmap(4, 4) { _, _ in (255, 255, 255, 255) }
        XCTAssertEqual(RenderMetrics.ink(white), 0)
        XCTAssertTrue(RenderMetrics.inkedPixelCount(white) == 0)
        // two inked pixels at grey 100 and 0, the rest white (255) and one light grey (210, not inked)
        let mixed = bitmap(2, 2) { x, y in
            switch (x, y) { case (0, 0): return (100, 100, 100, 255); case (1, 0): return (0, 0, 0, 255); case (0, 1): return (210, 210, 210, 255); default: return (255, 255, 255, 255) }
        }
        XCTAssertEqual(RenderMetrics.ink(mixed), ((255 - 100) + (255 - 0)) / 2.0, accuracy: 1e-9)
        XCTAssertEqual(RenderMetrics.inkedPixelCount(mixed), 2)
        // luminance uses Rec. 601 weights on RGB
        let red = bitmap(1, 1) { _, _ in (255, 0, 0, 255) }   // luminance ≈ 76 → inked, ink = 255 − 76.245
        XCTAssertEqual(RenderMetrics.ink(red), 255 - (0.299 * 255), accuracy: 0.01)
        XCTAssertEqual(RenderMetrics.inkThreshold, 200)
    }

    /// §7.1: I-009 holds when ink(node) ≥ 0.9 · ink(doc); an empty D on either side fails.
    func testInkRatioRule() {
        let dark = bitmap(2, 1) { _, _ in (0, 0, 0, 255) }
        let mid = bitmap(2, 1) { _, _ in (40, 40, 40, 255) }
        let white = bitmap(2, 1) { _, _ in (255, 255, 255, 255) }
        XCTAssertTrue(RenderMetrics.inkWeightHolds(node: dark, document: mid))
        XCTAssertFalse(RenderMetrics.inkWeightHolds(node: mid, document: dark))      // 215/255 = 0.843 < 0.9
        XCTAssertFalse(RenderMetrics.inkWeightHolds(node: white, document: dark))
        XCTAssertFalse(RenderMetrics.inkWeightHolds(node: dark, document: white))
    }

    /// C-17: q = |D| / N with D the pixels where any channel differs by more than 8; pass when q ≤ 0.001; N = 0, unequal
    /// dimensions, or a missing image fail. T-13, T-19, D-33.
    func testPixelMismatch() {
        let a = bitmap(10, 10) { x, _ in (UInt8(x * 20), 0, 0, 255) }
        XCTAssertEqual(RenderMetrics.pixelMismatch(a, a), 0)
        var b = a
        b.rgba[0] = 9                       // differs by 9 in one pixel → 1/100
        XCTAssertEqual(RenderMetrics.pixelMismatch(a, b)!, 0.01, accuracy: 1e-12)
        var c = a
        c.rgba[3 * 4 + 1] = 8               // differs by exactly 8 → not counted
        XCTAssertEqual(RenderMetrics.pixelMismatch(a, c), 0)
        XCTAssertNil(RenderMetrics.pixelMismatch(a, bitmap(9, 10) { _, _ in (0, 0, 0, 255) }))
        XCTAssertNil(RenderMetrics.pixelMismatch(bitmap(0, 0) { _, _ in (0, 0, 0, 0) }, bitmap(0, 0) { _, _ in (0, 0, 0, 0) }))
        XCTAssertTrue(RenderMetrics.pixelsMatch(a, c))
        XCTAssertFalse(RenderMetrics.pixelsMatch(a, b))                       // 0.01 > 0.001
        let big = bitmap(100, 100) { _, _ in (0, 0, 0, 255) }
        var big2 = big; big2.rgba[0] = 200                                     // 1/10000 = 0.0001 ≤ 0.001
        XCTAssertTrue(RenderMetrics.pixelsMatch(big, big2))
        XCTAssertEqual(RenderMetrics.channelThreshold, 8); XCTAssertEqual(RenderMetrics.mismatchTolerance, 0.001)
    }

    /// K-16 / T-45: an ink row is a row where any pixel differs from the page colour by more than 8/255 on any channel;
    /// gaps between consecutive ink bands are measured in pixels and divided by the scale. I-014.
    func testInkRowsAndGaps() {
        let page = RGBA(r: 244, g: 239, b: 227)
        // 40 rows: ink at rows 2–5, a faint (below-threshold) smudge at row 10, ink at rows 20–21, ink at rows 30–35
        let img = bitmap(3, 40) { _, y in
            if (2...5).contains(y) || (20...21).contains(y) || (30...35).contains(y) { return (60, 40, 30, 255) }
            if y == 10 { return (244 + 8, 239, 227, 255) }
            return (244, 239, 227, 255)
        }
        let bands = RenderMetrics.inkBands(img, page: page)
        XCTAssertEqual(bands, [2...5, 20...21, 30...35])
        XCTAssertEqual(RenderMetrics.gaps(between: bands, scale: 2), [7, 4])    // (20−5−1)/2, (30−21−1)/2
        XCTAssertEqual(RenderMetrics.gaps(between: bands, scale: 1), [14, 8])
        XCTAssertEqual(RenderMetrics.inkBands(bitmap(2, 3) { _, _ in (244, 239, 227, 255) }, page: page), [])
    }

    /// K-16: the rhythm band v ≤ g ≤ v + 0.6f with f the larger font size of the pair. I-014, T-45.
    func testRhythmBand() {
        let band = RenderMetrics.rhythmBand(margin: 32, fontSize: 21.25)
        XCTAssertEqual(band.lowerBound, 32)
        XCTAssertEqual(band.upperBound, 32 + 0.6 * 21.25, accuracy: 1e-9)
        XCTAssertTrue(band.contains(40.5)); XCTAssertFalse(band.contains(31.9)); XCTAssertFalse(band.contains(45.0))
        XCTAssertEqual(RenderMetrics.perBlockTolerance, 2)
    }

    /// T-46's centring apparatus: the ink bounding box of a raster against the page colour (nil when nothing is inked)
    /// and its horizontal offset from the column centre.
    func testInkBounds() {
        let page = RGBA(r: 255, g: 255, b: 255)
        let img = bitmap(20, 10) { x, y in (x >= 5 && x < 15 && y >= 3 && y < 6) ? (0, 0, 0, 255) : (255, 255, 255, 255) }
        XCTAssertEqual(RenderMetrics.inkBounds(img, page: page), CGRect(x: 5, y: 3, width: 10, height: 3))
        XCTAssertNil(RenderMetrics.inkBounds(bitmap(4, 4) { _, _ in (255, 255, 255, 255) }, page: page))
        XCTAssertEqual(RenderMetrics.horizontalCentreOffset(of: CGRect(x: 5, y: 3, width: 10, height: 3), in: 20), 0)
        XCTAssertEqual(RenderMetrics.horizontalCentreOffset(of: CGRect(x: 0, y: 0, width: 10, height: 3), in: 20), -5)
    }
}
