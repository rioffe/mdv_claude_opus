// ContentLimits — K-14 untrusted-content ceilings, enforced before every parser and decoder (R-41, R-36, E-28, I-002).
import Foundation

public enum ContentLimits {
    /// K-14 (binary units): UTF-8 document file 64 MiB.
    public static let documentBytes = 64 * 1024 * 1024
    /// One Mermaid source 1 MiB.
    public static let mermaidBytes = 1024 * 1024
    /// One LaTeX span 64 KiB.
    public static let latexBytes = 64 * 1024
    /// Encoded or compressed local/data/remote image 32 MiB.
    public static let encodedImageBytes = 32 * 1024 * 1024
    /// Decoded image 256 MiB.
    public static let decodedImageBytes = 256 * 1024 * 1024
    /// Decoded image 64 megapixels.
    public static let decodedImagePixels = 64_000_000
    /// 16,384 pixels on either axis.
    public static let imageAxisPixels = 16_384

    public enum Kind: CaseIterable, Sendable { case document, mermaid, latex, encodedImage, decodedImageBytes, decodedImagePixels, imageAxis }

    public static func ceiling(_ kind: Kind) -> Int {
        switch kind {
        case .document: return documentBytes
        case .mermaid: return mermaidBytes
        case .latex: return latexBytes
        case .encodedImage: return encodedImageBytes
        case .decodedImageBytes: return decodedImageBytes
        case .decodedImagePixels: return decodedImagePixels
        case .imageAxis: return imageAxisPixels
        }
    }

    /// K-14: content at the ceiling is admitted; content above it follows E-28.
    public static func admits(_ measure: Int, kind: Kind) -> Bool { measure <= ceiling(kind) }

    /// K-14 for a decoded image: both axes, the pixel count and the decoded byte count must be at or under their ceilings.
    public static func admitsImage(width: Int, height: Int, bytesPerPixel: Int) -> Bool {
        guard width >= 0, height >= 0, width <= imageAxisPixels, height <= imageAxisPixels else { return false }
        let pixels = width * height
        guard pixels <= decodedImagePixels else { return false }
        return pixels * max(bytesPerPixel, 1) <= decodedImageBytes
    }

    /// E-28: the text shown in the R-10/R-14 source fallback for oversized Mermaid or LaTeX.
    public static let exceededMessage = "input exceeds limit"
}
