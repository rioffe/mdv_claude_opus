// ChromeModel — C-18 / K-16: the chrome metrics, opacities and rules as theme-independent data (I-015). W4 introduces
// the constants the article needs; W6 completes the pane rules.
import Foundation
import SwiftUI

public enum ChromeMetrics {
    /// C-18.7 / K-16: the hovered-block stripe is 3 pt wide in the accent colour.
    public static let stripeWidth: CGFloat = 3
    /// C-18.7 / K-16: floating find button — 28 pt circle, 0.5 pt stroke, 13 pt semibold glyph.
    public static let findButtonSize: CGFloat = 28
    public static let findButtonStroke: CGFloat = 0.5
    public static let findButtonGlyph: CGFloat = 13
}
