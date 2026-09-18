// FTSQuery — C-03 query construction and the search constants (R-25, K-03, K-09, E-24, D-36).
import Foundation

public enum FTSQuery {
    /// K-03: at most 80 hits.
    public static let limit = 80
    /// K-03: snippets are 14 tokens.
    public static let snippetTokens = 14
    /// C-03, D-36: rank, then case-insensitive path, then binary path — deterministic at the 80-row boundary.
    public static let orderBy = "ORDER BY rank ASC, path COLLATE NOCASE ASC, path ASC"
    /// K-09.
    public static let tokenizer = "unicode61 remove_diacritics 2"

    static let dropped: Set<Character> = ["\"", "(", ")", ":", "*", "^"]

    /// C-03: split on whitespace; drop `" ( ) : * ^` from each token; discard empties; wrap as `"token"*`; join with
    /// spaces. Nil when no token survives (E-24: no search is performed).
    public static func make(_ input: String) -> String? {
        let tokens = input.split(whereSeparator: { $0.isWhitespace })
            .map { String($0.filter { !dropped.contains($0) }) }
            .filter { !$0.isEmpty }
        if tokens.isEmpty { return nil }
        return tokens.map { "\"\($0)\"*" }.joined(separator: " ")
    }
}
