// seed-store SUPPORT_DIR DEFAULTS_SUITE THEME FILE... — history rows (first argument displayed), four bookmarks in the
// first file (T-44), the theme id. Run from the repository root.
import Foundation
import mdv6Core

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 4 else { print("usage: seed-store SUPPORT_DIR DEFAULTS_SUITE THEME FILE..."); exit(2) }
let support = URL(fileURLWithPath: args[0]), suite = args[1], theme = args[2]
let files = args[3...].map { URL(fileURLWithPath: $0).standardizedFileURL.path }
try? FileManager.default.removeItem(at: support)
UserDefaults.standard.removePersistentDomain(forName: suite)
let model = AppModel.bootstrap(supportDir: support, defaultsSuite: suite)
for f in files.reversed() { model.history.add(path: f) }
model.preferences.themeId = theme
model.preferences.inspectorVisible = true
model.preferences.bookmarksExpanded = true
if let first = files.first, let text = try? String(contentsOfFile: first, encoding: .utf8) {
    let doc = ParsedDocument(raw: text)
    let targets = doc.tocHeadings.map(\.blockIndex).filter { $0 > 0 }.prefix(4)
    for i in targets { model.bookmarks.add(path: first, document: doc, index: i) }
}
model.defaults.synchronize()
print("seeded \(support.path) / \(suite): \(model.history.entries.count) history rows, \(model.bookmarks.bookmarks.count) bookmarks, theme \(theme)")
