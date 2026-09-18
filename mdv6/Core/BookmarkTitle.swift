// BookmarkTitle — the R-27 title rule (K-06 look-back and truncation), shared by bookmarks and the placeholder (R-28).
import Foundation

public enum BookmarkTitle {
    /// R-27, K-06: the nearest TOC heading at or within this many previous blocks.
    public static let lookBack = 40
    /// R-27, K-06: the stripped first line is truncated to this many extended grapheme clusters.
    public static let maxClusters = 60

    /// R-27: heading display text (C-02 rule 7: inline Markdown stripped per C-12, math per C-07.3) at or within the
    /// previous 40 blocks; else the block's first line stripped and truncated to 60 clusters; else `(line n)` with n the
    /// 1-based block index; `(empty)` only when the document has no blocks.
    public static func title(blocks: [String], toc: [TOCHeading], index: Int) -> String {
        guard !blocks.isEmpty else { return "(empty)" }
        let i = min(max(index, 0), blocks.count - 1)
        let lowest = max(0, i - lookBack)
        if let heading = toc.filter({ $0.blockIndex <= i && $0.blockIndex >= lowest }).max(by: { $0.blockIndex < $1.blockIndex }) {
            return heading.text
        }
        let firstLine = blocks[i].split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let stripped = stripInlineMarkdown(firstLine).trimmingCharacters(in: .whitespaces)
        if stripped.isEmpty { return "(line \(i + 1))" }
        return String(stripped.prefix(maxClusters))
    }
}
