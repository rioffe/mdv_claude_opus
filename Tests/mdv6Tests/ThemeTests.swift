import XCTest
import SwiftUI
@testable import mdv6Core

/// C-09 theme contract, K-10 defaults, the nine themes of `TYPOGRAPHY.md`, R-29 resolution, C-05 code palette lookup.
final class ThemeTests: XCTestCase {

    /// C-09: `MDVTheme.all` is the nine themes in the listed order with the documented ids and display names. R-29.
    func testCatalogOrderAndIds() {
        XCTAssertEqual(MDVTheme.all.map(\.id), ["high-contrast", "sevilla", "charcoal", "solarium-daylight", "solarium-moonlight",
                                                "phosphor", "twilight", "standard-erin-light", "standard-erin-dark"])
        XCTAssertEqual(MDVTheme.all.map(\.name), ["High Contrast", "Sevilla", "Charcoal", "Solarium Daylight", "Solarium Moonlight",
                                                  "Phosphor", "Twilight", "Standard Erin Light", "Standard Erin Dark"])
        XCTAssertEqual(MDVTheme.all.map(\.isDark), [false, false, true, false, true, true, true, false, true])
        XCTAssertEqual(Set(MDVTheme.all.map(\.id)).count, 9)
    }

    /// R-29, C-04: `system` resolves to `high-contrast` in Light and `twilight` in Dark; an unknown id resolves to
    /// `high-contrast`. T-12, T-42.
    func testResolution() {
        XCTAssertEqual(ThemeCatalog.resolve(id: "system", isDarkAppearance: false).id, "high-contrast")
        XCTAssertEqual(ThemeCatalog.resolve(id: "system", isDarkAppearance: true).id, "twilight")
        XCTAssertEqual(ThemeCatalog.resolve(id: "sevilla", isDarkAppearance: true).id, "sevilla")
        XCTAssertEqual(ThemeCatalog.resolve(id: "bogus", isDarkAppearance: false).id, "high-contrast")
        XCTAssertEqual(ThemeCatalog.resolve(id: "", isDarkAppearance: true).id, "high-contrast")
        XCTAssertEqual(ThemeCatalog.systemId, "system")
        XCTAssertEqual(ThemeCatalog.defaultId, "high-contrast")
        XCTAssertNil(ThemeCatalog.theme(id: "bogus"))
    }

    /// K-10, C-09: the cross-theme defaults — body 16 pt, line spacing 0.30 em, 1.75/1.4/1.15 (h4–h6 1.0/0.875/0.85),
    /// max width 860, gutter 40, spacing 24/16 ×3 and paragraph 16, H1 rule on / H2 rule off, semibold headings and strong.
    func testDefaults() {
        let t = MDVTheme.highContrast
        XCTAssertEqual(t.baseFontSize, 16)
        XCTAssertEqual(t.paragraphLineSpacingEm, 0.30)
        XCTAssertEqual(t.h1SizeEm, 1.75); XCTAssertEqual(t.h2SizeEm, 1.4); XCTAssertEqual(t.h3SizeEm, 1.15)
        XCTAssertEqual(t.h4SizeEm, 1.0); XCTAssertEqual(t.h5SizeEm, 0.875); XCTAssertEqual(t.h6SizeEm, 0.85)
        XCTAssertEqual(t.headingSizeEms, [1.75, 1.4, 1.15, 1.0, 0.875, 0.85])
        XCTAssertEqual(t.articleMaxWidth, 860); XCTAssertEqual(t.articleHorizontalPadding, 40)
        XCTAssertEqual(t.h1TopSpacing, 24); XCTAssertEqual(t.h1BottomSpacing, 16)
        XCTAssertEqual(t.h2TopSpacing, 24); XCTAssertEqual(t.h2BottomSpacing, 16)
        XCTAssertEqual(t.h3TopSpacing, 24); XCTAssertEqual(t.h3BottomSpacing, 16)
        XCTAssertEqual(t.paragraphBottomSpacing, 16)
        XCTAssertTrue(t.showH1Rule); XCTAssertFalse(t.showH2Rule)
        XCTAssertEqual(t.headingFontWeight, .semibold); XCTAssertEqual(t.strongFontWeight, .semibold)
        XCTAssertEqual(t.bodyFontFamily, .system)
        XCTAssertTrue(t.smartTypographyAllowed)
    }

