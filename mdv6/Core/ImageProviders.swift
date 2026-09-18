// ImageProviders — R-16 image views: local files relative to the document, `data:` URIs, and the remote gate
// ("Remote image blocked" until View → Load Remote Images; E-11 failure placeholder; in-flight loads cancelled when the
// preference turns off). Every image obeys K-14 and is never scaled above its intrinsic size.
import SwiftUI
import AppKit

public struct ImagePlaceholder: View {
    public let text: String
    public let theme: MDVTheme
    public var action: (() -> Void)? = nil

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo").foregroundStyle(theme.tertiaryText)
            Text(text).font(.system(size: 12)).foregroundStyle(theme.secondaryText)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(theme.secondaryBackground, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture { action?() }
    }
}

public struct DocumentImageView: View {
    public let url: URL
    public let theme: MDVTheme
    public let baseURL: URL?
    public let loadRemote: Bool
    public let remoteLoader: RemoteImageLoader?
    public let onRevealRemoteSetting: (() -> Void)?

    @State private var remoteResult: ImageLoadResult? = nil

    private var isRemote: Bool { let s = url.scheme?.lowercased(); return s == "http" || s == "https" }

    public var body: some View {
        Group {
            if isRemote {
                remoteBody
            } else if url.scheme == "data" {
                render(ImageDecoding.dataURI(url))
            } else {
                render(ImageDecoding.local(url: url, base: baseURL))
            }
        }
    }

    @ViewBuilder private var remoteBody: some View {
        if !loadRemote {
            ImagePlaceholder(text: "Remote image blocked", theme: theme, action: onRevealRemoteSetting)   // R-16, E-11
        } else if let remoteResult {
            render(remoteResult)
        } else {
            ProgressView().controlSize(.small)
                .task(id: url) {
                    guard let loader = remoteLoader else { remoteResult = .failed(reason: "no loader"); return }
                    let r = await loader.load(url)
                    if !Task.isCancelled { remoteResult = r }
                }
        }
    }

    @ViewBuilder private func render(_ result: ImageLoadResult) -> some View {
        switch result {
        case .image(let img):
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: img.size.width, maxHeight: img.size.height)     // never above intrinsic size
        case .blocked:
            ImagePlaceholder(text: "Remote image blocked", theme: theme, action: onRevealRemoteSetting)
        case .notFound(let name):
            ImagePlaceholder(text: "image not found: \(name)", theme: theme)
        case .failed(let reason):
            ImagePlaceholder(text: "image failed: \(reason)", theme: theme)
        }
    }
}
