// DiffHighlighter — C-05.1 line classification for `diff`/`patch` fences (R-50). Rendering is added by W11.
import Foundation

/// C-05.1 line kinds.
public enum DiffLineKind: Equatable, Sendable { case meta, hunkHeader, added, removed, context, note }

public enum DiffHighlighter {
    /// C-05: fence words (the info string's lower-cased first word) that select the classifier instead of tree-sitter.
    public static let fenceWords: Set<String> = ["diff", "patch"]

    /// C-05.1 step 2: `@@ -l[,s] +l[,s] @@…` split on spaces into at most four fields; the counts `s` (omitted → 1).
    public static func hunkCounts(_ line: Substring) -> (old: Int, new: Int)? {
        let fields = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: false)
        guard fields.count >= 3, fields[0] == "@@", fields[1].hasPrefix("-"), fields[2].hasPrefix("+") else { return nil }
        func count(_ f: Substring) -> Int? {
            let parts = f.dropFirst().split(separator: ",", omittingEmptySubsequences: false)
            guard (1...2).contains(parts.count), parts.allSatisfy({ Int($0) != nil }) else { return nil }
            return parts.count == 2 ? Int(parts[1]) : 1
        }
        guard let o = count(fields[1]), let n = count(fields[2]) else { return nil }
        return (o, n)
    }

    /// C-05.1: classify each line with the old/new counters `o`, `n` (inside a hunk while either is positive).
    public static func classify(_ lines: [Substring]) -> [DiffLineKind] {
        var o = 0, n = 0
        return lines.map { line in
            if o > 0 || n > 0 {                                                   // step 1: a hunk body
                switch line.first {
                case "+": n -= 1; return .added
                case "-": o -= 1; return .removed
                case "\\": return .note
                default: o -= 1; n -= 1; return .context
                }
            }
            if let counts = hunkCounts(line) { (o, n) = counts; return .hunkHeader }   // step 2
            if line.hasPrefix("--- ") || line.hasPrefix("+++ ") { return .meta }     // step 3
            switch line.first {
            case "+": return .added
            case "-": return .removed
            case "\\": return .note
            case " ", nil: return .context
            default: return .meta
            }
        }
    }
}

import AppKit
import SwiftUI

/// The diff background of a run, as `RRGGBBAA` (tests read it; SwiftUI reads `backgroundColor`).
public enum DiffBackgroundKey: AttributedStringKey { public typealias Value = String; public static let name = "mdv6.diffBackground" }

extension DiffHighlighter {
    /// C-05.1 styling over `out` (already in the plain colour and the monospace face): added / removed lines take the
    /// theme's diff pair (the background covers the line's characters), hunk headers italic in `secondaryText`, meta
    /// semibold, notes italic in the palette's `comment` colour, context unchanged.
    static func apply(to out: inout AttributedString, code: String, theme: MDVTheme, baseFont: NSFont) {
        let colors = theme.diffColors
        let italic = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        let semibold = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .semibold)
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
        for (line, kind) in zip(lines, classify(lines)) where !line.isEmpty {
            guard let lo = AttributedString.Index(line.startIndex, within: out),
                  let hi = AttributedString.Index(line.endIndex, within: out) else { continue }
            let r = lo ..< hi
            func color(_ c: RGBA) { out[r].foregroundColor = c.color; out[r][CodeRenderer.CaptureColorKey.self] = c.hex }
            func font(_ f: NSFont) { out[r].font = Font(f); out[r][CodeRenderer.FontKey.self] = CodeRenderer.FontSpec(f) }
            switch kind {
            case .added:
                color(colors.add); out[r].backgroundColor = colors.addBackground.color; out[r][DiffBackgroundKey.self] = colors.addBackground.hex
            case .removed:
                color(colors.remove); out[r].backgroundColor = colors.removeBackground.color; out[r][DiffBackgroundKey.self] = colors.removeBackground.hex
            case .hunkHeader: color(theme.rgba.secondaryText); font(italic)
            case .meta: font(semibold)
            case .note: color(theme.codePalette.color(forCapture: "comment")); font(italic)
            case .context: break
            }
        }
    }
}