    /// `TYPOGRAPHY.md` per-theme values: Sevilla, Charcoal, Solarium, Standard Erin (I-014 margins come from here). K-16.
    func testPerThemeValues() {
        let s = MDVTheme.sevilla
        XCTAssertEqual(s.bodyFontFamily, .custom("Alegreya"))
        XCTAssertEqual(s.baseFontSize, 17); XCTAssertEqual(s.paragraphLineSpacingEm, 0.55)
        XCTAssertEqual(s.articleMaxWidth, 620); XCTAssertEqual(s.articleHorizontalPadding, 30)
        XCTAssertEqual(s.h1SizeEm, 1.7); XCTAssertEqual(s.h2SizeEm, 1.25); XCTAssertEqual(s.h3SizeEm, 1.1)
        XCTAssertEqual(s.h1TopSpacing, 28); XCTAssertEqual(s.h1BottomSpacing, 18)
        XCTAssertEqual(s.h2TopSpacing, 32); XCTAssertEqual(s.h2BottomSpacing, 12)
        XCTAssertEqual(s.h3TopSpacing, 22); XCTAssertEqual(s.h3BottomSpacing, 8)
        XCTAssertEqual(s.paragraphBottomSpacing, 14)
        XCTAssertEqual(s.rgba.background.hex, "F4EFE3FF"); XCTAssertEqual(s.rgba.text.hex, "42372CFF")
        XCTAssertEqual(s.rgba.heading.hex, "2D2118FF"); XCTAssertEqual(s.rgba.link.hex, "2C5F8DFF")
        XCTAssertEqual(s.rgba.strong, s.rgba.text)                          // tier 1
        XCTAssertEqual(s.rgba.accent.hex, "B0623EFF"); XCTAssertEqual(s.rgba.divider.hex, "E6DEC2FF")
        XCTAssertTrue(s.showH1Rule); XCTAssertFalse(s.showH2Rule)

        let c = MDVTheme.charcoal
        XCTAssertEqual(c.baseFontSize, 16.5); XCTAssertEqual(c.paragraphLineSpacingEm, 0.25); XCTAssertEqual(c.articleMaxWidth, 920)
        XCTAssertEqual(c.h1SizeEm, 1.82); XCTAssertEqual(c.h2SizeEm, 1.39); XCTAssertEqual(c.h3SizeEm, 1.15)
        XCTAssertEqual(c.h1TopSpacing, 0); XCTAssertEqual(c.h1BottomSpacing, 14)
        XCTAssertEqual(c.h2TopSpacing, 26); XCTAssertEqual(c.h2BottomSpacing, 10)
        XCTAssertEqual(c.h3TopSpacing, 18); XCTAssertEqual(c.h3BottomSpacing, 8)
        XCTAssertEqual(c.paragraphBottomSpacing, 11)
        XCTAssertEqual(c.rgba.background.hex, "1E1F25FF"); XCTAssertEqual(c.rgba.text.hex, "C9D1DBFF")
        XCTAssertEqual(c.rgba.strong.hex, "EBF0F7FF"); XCTAssertEqual(c.rgba.heading.hex, "F5F7FCFF")   // tier 2
        XCTAssertEqual(c.rgba.accent.hex, "2E7AEBFF"); XCTAssertEqual(c.rgba.blockquoteBar.hex, "3D4554FF")

        for id in ["solarium-daylight", "solarium-moonlight"] {
            let t = ThemeCatalog.theme(id: id)!
            XCTAssertEqual(t.bodyFontFamily, .custom("Besley")); XCTAssertEqual(t.baseFontSize, 16)
            XCTAssertEqual(t.paragraphLineSpacingEm, 0.20); XCTAssertEqual(t.articleMaxWidth, 720); XCTAssertEqual(t.articleHorizontalPadding, 36)
            XCTAssertEqual(t.h1SizeEm, 1.55); XCTAssertEqual(t.h2SizeEm, 1.28); XCTAssertEqual(t.h3SizeEm, 1.1)
            XCTAssertEqual(t.h1TopSpacing, 24); XCTAssertEqual(t.paragraphBottomSpacing, 16)
            XCTAssertEqual(t.rgba.strong, t.rgba.text)
        }
        for id in ["standard-erin-light", "standard-erin-dark"] {
            let t = ThemeCatalog.theme(id: id)!
            XCTAssertEqual(t.baseFontSize, 15)
            XCTAssertEqual(t.headingFontWeight, .regular); XCTAssertEqual(t.strongFontWeight, .bold)
            XCTAssertEqual(t.paragraphLineSpacingEm, 0.30); XCTAssertEqual(t.articleMaxWidth, 860)
            if case .custom(let family) = t.bodyFontFamily { XCTAssertTrue(family == "OpenDyslexic" || family.hasPrefix("Dyslexie")) } else { XCTFail("custom family expected") }
        }
        XCTAssertEqual(MDVTheme.standardErinLight.rgba.background.hex, "FBF7E8FF")
        XCTAssertEqual(MDVTheme.standardErinDark.rgba.background.hex, "1B2233FF")
    }

