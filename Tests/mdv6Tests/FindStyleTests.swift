import XCTest
@testable import mdv6Core

/// C-09.1 find-highlight typography (R-24). T-60 (unit half).
final class FindStyleTests: XCTestCase {

    /// C-09.1: size = round(base × zoom × e); heading weight and colour; h6 tertiary; padding 0.3 × body size above a drawn rule.
    func testStyleTable() {
        for theme in [MDVTheme.highContrast, MDVTheme.sevilla] {
            let zoom: CGFloat = 1.25
            let base = theme.baseFontSize * zoom
            let ems = theme.headingSizeEms
            for level in 1...6 {
                let s = FindBlockStyle.style(forBlock: String(repeating: "#", count: level) + " Title", theme: theme, zoom: zoom)
                XCTAssertEqual(s.size, (base * ems[level - 1]).rounded(), "\(theme.id) h\(level)")
                XCTAssertEqual(s.weight, .heading)
                XCTAssertEqual(s.colorRole, level == 6 ? .tertiaryText : .heading)
                XCTAssertEqual(s.lineSpacing, s.size * 0.125, accuracy: 0.0001)
                XCTAssertEqual(s.rule, level == 1 ? theme.showH1Rule : level == 2 ? theme.showH2Rule : false)
                XCTAssertEqual(s.bottomPadding, s.rule ? base * 0.3 : 0, accuracy: 0.0001)   // C-09.1 (F-182): the heading's own padding
                XCTAssertEqual(s.codeSize, (s.size * 0.90).rounded())
            }
            let body = FindBlockStyle.style(forBlock: "plain paragraph", theme: theme, zoom: zoom)
            XCTAssertEqual(body.size, base.rounded())
            XCTAssertEqual(body.colorRole, .text)
            XCTAssertEqual(body.weight, .regular)
            XCTAssertEqual(body.lineSpacing, body.size * theme.paragraphLineSpacingEm, accuracy: 0.0001)
        }
        XCTAssertEqual(FindBlockStyle.style(forBlock: "####### seven", theme: .highContrast, zoom: 1).colorRole, .text)
        XCTAssertEqual(FindBlockStyle.style(forBlock: "#nospace", theme: .highContrast, zoom: 1).colorRole, .text)
    }
}
