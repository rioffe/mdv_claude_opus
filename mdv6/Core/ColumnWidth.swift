// ColumnWidth — the §7.2 column-width formula (K-13) and the Mermaid raster width (R-11, K-07).
import Foundation

public enum ColumnWidth {
    /// §7.2: `b`, the per-block horizontal padding.
    public static let blockPadding: CGFloat = 6
    /// §7.2, C-18.1: each shown side pane adds its 8 pt drag handle.
    public static let handleWidth: CGFloat = 8
    /// R-11: a diagram is drawn at the column width minus 36 pt.
    public static let mermaidInset: CGFloat = 36

    /// §7.2: `w_col = min(w_area − w_side − w_insp, w_max) − 2p − 2b`, where a shown pane's width includes its handle
    /// (pass 0 for a hidden pane) and `maxWidth` nil means no cap.
    public static func column(area: CGFloat, sidebar: CGFloat, inspector: CGFloat, maxWidth: CGFloat?, padding p: CGFloat) -> CGFloat {
        let side = sidebar > 0 ? sidebar + handleWidth : 0
        let insp = inspector > 0 ? inspector + handleWidth : 0
        let available = area - side - insp
        let capped = maxWidth.map { min(available, $0) } ?? available
        return capped - 2 * p - 2 * blockPadding
    }

    /// R-11, K-07: `⌊min(natural, max(w_col − 36, 1))⌋` — whole points, bounded below by 1 pt.
    public static func rasterWidth(natural: CGFloat, column: CGFloat) -> CGFloat {
        floor(min(natural, max(column - mermaidInset, 1)))
    }
}