    /// C-09: `smartTypographyAllowed` is false for phosphor and the two Standard Erin themes only. R-17, T-10.
    func testSmartTypographyOptOuts() {
        let optOut = MDVTheme.all.filter { !$0.smartTypographyAllowed }.map(\.id)
        XCTAssertEqual(optOut, ["phosphor", "standard-erin-light", "standard-erin-dark"])
    }

    /// `TYPOGRAPHY.md` cross-theme rules: body never equals heading; no pure black or pure white background; every theme
    /// has a code palette (default oneDark for dark, githubLight for light). C-09, I-015.
    func testCrossThemeRules() {
        for t in MDVTheme.all {
            XCTAssertNotEqual(t.rgba.text, t.rgba.heading, t.id)
            XCTAssertNotEqual(t.rgba.background.hex, "000000FF", t.id)
            XCTAssertNotEqual(t.rgba.background.hex, "FFFFFFFF", t.id)
            XCTAssertEqual(t.rgba.text.a, 255)
            XCTAssertFalse(t.codePalette.name.isEmpty, t.id)
        }
        XCTAssertEqual(MDVTheme.highContrast.codePalette.name, "githubLight")
        XCTAssertEqual(MDVTheme.twilight.codePalette.name, "oneDark")
        XCTAssertEqual(MDVTheme.standardErinDark.codePalette.name, "dyslexiaDark")
        XCTAssertEqual(MDVTheme.standardErinLight.codePalette.name, "dyslexiaLight")
    }

    /// C-05: palette lookup by capture-name components (`keyword.function` → `keyword`), plain text for unknown captures;
    /// comments are italic.
    func testCodePaletteLookup() {
        let p = CodePalette.oneDark
        XCTAssertEqual(p.color(forCapture: "keyword.function"), p.color(forCapture: "keyword"))
        XCTAssertEqual(p.color(forCapture: "string.special.path"), p.color(forCapture: "string"))
        XCTAssertNotEqual(p.color(forCapture: "keyword"), p.color(forCapture: "string"))
        XCTAssertNotEqual(p.color(forCapture: "comment"), p.plain)
        XCTAssertEqual(p.color(forCapture: "totally.unknown"), p.plain)
        XCTAssertTrue(p.isItalic(capture: "comment.line"))
        XCTAssertFalse(p.isItalic(capture: "keyword"))
        for name in ["keyword", "string", "comment", "number", "type", "function"] {
            XCTAssertNotEqual(CodePalette.githubLight.color(forCapture: name), CodePalette.githubLight.plain, name)
        }
    }

    /// The bundled fonts register into the process (`TYPOGRAPHY.md`): Alegreya, Besley and OpenDyslexic resolve after registration.
    func testBundledFontsRegister() {
        var failures: [String] = []
        Diagnostics.sink = { failures.append($0) }
        defer { Diagnostics.sink = nil }
        FontRegistration.registerBundledFonts()
        XCTAssertEqual(failures, [])
        for family in ["Alegreya", "Besley", "OpenDyslexic"] {
            XCTAssertNotNil(NSFont(name: family.replacingOccurrences(of: " ", with: "") + "-Regular", size: 12), family)
        }
        XCTAssertNotNil(NSFont(name: "Besley-SemiBold", size: 12))
        XCTAssertNotNil(NSFont(name: "OpenDyslexic-Bold", size: 12))
        XCTAssertTrue(["OpenDyslexic", "Dyslexie", "Dyslexie LT", "Dyslexie Regular"].contains(FontRegistration.dyslexiaBodyFamily))
        XCTAssertEqual(FontRegistration.bundledFontFiles.count, 16)
    }
}
