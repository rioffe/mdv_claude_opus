import XCTest
@testable import mdv6Core

/// The v0.14 formulas as functions: K-18 scroll steps, R-48 history step, C-21.1/C-21.3 print widths. T-56, T-57, T-53.
final class V014FormulaTests: XCTestCase {

    /// K-18: line 40 pt; page max(0.875 u, 40); Home/End aim past the ends (the scroll view clamps). R-49, T-57.
    func testScrollTargets() {
        XCTAssertEqual(ScrollKeys.target(.down, y: 100, usable: 800, documentHeight: 5000), 140)
        XCTAssertEqual(ScrollKeys.target(.up, y: 100, usable: 800, documentHeight: 5000), 60)
        XCTAssertEqual(ScrollKeys.target(.pageDown, y: 100, usable: 800, documentHeight: 5000), 800)
        XCTAssertEqual(ScrollKeys.target(.space, y: 100, usable: 800, documentHeight: 5000), 800)
        XCTAssertEqual(ScrollKeys.target(.pageUp, y: 800, usable: 800, documentHeight: 5000), 100)
        XCTAssertEqual(ScrollKeys.target(.pageDown, y: 0, usable: 10, documentHeight: 5000), 40)   // degenerate: 40 pt floor
        XCTAssertLessThan(ScrollKeys.target(.home, y: 900, usable: 800, documentHeight: 5000), -5000)
        XCTAssertGreaterThan(ScrollKeys.target(.end, y: 0, usable: 800, documentHeight: 5000), 5000)
        XCTAssertEqual(ScrollKeys.endRetries, 10)
    }

    /// K-18 / R-49: key codes map to keys; ⇧Space pages up; unknown keys pass.
    func testKeyMap() {
        XCTAssertEqual(ScrollKeys.key(keyCode: 125, shift: false), .down)
        XCTAssertEqual(ScrollKeys.key(keyCode: 126, shift: false), .up)
        XCTAssertEqual(ScrollKeys.key(keyCode: 121, shift: false), .pageDown)
        XCTAssertEqual(ScrollKeys.key(keyCode: 116, shift: false), .pageUp)
        XCTAssertEqual(ScrollKeys.key(keyCode: 49, shift: false), .space)
        XCTAssertEqual(ScrollKeys.key(keyCode: 49, shift: true), .pageUp)
        XCTAssertEqual(ScrollKeys.key(keyCode: 115, shift: false), .home)
        XCTAssertEqual(ScrollKeys.key(keyCode: 119, shift: false), .end)
        XCTAssertNil(ScrollKeys.key(keyCode: 0, shift: false))
    }

    /// R-48: one row down or up, clamped, no wrap; nothing displayed → nil. T-56.
    func testHistoryStep() {
        XCTAssertEqual(HistoryStep.target(current: 1, offset: 1, count: 4), 2)
        XCTAssertEqual(HistoryStep.target(current: 1, offset: -1, count: 4), 0)
        XCTAssertNil(HistoryStep.target(current: 3, offset: 1, count: 4))
        XCTAssertNil(HistoryStep.target(current: 0, offset: -1, count: 4))
        XCTAssertNil(HistoryStep.target(current: nil, offset: 1, count: 4))
    }

    /// C-21.1: s_p = min(1, w_c / W), 1 without a max width; C-21.3 w_d and w_ℓ with the 1 pt floor. K-17, T-53.
    func testPrintScale() {
        XCTAssertEqual(PrintScale.contentWidth(paperWidth: 612), 504)
        XCTAssertEqual(PrintScale.sp(contentWidth: 504, articleMaxWidth: 860), 504.0 / 860.0, accuracy: 1e-9)
        XCTAssertEqual(PrintScale.sp(contentWidth: 504, articleMaxWidth: nil), 1)
        XCTAssertEqual(PrintScale.sp(contentWidth: 1000, articleMaxWidth: 860), 1)
        let sp = 504.0 / 860.0
        XCTAssertEqual(PrintScale.diagramWidth(contentWidth: 504, sp: sp), 504 - 36 * sp, accuracy: 1e-9)
        XCTAssertEqual(PrintScale.layoutWidth(diagramWidth: 504 - 36 * sp, sp: sp), (504 - 36 * sp) / sp, accuracy: 1e-9)
        XCTAssertEqual(PrintScale.diagramWidth(contentWidth: 10, sp: 1), 1)
        XCTAssertEqual(PrintScale.layoutWidth(diagramWidth: 0, sp: 0.5), 1)
    }
}
