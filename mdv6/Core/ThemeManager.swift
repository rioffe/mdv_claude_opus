// ThemeManager — C-09 `MDVTheme`, the nine themes of `TYPOGRAPHY.md` (K-10), `ThemeCatalog` resolution (R-29, C-04),
// `CodePalette` (C-05) and `FontRegistration`. The observable manager that holds the live choice is added by W6.
import Foundation
import AppKit
import SwiftUI

// MARK: - Palette

/// The C-09 colour slots as 8-bit RGBA (the harness and the rhythm metric read these; views read the `Color`s).
public struct ThemePalette: Equatable, Sendable {
    public var text, secondaryText, tertiaryText, heading, strong, link, accent, background, secondaryBackground, border, divider, blockquoteBar: RGBA
}

/// C-09 `bodyFontFamily`.
public enum FontFamily: Equatable, Sendable {
    case system
    case custom(String)
}

/// C-05: the code-highlighting colours a theme uses, looked up by capture-name components.
public struct CodePalette: Equatable, Sendable {
    public let name: String
    public let plain: RGBA
    public let captures: [String: RGBA]     // "keyword", "string", "comment", "number", "type", "function", …

    /// `keyword.function` → `keyword.function`, then `keyword`; unknown → plain.
    public func color(forCapture capture: String) -> RGBA {
        var parts = capture.split(separator: ".").map(String.init)
        while !parts.isEmpty {
            if let c = captures[parts.joined(separator: ".")] { return c }
            parts.removeLast()
        }
        return plain
    }

    /// C-05: `comment` captures are italic.
    public func isItalic(capture: String) -> Bool { capture == "comment" || capture.hasPrefix("comment.") }

    static func make(_ name: String, plain: String, _ map: [String: String]) -> CodePalette {
        CodePalette(name: name, plain: RGBA(hex: plain)!, captures: map.mapValues { RGBA(hex: $0)! })
    }

    public static let oneDark = make("oneDark", plain: "ABB2BF", [
        "keyword": "C678DD", "string": "98C379", "comment": "5C6370", "number": "D19A66", "constant": "D19A66",
        "type": "E5C07B", "function": "61AFEF", "variable": "E06C75", "property": "E06C75", "operator": "56B6C2",
        "attribute": "D19A66", "punctuation": "ABB2BF", "tag": "E06C75", "label": "E06C75", "embedded": "ABB2BF",
    ])
    public static let githubLight = make("githubLight", plain: "24292F", [
        "keyword": "CF222E", "string": "0A3069", "comment": "6E7781", "number": "0550AE", "constant": "0550AE",
        "type": "953800", "function": "8250DF", "variable": "24292F", "property": "0550AE", "operator": "CF222E",
        "attribute": "0550AE", "punctuation": "24292F", "tag": "116329", "label": "953800", "embedded": "24292F",
    ])
    /// `TYPOGRAPHY.md` Standard Erin: low-saturation warm band; no saturated reds, no pure greens.
    public static let dyslexiaLight = make("dyslexiaLight", plain: "2C2A26", [
        "keyword": "6E4B6E", "string": "3D6B5C", "comment": "8A8378", "number": "7A5230", "constant": "7A5230",
        "type": "5A4A7A", "function": "1B4F8A", "variable": "2C2A26", "property": "5A4A7A", "operator": "6E4B6E",
        "attribute": "B0623E", "punctuation": "2C2A26", "tag": "6E4B6E", "label": "7A5230",
    ])
    /// No greens, no reds: warm cream / dusty amber with one cool dusty blue for functions.
    public static let dyslexiaDark = make("dyslexiaDark", plain: "E5DCC5", [
        "keyword": "C99A4A", "string": "E8D5A6", "comment": "8F8874", "number": "EBCF9E", "constant": "EBCF9E",
        "type": "F5C97A", "function": "9DB4D0", "variable": "E5DCC5", "property": "F5C97A", "operator": "C99A4A",
        "attribute": "C99A4A", "punctuation": "E5DCC5", "tag": "C99A4A", "label": "EBCF9E",
    ])
}

