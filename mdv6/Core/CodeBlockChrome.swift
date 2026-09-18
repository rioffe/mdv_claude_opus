// CodeBlockChrome — R-08 / C-05 / §5.1: a fenced code block with its language label, hover-revealed toolbar (wrap,
// copy), context menu (Copy Code, Wrap Long Lines, Copy Without Prompts when the fence is prompt-aware and prompted).
import SwiftUI
import AppKit

/// The parts of a fence block: info string and body (opening/closing marker lines removed).
public struct FenceParts: Equatable {
    public let infoString: String?
    public let code: String

    /// Splits a C-02 fence block; the closing marker line (if any) is dropped; the body keeps interior blank lines.
    public init(block: String) {
        var lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let opener = lines.removeFirst()
        let head = opener.drop(while: { $0 == " " || $0 == "\t" })
        let marker = head.hasPrefix("~~~") ? "~~~" : "```"
        let info = head.drop(while: { $0 == marker.first! }).trimmingCharacters(in: .whitespaces)
        infoString = info.isEmpty ? nil : info
        if let last = lines.last, last.drop(while: { $0 == " " || $0 == "\t" }).hasPrefix(marker) { lines.removeLast() }
        code = lines.joined(separator: "\n")
    }
}

public struct CodeBlockChrome: View {
    public let parts: FenceParts
    public let theme: MDVTheme
    public let zoom: CGFloat

    @State private var hovering = false
    @State private var wrap = false

    public init(parts: FenceParts, theme: MDVTheme, zoom: CGFloat) { self.parts = parts; self.theme = theme; self.zoom = zoom }

    private var promptAware: Bool { CodeLanguage.isPromptAware(infoString: parts.infoString) && CodeLanguage.isPrompted(code: parts.code) }
    private var highlighted: AttributedString { CodeRenderer.shared.render(code: parts.code, languageHint: parts.infoString, theme: theme, zoom: zoom) }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if wrap {
                    Text(highlighted).fixedSize(horizontal: false, vertical: true)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) { Text(highlighted).fixedSize(horizontal: true, vertical: true) }
                }
            }
            .textSelection(.enabled)
            .lineSpacing(0.225 * 0.85 * theme.baseFontSize * zoom)
            .padding(.horizontal, 16).padding(.top, 22).padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 0.5))

            HStack(spacing: 6) {
                if hovering {
                    Button { wrap.toggle() } label: { Image(systemName: wrap ? "text.justify.left" : "text.word.spacing") }
                        .buttonStyle(.plain).help(wrap ? "Unwrap Long Lines" : "Wrap Long Lines")
                    Button { Pasteboard.copy(parts.code) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.plain).help("Copy Code")
                }
                Text(CodeLanguage.label(infoString: parts.infoString))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.tertiaryText)
            }
            .font(.system(size: 11))
            .foregroundStyle(theme.secondaryText)
            .padding(.horizontal, 8).padding(.top, 5)
        }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Copy Code") { Pasteboard.copy(parts.code) }
            Button(wrap ? "Unwrap Long Lines" : "Wrap Long Lines") { wrap.toggle() }
            if promptAware { Button("Copy Without Prompts") { Pasteboard.copy(CodeLanguage.stripPrompts(parts.code)) } }
        }
    }
}
