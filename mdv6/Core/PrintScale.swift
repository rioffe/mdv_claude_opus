// PrintScale — the C-21.1 type scale and the C-21.3 diagram widths (K-17), as functions of the paper.
import CoreGraphics

public enum PrintScale {
    /// C-21.1 / K-17: 54 pt margins on every side.
    public static let margin: CGFloat = 54

    /// w_c: the paper width minus both margins (Letter: 612 − 108 = 504).
    public static func contentWidth(paperWidth: CGFloat) -> CGFloat { paperWidth - 2 * margin }

    /// C-21.1: s_p = min(1, w_c / W), with W the print theme's articleMaxWidth; 1 when the theme sets none.
    public static func sp(contentWidth wc: CGFloat, articleMaxWidth W: CGFloat?) -> CGFloat {
        guard let W, W > 0 else { return 1 }
        return min(1, wc / W)
    }

    /// C-21.3: w_d = max(w_c − 2·18·s_p, 1), the diagram's drawn width inside the scaled chrome insets.
    public static func diagramWidth(contentWidth wc: CGFloat, sp: CGFloat) -> CGFloat { max(wc - 2 * 18 * sp, 1) }

    /// C-21.3: w_ℓ = max(w_d / s_p, 1), the width the screen's column would give the diagram.
    public static func layoutWidth(diagramWidth wd: CGFloat, sp: CGFloat) -> CGFloat {
        guard sp > 0 else { return 1 }
        return max(wd / sp, 1)
    }
}