// MARK: - MDVTheme (C-09)

public struct MDVTheme: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isDark: Bool
    public let rgba: ThemePalette

    public var bodyFontFamily: FontFamily
    public var baseFontSize: CGFloat                        // default 16 (K-10)
    public var paragraphLineSpacingEm: CGFloat = 0.30        // K-10
    public var h1SizeEm: CGFloat = 1.75, h2SizeEm: CGFloat = 1.4, h3SizeEm: CGFloat = 1.15
    public let h4SizeEm: CGFloat = 1.0, h5SizeEm: CGFloat = 0.875, h6SizeEm: CGFloat = 0.85   // fixed
    public var articleMaxWidth: CGFloat? = 860
    public var articleHorizontalPadding: CGFloat = 40
    public var showH1Rule = true
    public var showH2Rule = false
    /// `TYPOGRAPHY.md` per-element vertical spacing (MarkdownUI's GitHub-mirror defaults); I-014 reads these.
    public var h1TopSpacing: CGFloat = 24, h1BottomSpacing: CGFloat = 16
    public var h2TopSpacing: CGFloat = 24, h2BottomSpacing: CGFloat = 16
    public var h3TopSpacing: CGFloat = 24, h3BottomSpacing: CGFloat = 16
    public var paragraphBottomSpacing: CGFloat = 16
    public var headingFontWeight: Font.Weight = .semibold
    public var strongFontWeight: Font.Weight = .semibold
    public var smartTypographyAllowed = true                 // false for phosphor, standard-erin-light, standard-erin-dark
    public var codePalette: CodePalette

    /// C-09: `[h1…h6]`, used by the Markdown theme and by math in headings (R-13).
    public var headingSizeEms: [CGFloat] { [h1SizeEm, h2SizeEm, h3SizeEm, h4SizeEm, h5SizeEm, h6SizeEm] }

    // C-09 `Color` fields
    public var text: Color { rgba.text.color }
    public var secondaryText: Color { rgba.secondaryText.color }
    public var tertiaryText: Color { rgba.tertiaryText.color }
    public var heading: Color { rgba.heading.color }
    public var strong: Color { rgba.strong.color }
    public var link: Color { rgba.link.color }
    public var accent: Color { rgba.accent.color }
    public var background: Color { rgba.background.color }
    public var secondaryBackground: Color { rgba.secondaryBackground.color }
    public var border: Color { rgba.border.color }
    public var divider: Color { rgba.divider.color }
    public var blockquoteBar: Color { rgba.blockquoteBar.color }

    init(id: String, name: String, isDark: Bool, rgba: ThemePalette, bodyFontFamily: FontFamily = .system,
         baseFontSize: CGFloat = 16, codePalette: CodePalette? = nil) {
        self.id = id; self.name = name; self.isDark = isDark; self.rgba = rgba
        self.bodyFontFamily = bodyFontFamily; self.baseFontSize = baseFontSize
        self.codePalette = codePalette ?? (isDark ? .oneDark : .githubLight)
    }

    // MARK: the nine themes (TYPOGRAPHY.md)

    /// Defaults + tier-1 strong + system-blue accent. Near-black on near-white (never pure values).
    public static let highContrast: MDVTheme = {
        let p = palette(text: "1A1A1A", secondaryText: "4A4A4A", tertiaryText: "7A7A7A", heading: "000000", strong: "1A1A1A",
                        link: "0B57D0", accent: "007AFF", background: "FCFCFA", secondaryBackground: "F0F0EC",
                        border: "D9D9D4", divider: "D9D9D4", blockquoteBar: "007AFF")
        return MDVTheme(id: "high-contrast", name: "High Contrast", isDark: false, rgba: p)
    }()

    /// Long-form reading theme: Alegreya, 17 pt, 0.55 em, 620 pt, terracotta accent, faded H1 rule.
    public static let sevilla: MDVTheme = {
        let p = palette(text: "42372C", secondaryText: "6A5C4D", tertiaryText: "968874", heading: "2D2118", strong: "42372C",
                        link: "2C5F8D", accent: "B0623E", background: "F4EFE3", secondaryBackground: "EAE5D6",
                        border: "E6DEC2", divider: "E6DEC2", blockquoteBar: "B0623E")
        var t = MDVTheme(id: "sevilla", name: "Sevilla", isDark: false, rgba: p, bodyFontFamily: .custom("Alegreya"), baseFontSize: 17)
        t.paragraphLineSpacingEm = 0.55
        t.articleMaxWidth = 620; t.articleHorizontalPadding = 30
        t.h1SizeEm = 1.7; t.h2SizeEm = 1.25; t.h3SizeEm = 1.1
        t.h1TopSpacing = 28; t.h1BottomSpacing = 18
        t.h2TopSpacing = 32; t.h2BottomSpacing = 12
        t.h3TopSpacing = 22; t.h3BottomSpacing = 8
        t.paragraphBottomSpacing = 14
        return t
    }()

    /// "GitHub README, dark, all business": SF Pro 16.5, 0.25 em, 920 pt, operational rhythm, muted-blue accent.
    public static let charcoal: MDVTheme = {
        let p = palette(text: "C9D1DB", secondaryText: "94A1B0", tertiaryText: "6E7785", heading: "F5F7FC", strong: "EBF0F7",
                        link: "5CA3FA", accent: "2E7AEB", background: "1E1F25", secondaryBackground: "2E303B",
                        border: "3D4554", divider: "3D4554", blockquoteBar: "3D4554")
        var t = MDVTheme(id: "charcoal", name: "Charcoal", isDark: true, rgba: p, baseFontSize: 16.5)
        t.paragraphLineSpacingEm = 0.25
        t.articleMaxWidth = 920
        t.h1SizeEm = 1.82; t.h2SizeEm = 1.39; t.h3SizeEm = 1.15
        t.h1TopSpacing = 0; t.h1BottomSpacing = 14
        t.h2TopSpacing = 26; t.h2BottomSpacing = 10
        t.h3TopSpacing = 18; t.h3BottomSpacing = 8
        t.paragraphBottomSpacing = 11
        return t
    }()

    /// Solarized Light palette wearing Besley: 16 pt, 0.20 em, 720 pt, 36 pt gutter, 1.55/1.28/1.1, orange accent.
    public static let solariumDaylight: MDVTheme = {
        let p = palette(text: "586E75", secondaryText: "657B83", tertiaryText: "93A1A1", heading: "073642", strong: "586E75",
                        link: "268BD2", accent: "CB4B16", background: "FDF6E3", secondaryBackground: "EEE8D5",
                        border: "E3DCC5", divider: "E3DCC5", blockquoteBar: "CB4B16")
        var t = MDVTheme(id: "solarium-daylight", name: "Solarium Daylight", isDark: false, rgba: p, bodyFontFamily: .custom("Besley"))
        solarium(&t)
        return t
    }()

    /// Solarized Dark palette wearing Besley; yellow accent; strong at tier 1.
    public static let solariumMoonlight: MDVTheme = {
        let p = palette(text: "93A1A1", secondaryText: "839496", tertiaryText: "657B83", heading: "EEE8D5", strong: "93A1A1",
                        link: "268BD2", accent: "B58900", background: "002B36", secondaryBackground: "073642",
                        border: "0E4250", divider: "0E4250", blockquoteBar: "B58900")
        var t = MDVTheme(id: "solarium-moonlight", name: "Solarium Moonlight", isDark: true, rgba: p, bodyFontFamily: .custom("Besley"))
        solarium(&t)
        return t
    }()

    private static func solarium(_ t: inout MDVTheme) {
        t.paragraphLineSpacingEm = 0.20
        t.articleMaxWidth = 720; t.articleHorizontalPadding = 36
        t.h1SizeEm = 1.55; t.h2SizeEm = 1.28; t.h3SizeEm = 1.1
    }

    /// Defaults + amber accent (CRT vibe); a dark green-on-black-ish phosphor page; smart typography off.
    public static let phosphor: MDVTheme = {
        let p = palette(text: "9FE89F", secondaryText: "6DBF6D", tertiaryText: "4E8F4E", heading: "C8FFC8", strong: "9FE89F",
                        link: "FFD166", accent: "FFB000", background: "0B120B", secondaryBackground: "142014",
                        border: "1F3320", divider: "1F3320", blockquoteBar: "FFB000")
        var t = MDVTheme(id: "phosphor", name: "Phosphor", isDark: true, rgba: p)
        t.smartTypographyAllowed = false
        return t
    }()

    /// Defaults + cream accent; strong at tier 2 (lifted). The System theme's Dark resolution (R-29).
    public static let twilight: MDVTheme = {
        let p = palette(text: "D6D3CB", secondaryText: "A29F97", tertiaryText: "77756F", heading: "F5F2EA", strong: "EAE6DC",
                        link: "9DC1F0", accent: "F2E4C8", background: "22242B", secondaryBackground: "2E3038",
                        border: "3C3F49", divider: "3C3F49", blockquoteBar: "F2E4C8")
        return MDVTheme(id: "twilight", name: "Twilight", isDark: true, rgba: p)
    }()

    /// OpenDyslexic (or the installed Dyslexie) at 15 pt; regular headings, bold strong; cream page; smart typography off.
    public static let standardErinLight: MDVTheme = {
        let p = palette(text: "2C2A26", secondaryText: "5C5850", tertiaryText: "8A8378", heading: "1E1C19", strong: "2C2A26",
                        link: "1B4F8A", accent: "B0623E", background: "FBF7E8", secondaryBackground: "F1ECDA",
                        border: "E4DEC8", divider: "E4DEC8", blockquoteBar: "B0623E")
        var t = MDVTheme(id: "standard-erin-light", name: "Standard Erin Light", isDark: false, rgba: p,
                         bodyFontFamily: .custom(FontRegistration.dyslexiaBodyFamily), baseFontSize: 15, codePalette: .dyslexiaLight)
        standardErin(&t)
        return t
    }()

    public static let standardErinDark: MDVTheme = {
        let p = palette(text: "E5DCC5", secondaryText: "B8B09C", tertiaryText: "8F8874", heading: "F5EEDC", strong: "E5DCC5",
                        link: "F5C97A", accent: "C99A4A", background: "1B2233", secondaryBackground: "262E42",
                        border: "343D55", divider: "343D55", blockquoteBar: "C99A4A")
        var t = MDVTheme(id: "standard-erin-dark", name: "Standard Erin Dark", isDark: true, rgba: p,
                         bodyFontFamily: .custom(FontRegistration.dyslexiaBodyFamily), baseFontSize: 15, codePalette: .dyslexiaDark)
        standardErin(&t)
        return t
    }()

    private static func standardErin(_ t: inout MDVTheme) {
        t.headingFontWeight = .regular
        t.strongFontWeight = .bold
        t.smartTypographyAllowed = false
    }

    /// C-09 order.
    public static let all: [MDVTheme] = [highContrast, sevilla, charcoal, solariumDaylight, solariumMoonlight, phosphor, twilight,
                                         standardErinLight, standardErinDark]

    private static func palette(text: String, secondaryText: String, tertiaryText: String, heading: String, strong: String,
                                link: String, accent: String, background: String, secondaryBackground: String, border: String,
                                divider: String, blockquoteBar: String) -> ThemePalette {
        ThemePalette(text: RGBA(hex: text)!, secondaryText: RGBA(hex: secondaryText)!, tertiaryText: RGBA(hex: tertiaryText)!,
                     heading: RGBA(hex: heading)!, strong: RGBA(hex: strong)!, link: RGBA(hex: link)!, accent: RGBA(hex: accent)!,
                     background: RGBA(hex: background)!, secondaryBackground: RGBA(hex: secondaryBackground)!,
                     border: RGBA(hex: border)!, divider: RGBA(hex: divider)!, blockquoteBar: RGBA(hex: blockquoteBar)!)
    }
}

