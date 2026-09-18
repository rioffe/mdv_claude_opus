// CodeLanguage — C-05 language resolution, the prompt-aware fence set and Copy Without Prompts (R-08, K-05, R-38).
import Foundation

public enum CodeLanguage: String, CaseIterable, Sendable {
    case c, go, rust, bash, javascript, yaml, toml, python, ruby, swift, sql

    static let aliases: [String: CodeLanguage] = [
        "js": .javascript, "jsx": .javascript, "javascriptreact": .javascript, "node": .javascript,
        "sh": .bash, "zsh": .bash, "shell": .bash,
        "py": .python, "python3": .python,
        "rb": .ruby, "yml": .yaml, "rs": .rust, "golang": .go,
        "h": .c, "objective-c": .c, "objc": .c,
        "sqlite": .sql, "postgresql": .sql, "postgres": .sql, "mysql": .sql, "plsql": .sql, "tsql": .sql,
    ]

    /// C-05: lower-case the info string, keep its first word; direct names, then aliases; anything else → nil (plain).
    public static func resolve(infoString: String?) -> CodeLanguage? {
        guard let word = firstWord(infoString) else { return nil }
        return CodeLanguage(rawValue: word) ?? aliases[word]
    }

    /// C-05 prompt-aware fence words — a separate test on the raw first word (`fish`/`console` highlight as plain).
    static let promptAware: Set<String> = ["bash", "sh", "zsh", "fish", "shell", "console"]

    public static func isPromptAware(infoString: String?) -> Bool {
        guard let word = firstWord(infoString) else { return false }
        return promptAware.contains(word)
    }

    /// R-08: at least half of the non-empty lines start with `$ ` or `# `.
    public static func isPrompted(code: String) -> Bool {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.allSatisfy(\.isWhitespace) }
        guard !lines.isEmpty else { return false }
        let prompted = lines.filter { isPromptLine($0) }.count
        return prompted * 2 >= lines.count
    }

    /// R-08 Copy Without Prompts: the leading `$ `/`# ` removed from each prompted line; every other line unchanged.
    public static func stripPrompts(_ code: String) -> String {
        code.split(separator: "\n", omittingEmptySubsequences: false)
            .map { isPromptLine($0) ? String($0.dropFirst(2)) : String($0) }
            .joined(separator: "\n")
    }

    /// The block label: the raw first word lower-cased, or `text`.
    public static func label(infoString: String?) -> String { firstWord(infoString) ?? "text" }

    static func isPromptLine(_ line: Substring) -> Bool { line.hasPrefix("$ ") || line.hasPrefix("# ") }

    static func firstWord(_ info: String?) -> String? {
        guard let info else { return nil }
        guard let word = info.split(whereSeparator: { $0.isWhitespace }).first else { return nil }
        return word.lowercased()
    }
}
