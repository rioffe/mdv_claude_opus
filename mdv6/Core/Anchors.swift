// Anchors — C-08: block fingerprints and anchor resolution for bookmarks and scroll positions (K-09, E-08, D-35).
import Foundation

/// C-08: split at every Unicode whitespace scalar, drop empty pieces, join with U+0020, locale-independent lowercase
/// without normalisation, first 80 extended grapheme clusters (K-09).
public func bookmarkFingerprint(_ block: String) -> String {
    var pieces: [String] = []
    var current = String.UnicodeScalarView()
    for scalar in block.unicodeScalars {
        if scalar.properties.isWhitespace {
            if !current.isEmpty { pieces.append(String(current)); current = String.UnicodeScalarView() }
        } else {
            current.append(scalar)
        }
    }
    if !current.isEmpty { pieces.append(String(current)) }
    let joined = pieces.joined(separator: " ").lowercased()
    return String(joined.prefix(80))
}

/// C-08 equality is byte-wise (scalar sequence), never canonical: byte-distinct combining sequences stay distinct (D-35).
public func fingerprintsEqual(_ a: String, _ b: String) -> Bool {
    a.unicodeScalars.elementsEqual(b.unicodeScalars)
}

/// C-08: the first block whose fingerprint equals the stored one; else `storedIndex` clamped to `[0, count-1]`; else 0.
public func resolveBookmarkAnchor(blocks: [String], storedIndex: Int, fingerprint: String) -> Int {
    if blocks.isEmpty { return 0 }
    if !fingerprint.isEmpty, let i = blocks.firstIndex(where: { fingerprintsEqual(bookmarkFingerprint($0), fingerprint) }) { return i }
    return min(max(storedIndex, 0), blocks.count - 1)
}

/// C-08, E-08, K-06: scroll restoration validity.
public enum AnchorValidity {
    /// Whole seconds (K-06).
    public static let mtimeTolerance = 1

    public static func scrollRestorable(storedMtime: Int, fileMtime: Int, index: Int, count: Int) -> Bool {
        abs(storedMtime - fileMtime) <= mtimeTolerance && index >= 0 && index < count
    }
}
