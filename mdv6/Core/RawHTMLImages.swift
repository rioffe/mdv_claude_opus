// RawHTMLImages — C-22.1 `<img>` → `mdv6-img://` rewrite and C-22.2 display size (R-51, E-35).
import Foundation

/// One `<img>` tag as carried by `mdv6-img://<base64url(src)>?a=<base64url(alt)>&w=<w>&h=<h>` (C-22.1).
public struct HTMLImageSpec: Hashable, Sendable {
    public static let scheme = "mdv6-img"
    public let src: String
    public let alt: String
    public let width: CGFloat?
    public let height: CGFloat?

    public init(src: String, alt: String, width: CGFloat?, height: CGFloat?) {
        self.src = src; self.alt = alt; self.width = width; self.height = height
    }

    /// C-22.1: each query item present only when its attribute is (`a` only for a non-empty `alt`); sizes to 1 decimal.
    public var url: String {
        var q: [String] = []
        if !alt.isEmpty { q.append("a=\(MathMarkdown.base64url(alt))") }
        if let width { q.append("w=\(String(format: "%.1f", Double(width)))") }
        if let height { q.append("h=\(String(format: "%.1f", Double(height)))") }
        return "\(Self.scheme)://\(MathMarkdown.base64url(src))" + (q.isEmpty ? "" : "?" + q.joined(separator: "&"))
    }

    /// Decodes an `mdv6-img://` URL from its string form (a URL host may be case-folded, the payload must not be).
    public init?(url: URL) {
        let s = url.absoluteString
        let prefix = Self.scheme + "://"
        guard s.hasPrefix(prefix) else { return nil }
        let rest = s.dropFirst(prefix.count)
        let payload = rest.prefix { $0 != "?" && $0 != "/" }
        guard let src = MathMarkdown.base64urlDecode(String(payload)) else { return nil }
        var items: [String: String] = [:]
        if let qi = rest.firstIndex(of: "?") {
            for pair in rest[rest.index(after: qi)...].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 { items[String(kv[0])] = String(kv[1]) }
            }
        }
        self.src = src
        self.alt = items["a"].flatMap(MathMarkdown.base64urlDecode) ?? ""
        self.width = items["w"].flatMap(Double.init).map { CGFloat($0) }
        self.height = items["h"].flatMap(Double.init).map { CGFloat($0) }
    }

    /// C-22.2: caps, never enlarging — both → (min(w, h·r), min(h, w/r)); width → (min(w, w0), …); height → (…, min(h, h0)).
    public func displaySize(natural n: CGSize) -> CGSize {
        guard n.width > 0, n.height > 0 else { return n }
        let r = n.width / n.height
        switch (width, height) {
        case let (w?, h?): return CGSize(width: min(w, h * r), height: min(h, w / r))
        case let (w?, nil): let w2 = min(w, n.width); return CGSize(width: w2, height: w2 / r)
        case let (nil, h?): let h2 = min(h, n.height); return CGSize(width: h2 * r, height: h2)
        case (nil, nil): return n
        }
    }

    /// C-22.2: a URL with a scheme is used as it is; otherwise a path resolved against the document's directory (R-16).
    public func resolvedURL(baseURL: URL?) -> URL {
        if let u = URL(string: src), let scheme = u.scheme, !scheme.isEmpty, scheme.count > 1 { return u }
        if src.hasPrefix("/") { return URL(fileURLWithPath: src).standardizedFileURL }
        guard let baseURL else { return URL(fileURLWithPath: src).standardizedFileURL }
        return URL(fileURLWithPath: src, relativeTo: baseURL).standardizedFileURL
    }
}

public enum RawHTMLImages {

    /// C-22.1: rewrite every `<img …>` outside code in one prose block; fenced blocks and blocks without `<img` unchanged.
    public static func rewrite(_ block: String) -> String {
        transform(block) { tag in tagSpec(tag).map { "![](\($0.url))" } ?? tag }
    }

