// PipelineProbe — R-41 / I-002 evidence hook: called immediately before every third-party parser or decoder entry
// ("mermaid", "math", "image", "treesitter"), so tests can prove that oversized content never reaches one (T-41).
import Foundation

public enum PipelineProbe {
    nonisolated(unsafe) public static var onParserEntry: ((String) -> Void)? = nil

    @inline(__always) static func enter(_ parser: String) { onParserEntry?(parser) }
}
