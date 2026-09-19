// CodeRenderer — C-05: tree-sitter highlighting for the K-05 languages (+ swift/sql, R-38; + cpp/json/lua/
// opencl/perl, R-43), plain monospace for everything else, never an error (R-08); result cache of 256 entries.
import Foundation
import AppKit
import SwiftUI
import SwiftTreeSitter
import CGrammars

public final class CodeRenderer {
    public static let shared = CodeRenderer()
    /// C-05: at most 256 cached results, flushed whole when full.
    public static let cacheLimit = 256
    /// C-05: fence text at 0.85 × `baseFontSize` × zoom.
    public static let fontFactor: CGFloat = 0.85

    /// The capture colour applied to a run (`RRGGBBAA`), for tests and the harness.
    public enum CaptureColorKey: AttributedStringKey { public typealias Value = String; public static let name = "mdv6.captureColor" }
    /// The resolved `NSFont` of a run.
    /// The fence font as a value (`NSFont` is not `Sendable`, and attribute values must be): point size and traits.
    public struct FontSpec: Hashable, Sendable {
        public let pointSize: CGFloat
        public let isMonospace: Bool
        public let isItalic: Bool
        public init(_ font: NSFont) {
            pointSize = font.pointSize
            isMonospace = font.fontDescriptor.symbolicTraits.contains(.monoSpace)
            isItalic = font.fontDescriptor.symbolicTraits.contains(.italic)
        }
    }
    public enum FontKey: AttributedStringKey { public typealias Value = FontSpec; public static let name = "mdv6.font" }

    struct Grammar { let language: Language; let query: Query? }

    private var grammars: [CodeLanguage: Grammar] = [:]
    /// C-05: the embedded grammar of a language that has one (markdown's inline grammar), loaded once.
    private var embeddedGrammars: [CodeLanguage: Grammar] = [:]
    /// C-05: a language whose query failed to compile falls back to plain for the rest of the session.
    public private(set) var plainForSession: Set<CodeLanguage> = []
    private var cache: [CacheKey: AttributedString] = [:]
    private let lock = NSLock()

    struct CacheKey: Hashable { let language: CodeLanguage?; let themeId: String; let zoom: CGFloat; let code: Int }

    public init() {}

    public var cacheCount: Int { lock.lock(); defer { lock.unlock() }; return cache.count }

    static func tsLanguage(_ lang: CodeLanguage) -> OpaquePointer {
        switch lang {
        case .c: return tree_sitter_c()
        case .go: return tree_sitter_go()
        case .rust: return tree_sitter_rust()
        case .bash: return tree_sitter_bash()
        case .javascript: return tree_sitter_javascript()
        case .yaml: return tree_sitter_yaml()
        case .toml: return tree_sitter_toml()
        case .python: return tree_sitter_python()
        case .ruby: return tree_sitter_ruby()
        case .swift: return tree_sitter_swift()
        case .sql: return tree_sitter_sql()
        case .cpp: return tree_sitter_cpp()
        case .json: return tree_sitter_json()
        case .lua: return tree_sitter_lua()
        case .opencl: return tree_sitter_opencl()
        case .perl: return tree_sitter_perl()
        case .markdown: return tree_sitter_markdown()
        }
    }

    /// C-05: markdown is the one language highlighted by two grammars — the block grammar above, then
    /// `tree-sitter-markdown-inline` over each `(inline)` span the block grammar leaves whole. Every other
    /// language has no embedded grammar.
    static func embeddedTSLanguage(_ lang: CodeLanguage) -> OpaquePointer? {
        switch lang {
        case .markdown: return tree_sitter_markdown_inline()
        default: return nil
        }
    }

    /// The embedded grammar (language + compiled query) for a language, loaded once. Its query failing to
    /// compile is not a `plainForSession` case: the block grammar's captures still stand.
    func embeddedGrammar(for lang: CodeLanguage) -> Grammar? {
        lock.lock(); defer { lock.unlock() }
        if let g = embeddedGrammars[lang] { return g }
        guard let ts = CodeRenderer.embeddedTSLanguage(lang) else { return nil }
        let name = "\(lang.rawValue)-inline-highlights.scm"
        let language = Language(language: ts)
        var query: Query? = nil
        if let url = Resources.url(file: name, subdirectory: "Queries"),
           let data = try? Data(contentsOf: url), let q = try? Query(language: language, data: data) {
            query = q
        }
        let g = Grammar(language: language, query: query)
        embeddedGrammars[lang] = g
        return g
    }