// MARK: - ThemeCatalog (R-29, C-04)

public enum ThemeCatalog {
    public static let systemId = "system"
    public static let defaultId = "high-contrast"

    public static func theme(id: String) -> MDVTheme? { MDVTheme.all.first { $0.id == id } }

    /// R-29: `system` → `high-contrast` in Light, `twilight` in Dark; C-04: an unknown id resolves to `high-contrast`.
    public static func resolve(id: String, isDarkAppearance: Bool) -> MDVTheme {
        if id == systemId { return isDarkAppearance ? MDVTheme.twilight : MDVTheme.highContrast }
        return theme(id: id) ?? MDVTheme.highContrast
    }
}

// MARK: - Colours

extension RGBA {
    public var color: Color { Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255) }
    public var nsColor: NSColor { NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255) }
    public var cgColor: CGColor { nsColor.cgColor }
}

// MARK: - Resources and fonts

/// Locates bundled resources: the flat `Contents/Resources` layout of the app bundle (C-01/C-13) first, then the
/// SwiftPM resource bundle (`swift run`, `swift test`).
public enum Resources {
    public static func url(file: String, subdirectory: String?) -> URL? {
        if let main = Bundle.main.resourceURL {
            let flat = main.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: flat.path) { return flat }
        }
        let name = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        return Bundle.module.url(forResource: name, withExtension: ext.isEmpty ? nil : ext, subdirectory: subdirectory)
    }
}

