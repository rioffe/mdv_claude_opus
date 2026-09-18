// Diagnostics — R-35 / I-003: the only log sink. Takes a closed event set so document content, file contents and
// query strings can never reach a log; every line is prefixed `[mdv6]`.
import Foundation

public enum Diagnostics {
    public enum Event {
        /// E-12: a persistence-store failure (may name the file path and the SQLite message).
        case storeFailure(String)
        /// A bundled-font registration failure (names the font file).
        case fontRegistrationFailure(String)
        /// R-23: an external-editor launch failure (the error text may include the file path).
        case editorLaunchFailure(String)
    }

    /// Test hook: when set, lines go here instead of `NSLog`.
    nonisolated(unsafe) public static var sink: ((String) -> Void)? = nil

    public static func log(_ event: Event) {
        let line: String
        switch event {
        case .storeFailure(let detail): line = "[mdv6] persistence store failure: \(detail)"
        case .fontRegistrationFailure(let detail): line = "[mdv6] font registration failed: \(detail)"
        case .editorLaunchFailure(let detail): line = "[mdv6] external editor launch failed: \(detail)"
        }
        if let sink { sink(line) } else { NSLog("%@", line) }
    }
}