    /// The grammar (language + compiled `highlights.scm`) for a language, loaded once.
    func grammar(for lang: CodeLanguage) -> Grammar? {
        lock.lock(); defer { lock.unlock() }
        if let g = grammars[lang] { return g }
        let language = Language(language: CodeRenderer.tsLanguage(lang))
        var query: Query? = nil
        if let url = Resources.url(file: "\(lang.rawValue)-highlights.scm", subdirectory: "Queries"),
           let data = try? Data(contentsOf: url), let q = try? Query(language: language, data: data) {
            query = q
        } else {
            plainForSession.insert(lang)
        }
        let g = Grammar(language: language, query: query)
        grammars[lang] = g
        return g
    }

    /// C-05: synchronous, never throws.
    public func render(code: String, languageHint: String?, theme: MDVTheme, zoom: CGFloat) -> AttributedString {
        let lang = CodeLanguage.resolve(infoString: languageHint)
        let key = CacheKey(language: lang, themeId: theme.id, zoom: zoom, code: code.hashValue)
        lock.lock()
        if let hit = cache[key] { lock.unlock(); return hit }
        lock.unlock()

        let size = CodeRenderer.fontFactor * theme.baseFontSize * zoom
        let baseFont = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        let palette = theme.codePalette
        var out = AttributedString(code)
        out.font = Font(baseFont)
        out.foregroundColor = palette.plain.color
        out[FontKey.self] = FontSpec(baseFont)
        out[CaptureColorKey.self] = palette.plain.hex

        if let lang, let g = grammar(for: lang), let query = g.query, !plainForSession.contains(lang) {
            let parser = Parser()                                       // C-05: a fresh Parser per call
            if (try? parser.setLanguage(g.language)) != nil {
                PipelineProbe.enter("treesitter")
                if let tree = parser.parse(code) {
                    var assigned = Set<NSRange>()                              // first capture of a node wins (tree-sitter convention)
                    apply(query, tree: tree, code: code, source: code, offset: 0,
                          to: &out, palette: palette, italicFont: italicFont, assigned: &assigned)
                    // C-05: markdown — re-parse each `(inline)` span with the inline grammar and colour it too,
                    // after the block captures so an inline capture wins on its own range.
                    if let embedded = embeddedGrammar(for: lang), let eQuery = embedded.query, let root = tree.rootNode {
                        let inlineParser = Parser()
                        if (try? inlineParser.setLanguage(embedded.language)) != nil {
                            for node in CodeRenderer.nodes(named: "inline", in: root) {
                                guard let span = Range(node.range, in: code) else { continue }
                                let source = String(code[span])
                                guard let subTree = inlineParser.parse(source) else { continue }
                                apply(eQuery, tree: subTree, code: code, source: source, offset: node.range.location,
                                      to: &out, palette: palette, italicFont: italicFont, assigned: &assigned)
                            }
                        }
                    }
                }
            }
        }
        lock.lock()
        if cache.count >= CodeRenderer.cacheLimit { cache.removeAll() }
        cache[key] = out
        lock.unlock()
        return out
    }

    /// C-05: colour one query's captures. `source` is the text the query ran on (the predicate context);
    /// `code` is the whole block, and `offset` the position of `source` in it, so an embedded grammar's
    /// captures land on the right characters.
    private func apply(_ query: Query, tree: MutableTree, code: String, source: String, offset: Int,
                       to out: inout AttributedString, palette: CodePalette, italicFont: NSFont,
                       assigned: inout Set<NSRange>) {
        let cursor = query.execute(in: tree)
        let context = Predicate.Context(string: source)
        while let match = cursor.next() {
            guard match.allowed(in: context) else { continue }        // #eq? / #match? / #any-of? predicates
            for capture in match.captures {
                var range = capture.range
                range.location += offset
                guard let name = capture.name, palette.knows(capture: name),   // `@spell`-style captures carry no colour
                      !assigned.contains(range), let r = Range(range, in: code),
                      let lo = AttributedString.Index(r.lowerBound, within: out),
                      let hi = AttributedString.Index(r.upperBound, within: out), lo < hi else { continue }
                assigned.insert(range)
                let color = palette.color(forCapture: name)
                out[lo..<hi].foregroundColor = color.color
                out[lo..<hi][CaptureColorKey.self] = color.hex
                if palette.isItalic(capture: name) {
                    out[lo..<hi].font = Font(italicFont)
                    out[lo..<hi][FontKey.self] = FontSpec(italicFont)
                }
            }
        }
    }

    /// Every node of a type in a tree, depth first.
    static func nodes(named type: String, in node: Node) -> [Node] {
        var found: [Node] = []
        func walk(_ node: Node) {
            if node.nodeType == type { found.append(node) }
            for i in 0..<node.childCount { if let child = node.child(at: i) { walk(child) } }
        }
        walk(node)
        return found
    }
}
