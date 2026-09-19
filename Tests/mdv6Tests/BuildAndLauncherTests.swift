import XCTest
@testable import mdv6Core

/// §9.1 scripted checks on the built bundle, the launcher and the Makefile (T-01, T-02, T-03 launcher clauses, T-34,
/// T-43's tag-gate half): R-33, R-34, C-01, C-13, K-01, K-02, K-11, K-12, I-011. Requires `make` to have produced
/// `build/mdv6.app` (the README's verification order is `make && swift test`).
final class BuildAndLauncherTests: XCTestCase {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    var app: URL { Self.root.appendingPathComponent("build/mdv6.app") }

    @discardableResult
    private func run(_ launchPath: String, _ args: [String], env: [String: String] = [:], cwd: URL? = nil) -> (status: Int32, out: String, err: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        p.currentDirectoryURL = cwd ?? Self.root
        var e = ProcessInfo.processInfo.environment
        for (k, v) in env { e[k] = v }
        p.environment = e
        let out = Pipe(), err = Pipe()
        p.standardOutput = out; p.standardError = err
        try! p.run()
        let o = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let r = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        return (p.terminationStatus, o, r)
    }

    /// T-01, C-01, C-13, K-01, K-02, K-12: `build/mdv6.app` carries every C-13 file, nothing beside `Contents/`, the K-02
    /// identifier/version, a 13.0 minimum OS, and passes `codesign --verify --deep --strict`. R-34.
    func testBuiltBundleLayoutAndSignature() throws {
        try XCTSkipIf(false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: app.path), "run `make` before `swift test` (T-01)")
        for f in ["Contents/MacOS/mdv6", "Contents/Info.plist", "Contents/Resources/AppIcon.icns", "Contents/Resources/mdv6",
                  "Contents/Resources/Help.md", "Contents/Resources/mathFonts.bundle/latinmodern-math.otf", "Contents/Resources/mathFonts.bundle/latinmodern-math.plist",
                  "Contents/Resources/Alegreya-Regular.otf", "Contents/Resources/Besley-SemiBold.otf", "Contents/Resources/OpenDyslexic-Bold.otf",
                  "Contents/Resources/swift-highlights.scm", "Contents/Resources/sql-highlights.scm",
                  "Contents/Resources/cpp-highlights.scm", "Contents/Resources/markdown-highlights.scm",
                  "Contents/Resources/markdown-inline-highlights.scm"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: app.appendingPathComponent(f).path), f)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: app.path), ["Contents"])
        // K-05, R-38, R-43: every grammar's query ships — 17 fence languages, markdown contributing two.
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: app.appendingPathComponent("Contents/Resources").path).filter { $0.hasSuffix("-highlights.scm") }.count, 18)
        let plist = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))!
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "com.mdv6.app")
        XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "1.0.0"); XCTAssertEqual(plist["CFBundleVersion"] as? String, "1")
        XCTAssertEqual(plist["LSMinimumSystemVersion"] as? String, "13.0")
        let types = plist["CFBundleDocumentTypes"] as! [[String: Any]]
        XCTAssertEqual(types[0]["CFBundleTypeExtensions"] as? [String], ["md", "markdown", "mdown"])
        XCTAssertEqual(types[0]["LSItemContentTypes"] as? [String], ["net.daringfireball.markdown", "public.plain-text"])
        XCTAssertEqual(run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path]).status, 0)
        let otool = run("/usr/bin/otool", ["-l", app.appendingPathComponent("Contents/MacOS/mdv6").path]).out
        XCTAssertTrue(otool.contains("minos 13.0"))
        let entitlements = run("/usr/bin/codesign", ["-d", "--entitlements", "-", "--xml", app.path]).out
        XCTAssertTrue(entitlements.contains("com.apple.security.files.user-selected.read-only"))
        XCTAssertFalse(entitlements.contains("<key>com.apple.security.app-sandbox</key>\n\t<true/>"))
    }

    /// T-03 (launcher clauses), R-33, §5.2: `--version` prints the bundle's version; a missing argument exits 1 with
    /// `mdv6: no such file: <arg>` and nothing is opened; `MDV6_APP=/nonexistent` falls through the search order; `-h`
    /// prints the usage; with no bundle anywhere the launcher exits 1 before reading its arguments.
    func testLauncherSurface() {
        let bin = Self.root.appendingPathComponent("bin/mdv6").path
        XCTAssertEqual(run(bin, ["--version"], env: ["MDV6_APP": app.path]).out, "1.0.0\n")
        let missing = run(bin, ["nope.md"], env: ["MDV6_APP": app.path])
        XCTAssertEqual(missing.status, 1); XCTAssertEqual(missing.err, "mdv6: no such file: nope.md\n")
        let firstMissing = run(bin, ["nope.md", "test-docs/rhythm.md"], env: ["MDV6_APP": app.path])
        XCTAssertEqual(firstMissing.status, 1); XCTAssertEqual(firstMissing.err, "mdv6: no such file: nope.md\n")
        XCTAssertEqual(run(bin, ["-", "test-docs/rhythm.md"], env: ["MDV6_APP": app.path]).err, "mdv6: no such file: -\n")
        XCTAssertEqual(run(bin, ["--version"], env: ["MDV6_APP": "/nonexistent"]).out, "1.0.0\n", "search order continues past MDV6_APP")
        XCTAssertTrue(run(bin, ["-h"]).out.hasPrefix("usage: mdv6"))
        XCTAssertTrue(run(bin, ["--help"]).out.contains("--version"))
        // no bundle: copy the script somewhere neutral and stub Spotlight (only provable while no mdv6.app is installed —
        // the search order's /Applications and ~/Applications steps cannot be redirected)
        guard !FileManager.default.fileExists(atPath: "/Applications/mdv6.app"),
              !FileManager.default.fileExists(atPath: NSHomeDirectory() + "/Applications/mdv6.app") else { return }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-launcher-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        try! FileManager.default.copyItem(atPath: bin, toPath: tmp.appendingPathComponent("mdv6").path)
        try! "#!/bin/sh\nexit 0\n".write(to: tmp.appendingPathComponent("mdfind"), atomically: true, encoding: .utf8)
        _ = run("/bin/chmod", ["+x", tmp.appendingPathComponent("mdfind").path])
        let none = run(tmp.appendingPathComponent("mdv6").path, ["--version"], env: ["MDV6_APP": "/nonexistent", "PATH": "\(tmp.path):/usr/bin:/bin", "HOME": "/nonexistent"], cwd: URL(fileURLWithPath: "/"))
        XCTAssertEqual(none.status, 1); XCTAssertTrue(none.err.contains("mdv6.app not found"))
        try? FileManager.default.removeItem(at: tmp)
    }

    /// T-02, R-34, K-11: on an untagged commit `make dist` and `make dist VERSION=9.9.9` exit non-zero at `check-version`
    /// before `clean` or any build command; T-43 (tag-gate half): the release chain and artefact naming are derived only
    /// from the exact tag (the signing/notarisation run needs credentials and a tag and is recorded separately).
    func testDistRefusesWithoutExactTag() {
        let tag = run("/usr/bin/git", ["describe", "--tags", "--exact-match"])
        XCTAssertNotEqual(tag.status, 0, "this checkout is untagged: the T-43 signing/notarisation run is recorded as pending, its tag gate is proved here")
        let dist = run("/usr/bin/make", ["dist"])
        XCTAssertNotEqual(dist.status, 0); XCTAssertTrue(dist.out.contains("check-version"))
        XCTAssertFalse(dist.out.contains("swift build")); XCTAssertFalse(dist.out.contains("rm -rf build"))
        let forced = run("/usr/bin/make", ["dist", "VERSION=9.9.9"])
        XCTAssertNotEqual(forced.status, 0); XCTAssertTrue(forced.out.contains("command line"))
        let makefile = try! String(contentsOf: Self.root.appendingPathComponent("Makefile"), encoding: .utf8)
        XCTAssertTrue(makefile.contains("dist: check-version"))
        for step in ["clean", "release", "sign", "zip-notary", "notarize", "staple", "zip-release", "checksum", "verify-release"] {
            XCTAssertTrue(makefile.contains("$(MAKE) \(step)"), step)
        }
        XCTAssertTrue(makefile.contains("git describe --tags --exact-match"))
        XCTAssertTrue(makefile.contains("mdv6-$(RELEASE_VERSION)-macos.zip"))
        XCTAssertTrue(makefile.contains("--options runtime --timestamp"))
        XCTAssertTrue(makefile.contains("xcrun stapler validate"))
        XCTAssertTrue(makefile.contains("spctl --assess"))
    }

    /// T-43, K-11, R-34: in a disposable clone whose `HEAD` carries the exact tag `v1.2.3`, the release chain names
    /// `dist/mdv6-1.2.3-macos.zip` and its `.sha256` from the tag alone, signs with Developer ID under the hardened runtime
    /// with a timestamp, notarises, staples, verifies with `codesign --verify --deep --strict`, `spctl` and `stapler validate`
    /// (the chain is dry-run here: this host has no signing identity or notary profile, so the credentialed run is pending),
    /// and a command-line `VERSION` is refused before any artefact can be named after it.
    func testTaggedCheckoutNamesArtefactsFromTag() throws {
        let clone = FileManager.default.temporaryDirectory.appendingPathComponent("mdv6-t43-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: clone) }
        XCTAssertEqual(run("/usr/bin/git", ["clone", "-q", "--depth", "1", "file://" + Self.root.path, clone.path]).status, 0)
        XCTAssertEqual(run("/usr/bin/git", ["tag", "v1.2.3"], cwd: clone).status, 0)
        let dry = run("/usr/bin/make", ["-n", "dist"], cwd: clone)
        XCTAssertEqual(dry.status, 0, dry.err)
        XCTAssertTrue(dry.out.contains("check-version: releasing v1.2.3"))
        XCTAssertTrue(dry.out.contains("ditto -c -k --keepParent build/mdv6.app dist/mdv6-1.2.3-macos.zip"))
        XCTAssertTrue(dry.out.contains("shasum -a 256 mdv6-1.2.3-macos.zip > mdv6-1.2.3-macos.zip.sha256"))
        XCTAssertTrue(dry.out.contains("codesign --force --deep --options runtime --timestamp --sign \"Developer ID Application:"))
        XCTAssertTrue(dry.out.contains("xcrun notarytool submit dist/mdv6-notary.zip --keychain-profile"))
        XCTAssertTrue(dry.out.contains("xcrun stapler staple build/mdv6.app"))
        XCTAssertTrue(dry.out.contains("ditto -x -k dist/mdv6-1.2.3-macos.zip dist/verify"))
        XCTAssertTrue(dry.out.contains("codesign --verify --deep --strict dist/verify/mdv6.app"))
        XCTAssertTrue(dry.out.contains("spctl --assess --type execute --verbose=4 dist/verify/mdv6.app"))
        XCTAssertTrue(dry.out.contains("xcrun stapler validate dist/verify/mdv6.app"))
        let steps = ["make clean", "make release", "make sign", "make zip-notary", "make notarize", "make staple", "make zip-release", "make checksum", "make verify-release"]
        let positions = steps.map { dry.out.range(of: $0)?.lowerBound }
        XCTAssertEqual(positions.compactMap { $0 }.count, steps.count, "every step of the chain")
        XCTAssertEqual(positions.compactMap { $0 }, positions.compactMap { $0 }.sorted(), "in §5.3 order")
        XCTAssertFalse(dry.out.contains("v1.2.3-macos"), "the artefact carries the version without its v")
        let forced = run("/usr/bin/make", ["dist", "VERSION=9.9.9"], cwd: clone)
        XCTAssertNotEqual(forced.status, 0); XCTAssertTrue(forced.out.contains("command line"))
        XCTAssertFalse(forced.out.contains("9.9.9-macos")); XCTAssertFalse(FileManager.default.fileExists(atPath: clone.appendingPathComponent("dist").path))
    }

    /// T-32, K-15, I-008: the idle-math CPU protocol — `test-docs/math.md` visible and untouched for 5 s, then 30 one-second
    /// process-CPU samples: median ≤ 1 %, nearest-rank p95 ≤ 3 % (`tools/idle-cpu.sh` runs the app on an isolated store).
    func testIdleMathCPU() {
        XCTAssertTrue(FileManager.default.fileExists(atPath: app.path), "run `make` before `swift test`")
        // K-15 is a measurement on an otherwise idle host: under `swift test --parallel` wait for the sibling workers to drain
        let deadline = Date().addingTimeInterval(600)
        while Date() < deadline {
            let others = run("/usr/bin/pgrep", ["-f", "PackageTests.xctest"]).out.split(separator: "\n").filter { Int32($0) != getpid() }
            if others.isEmpty { break }
            Thread.sleep(forTimeInterval: 2)
        }
        let r = run("/bin/bash", ["tools/idle-cpu.sh"], env: ["MDV6_SUPPORT_DIR": NSTemporaryDirectory() + "mdv6-idle-test", "MDV6_DEFAULTS_SUITE": "mdv6.idle.test"])
        XCTAssertEqual(r.status, 0, r.out)
        let samples = r.out.split(separator: "\n").first { $0.hasPrefix("samples:") }.map { $0.dropFirst("samples:".count).split(separator: " ").compactMap { Double($0) } } ?? []
        XCTAssertEqual(samples.count, 30, "thirty one-second samples")
        let sorted = samples.sorted()
        let median = sorted.count == 30 ? (sorted[14] + sorted[15]) / 2 : .infinity
        let p95 = sorted.count == 30 ? sorted[28] : .infinity                    // nearest rank: ceil(0.95 × 30) = 29th
        XCTAssertLessThanOrEqual(median, 1.0, "K-15 median ≤ 1 %: \(samples)")
        XCTAssertLessThanOrEqual(p95, 3.0, "K-15 nearest-rank p95 ≤ 3 %: \(samples)")
        UserDefaults.standard.removePersistentDomain(forName: "mdv6.idle.test")
    }

    /// R-37: the suite runs with `swift test` from a clean checkout and CI runs it on every push to `main` and every pull request.
    func testSuiteAndCI() throws {
        let workflow = try String(contentsOf: Self.root.appendingPathComponent(".github/workflows/build.yml"), encoding: .utf8)
        XCTAssertTrue(workflow.contains("swift test"))
        XCTAssertTrue(workflow.contains("branches: [main]")); XCTAssertTrue(workflow.contains("pull_request"))
        XCTAssertTrue(workflow.contains("macos-15"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: Self.root.appendingPathComponent("Tests/mdv6Tests").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: Self.root.appendingPathComponent("Tests/mdv6RenderTests").path))
    }

    /// T-34, I-011: the vendored SwiftMath carries exactly the README-listed patches — the patch markers appear only in the
    /// listed files and the font bundle is trimmed to Latin Modern Math (the full upstream diff is `tools/check-swiftmath.sh`).
    func testVendoredSwiftMathInventory() throws {
        let vendor = Self.root.appendingPathComponent("Vendor/SwiftMath/Sources/SwiftMath")
        let readme = try String(contentsOf: Self.root.appendingPathComponent("Vendor/SwiftMath/README.md"), encoding: .utf8)
        let listed = ["MathBundle/MathFont.swift", "MathRender/MTFont.swift", "MathRender/MTMathList.swift", "MathRender/MTMathListBuilder.swift",
                      "MathRender/MTTypesetter.swift", "MathRender/MTMathListDisplay.swift"]
        for f in listed { XCTAssertTrue(readme.contains(f.split(separator: "/").last!), f) }
        var patched: [String] = []
        for case let url as URL in FileManager.default.enumerator(at: vendor, includingPropertiesForKeys: nil)! where url.pathExtension == "swift" {
            if (try String(contentsOf: url, encoding: .utf8)).contains("mdv6 patch") { patched.append(url.path.replacingOccurrences(of: vendor.path + "/", with: "")) }
        }
        XCTAssertEqual(Set(patched), Set(listed))
        let bundle = try FileManager.default.contentsOfDirectory(atPath: vendor.appendingPathComponent("mathFonts.bundle").path).sorted()
        XCTAssertEqual(bundle, ["GUST-FONT-LICENSE.txt", "LICENSE", "OFL.txt", "latinmodern-math.otf", "latinmodern-math.plist"])
        XCTAssertTrue(readme.contains("fa8244ed032f4a1ade4cb0571bf87d2f1a9fd2d7"))
    }
}