public enum FontRegistration {
    /// The sixteen bundled faces (`mdv6/Fonts`, `TYPOGRAPHY.md`).
    public static let bundledFontFiles: [String] = [
        "Alegreya-Regular.otf", "Alegreya-Italic.otf", "Alegreya-Medium.otf", "Alegreya-Bold.otf", "Alegreya-BoldItalic.otf", "Alegreya-ExtraBold.otf",
        "Besley-Regular.otf", "Besley-Italic.otf", "Besley-SemiBold.otf", "Besley-SemiBoldItalic.otf", "Besley-Bold.otf", "Besley-BoldItalic.otf",
        "OpenDyslexic-Regular.otf", "OpenDyslexic-Italic.otf", "OpenDyslexic-Bold.otf", "OpenDyslexic-BoldItalic.otf",
    ]

    nonisolated(unsafe) private static var registered = false

    /// Registers the bundled fonts into the process-local font space once (never installed on the system).
    /// A failure is reported through `Diagnostics` (R-35) and never stops the launch.
    public static func registerBundledFonts() {
        if registered { return }
        registered = true
        for file in bundledFontFiles {
            guard let url = Resources.url(file: file, subdirectory: "Fonts") else {
                Diagnostics.log(.fontRegistrationFailure("\(file) not found"))
                continue
            }
            var error: Unmanaged<CFError>? = nil
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                let code = (error?.takeRetainedValue() as Error?).map { ($0 as NSError).code } ?? 0
                // 305 = already registered (a second test process in the same host); not a failure.
                if code != 305 { Diagnostics.log(.fontRegistrationFailure("\(file): CTFontManager error \(code)")) }
            }
        }
    }

    /// `TYPOGRAPHY.md`: `Dyslexie` (or `Dyslexie LT` / `Dyslexie Regular`) when the user has it installed, else `OpenDyslexic`.
    /// Resolved at first access and sticky for the session.
    public static let dyslexiaBodyFamily: String = {
        registerBundledFonts()
        for candidate in ["Dyslexie", "Dyslexie LT", "Dyslexie Regular"] where NSFontManager.shared.availableFontFamilies.contains(candidate) {
            return candidate
        }
        return "OpenDyslexic"
    }()
}
