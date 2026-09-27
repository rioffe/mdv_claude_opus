import SwiftUI

// mdv6 local change (see Vendor/MarkdownUI/README.md): inline images the caller has already resolved, keyed by the
// image source string, so a renderer that runs no `.task` (SwiftUI's `ImageRenderer`) still draws them.

extension View {
  /// Supplies already-resolved inline images, keyed by image source. Empty by default; an image loaded by the
  /// inline image provider for the same key wins over a supplied one.
  public func markdownResolvedInlineImages(_ images: [String: Image]) -> some View {
    self.environment(\.resolvedInlineImages, images)
  }
}

extension EnvironmentValues {
  var resolvedInlineImages: [String: Image] {
    get { self[ResolvedInlineImagesKey.self] }
    set { self[ResolvedInlineImagesKey.self] = newValue }
  }
}

private struct ResolvedInlineImagesKey: EnvironmentKey {
  static let defaultValue: [String: Image] = [:]
}
