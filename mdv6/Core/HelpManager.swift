// HelpManager — R-31: ⌘? copies the bundled Help.md over `<support dir>/Help.md` on every invocation and opens it as an
// adding route (so the copy matches the running build and has a stable path for history and bookmarks).
import Foundation

public enum HelpManager {
    public static func helpURL(model: AppModel) -> URL { model.supportDirectory.appendingPathComponent("Help.md") }

    @MainActor
    public static func openHelp(in session: DocumentSession) {
        let target = helpURL(model: session.model)
        if let source = Resources.url(file: "Help.md", subdirectory: nil), let data = FileManager.default.contents(atPath: source.path) {
            try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: target, options: .atomic)
        }
        _ = session.open(target, route: .adding)
    }
}
