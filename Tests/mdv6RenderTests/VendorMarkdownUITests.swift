import XCTest
import SwiftUI
import AppKit
import CryptoKit
import MarkdownUI
@testable import mdv6Core

/// I-016 / T-62: the vendored MarkdownUI carries exactly the changes its README lists; the resolved-inline-images hook
/// (the one behavioural patch, C-21.4) makes an inline image render under `ImageRenderer`, which runs no `.task`.
final class VendorMarkdownUITests: XCTestCase {

    private var vendor: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../Vendor/MarkdownUI").standardizedFileURL
    }

    /// The files the README's "Local changes vs upstream" section names (backticked paths under `Sources/MarkdownUI/`).
    private func listedChanges() throws -> Set<String> {
        let readme = try String(contentsOf: vendor.appendingPathComponent("README.md"), encoding: .utf8)
        let section = readme.components(separatedBy: "## Local changes vs upstream").last ?? ""
        let regex = try NSRegularExpression(pattern: "`(\\./[A-Za-z0-9_+/.-]+\\.swift)`")
        let range = NSRange(section.startIndex..., in: section)
        return Set(regex.matches(in: section, range: range).compactMap { Range($0.range(at: 1), in: section).map { String(section[$0]) } })
    }

    /// I-016, T-62: every upstream file not listed is byte-identical to v2.4.1 (the recorded manifest); every listed file
    /// differs from upstream or is new; no other file exists; `Documentation.docc` is absent.
    func testInventoryMatchesREADME() throws {
        let root = vendor.appendingPathComponent("Sources/MarkdownUI")
        let manifest = try String(contentsOf: vendor.appendingPathComponent("UPSTREAM.sha256"), encoding: .utf8)
        var upstream: [String: String] = [:]
        for line in manifest.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            upstream[parts[1].trimmingCharacters(in: .whitespaces)] = String(parts[0])
        }
        XCTAssertEqual(upstream.count, 126)
        let listed = try listedChanges()
        XCTAssertFalse(listed.isEmpty, "README lists no changes")
        var present: Set<String> = []
        let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])!
        for case let url as URL in e where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            let rel = "." + url.path.dropFirst(root.path.count)
            present.insert(rel)
            let hash = SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
            if listed.contains(rel) {
                XCTAssertNotEqual(upstream[rel], hash, "\(rel) is listed as changed but equals upstream")
            } else {
                XCTAssertEqual(upstream[rel], hash, "\(rel) differs from upstream v2.4.1 but is not listed in README.md")
            }
        }
        XCTAssertEqual(present.subtracting(upstream.keys), listed.subtracting(upstream.keys), "unlisted new files")
        XCTAssertTrue(Set(upstream.keys).isSubset(of: present), "upstream files removed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Documentation.docc").path))
    }

    /// I-016, C-21.4: an image supplied through `markdownResolvedInlineImages` draws under `ImageRenderer`.
    @MainActor
    func testResolvedInlineImageRendersUnderImageRenderer() throws {
        let red = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { r in NSColor.red.setFill(); r.fill(); return true }
        func redPixels(_ resolved: [String: Image]) -> Int {
            let view = Markdown("a ![](x://one) b").markdownResolvedInlineImages(resolved).frame(width: 200).background(Color.white)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            guard let cg = renderer.cgImage else { return -1 }
            let rep = NSBitmapImageRep(cgImage: cg)                  // colour-space and byte-order independent
            var count = 0
            for y in 0 ..< rep.pixelsHigh { for x in 0 ..< rep.pixelsWide {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                if c.redComponent > 0.8 && c.greenComponent < 0.25 && c.blueComponent < 0.25 { count += 1 }
            } }
            return count
        }
        XCTAssertEqual(redPixels([:]), 0, "without the hook ImageRenderer skips the unloaded inline image")
        XCTAssertGreaterThan(redPixels(["x://one": Image(nsImage: red)]), 100)
    }
}
