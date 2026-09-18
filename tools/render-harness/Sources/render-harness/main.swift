// render-harness — C-17: argument parsing, JSON records and exit codes only; every render and metric lives in mdv6Core
// (R-39: links, never copies). Runs as `swift run --package-path tools/render-harness render-harness …` from the root.
import Foundation
import AppKit
import mdv6Core

let usage = """
usage: render-harness INPUT --output FILE [--width PT] [--scale S] [--theme ID]
       render-harness --scan ROOT --output-dir DIR
       render-harness --check MANIFEST [--case ID]
"""

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

var args = Array(CommandLine.arguments.dropFirst())
let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func url(_ s: String) -> URL { URL(fileURLWithPath: s, relativeTo: cwd).standardizedFileURL }
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name) else { return nil }
    guard i + 1 < args.count else { fail("\(name) needs a value\n\(usage)", code: 2) }
    let v = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return v
}

NSApplication.shared.setActivationPolicy(.prohibited)

// C-17: only the JSON records go to stdout. The vendored typesetter prints its font-registration lines with `print`
// (permitted by R-35), so the process's stdout is pointed at stderr and the records are written to the original fd.
let recordsFD = dup(STDOUT_FILENO)
dup2(STDERR_FILENO, STDOUT_FILENO)
let records = FileHandle(fileDescriptor: recordsFD)
func emit(_ r: CaseResult) {
    records.write(Data((r.json + "\n").utf8))
    for d in r.diagnostics { FileHandle.standardError.write(Data("\(r.id): \(d)\n".utf8)) }
}

if args.contains("-h") || args.contains("--help") { records.write(Data((usage + "\n").utf8)); exit(0) }

let scanRoot = option("--scan")
let outputDir = option("--output-dir")
let manifestPath = option("--check")
let onlyCase = option("--case")
let output = option("--output")
let width = option("--width").map { CGFloat(Double($0) ?? -1) } ?? 860
let scale = option("--scale").map { CGFloat(Double($0) ?? -1) } ?? 2
let themeId = option("--theme") ?? "high-contrast"
guard width > 0, scale > 0 else { fail("invalid --width/--scale\n\(usage)", code: 2) }

var exitCode: Int32 = 0
DispatchQueue.main.async {
    do {
        if let scanRoot {
            guard let outputDir, args.isEmpty else { fail(usage, code: 2) }
            let results = try HarnessRunner.runScan(root: url(scanRoot), outputDir: url(outputDir), width: width, scale: scale, themeId: themeId)
            for r in results { emit(r) }
            exitCode = results.contains { $0.status == .fail } ? 1 : 0
        } else if let manifestPath {
            guard args.isEmpty else { fail(usage, code: 2) }
            let manifestURL = url(manifestPath)
            let manifest = try HarnessRunner.loadManifest(manifestURL)
            let root = cwd
            let out = outputDir.map(url) ?? url("build/render-harness")
            let results = try HarnessRunner.runCheck(manifest: manifest, root: root, outputDir: out, only: onlyCase)
            for r in results { emit(r) }
            exitCode = results.contains { $0.status == .fail } ? 1 : 0
        } else {
            guard args.count == 1, let output else { fail(usage, code: 2) }
            let ok = try HarnessRunner.renderOne(input: url(args[0]), output: url(output), width: width, scale: scale, themeId: themeId)
            exitCode = ok ? 0 : 1
        }
    } catch let e as HarnessError {
        fail("render-harness: \(e)", code: 2)
    } catch {
        fail("render-harness: \(error)", code: 1)
    }
    exit(exitCode)
}
RunLoop.main.run()