    /// C-12 step (0): remove every `<img …>` tag outside code spans (F-171).
    public static func stripTags(_ s: String) -> String {
        transform(s) { tag in tagSpec(tag) != nil || tag.lowercased().hasPrefix("<img") ? "" : tag }
    }

    /// Scans left to right, copying code spans verbatim (a run of k backticks closes only on a run of exactly k, as
    /// C-07.1), and hands each `<img …>` candidate — up to the first `>` not inside a quoted value — to `replace`.
    static func transform(_ block: String, replace: (String) -> String) -> String {
        guard block.contains("<img") else { return block }
        let head = block.drop(while: { $0 == " " || $0 == "\t" })
        if head.hasPrefix("```") || head.hasPrefix("~~~") { return block }
        let chars = Array(block)
        var out = ""
        var i = 0
        var codeRun = 0
        while i < chars.count {
            let c = chars[i]
            if c == "`" {
                var run = 0
                while i < chars.count, chars[i] == "`" { out.append("`"); run += 1; i += 1 }
                if codeRun == 0 { codeRun = run } else if run == codeRun { codeRun = 0 }
                continue
            }
            if codeRun > 0 || c != "<" || i + 4 > chars.count || String(chars[i ..< i + 4]) != "<img" {
                out.append(c); i += 1; continue
            }
            guard let close = closingBracket(chars, from: i + 4) else { out.append(c); i += 1; continue }
            out += replace(String(chars[i ... close]))
            i = close + 1
        }
        return out
    }

    /// The first `>` after `from` that is not inside a `"…"` or `'…'` value (F-171).
    static func closingBracket(_ chars: [Character], from: Int) -> Int? {
        var quote: Character? = nil
        var j = from
        while j < chars.count {
            let c = chars[j]
            if let q = quote { if c == q { quote = nil } } else if c == "\"" || c == "'" { quote = c } else if c == ">" { return j }
            j += 1
        }
        return nil
    }

    /// `src`, `alt`, `width`, `height` off one tag; nil when `src` is missing or empty (E-35: the tag stays literal).
    static func tagSpec(_ tag: String) -> HTMLImageSpec? {
        let attrs = attributes(tag)
        guard let src = attrs["src"], !src.isEmpty else { return nil }
        return HTMLImageSpec(src: src, alt: attrs["alt"] ?? "", width: length(attrs["width"]), height: length(attrs["height"]))
    }

    /// Case-insensitive `name="…"`, `name='…'` or bare `name=value` (ending at whitespace, `>` or a quote).
    static func attributes(_ tag: String) -> [String: String] {
        let chars = Array(tag.dropFirst(4))
        var out: [String: String] = [:]
        var i = 0
        func skipSpace() { while i < chars.count, chars[i].isWhitespace { i += 1 } }
        while i < chars.count {
            skipSpace()
            var name = ""
            while i < chars.count, chars[i].isLetter || chars[i] == "-" { name.append(chars[i]); i += 1 }
            if name.isEmpty { i += 1; continue }
            skipSpace()
            guard i < chars.count, chars[i] == "=" else { continue }
            i += 1
            skipSpace()
            var value = ""
            if i < chars.count, chars[i] == "\"" || chars[i] == "'" {
                let q = chars[i]; i += 1
                while i < chars.count, chars[i] != q { value.append(chars[i]); i += 1 }
                i += 1
            } else {
                while i < chars.count, !chars[i].isWhitespace, chars[i] != ">", chars[i] != "\"", chars[i] != "'" {
                    value.append(chars[i]); i += 1
                }
            }
            let key = name.lowercased()
            if out[key] == nil { out[key] = value }
        }
        return out
    }

    /// C-22.1: drop a case-insensitive `px`; the value must parse as a number > 0, else it is absent.
    static func length(_ raw: String?) -> CGFloat? {
        guard let raw else { return nil }
        let digits = raw.replacingOccurrences(of: "px", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
        guard let v = Double(digits), v > 0, v.isFinite else { return nil }
        return CGFloat(v)
    }
}
