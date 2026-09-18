// EditorLauncher — R-23: open the current file in the chosen external editor; a launch failure is logged (R-35 permits
// the error text) and reported to the caller for the C-14 alert.
import Foundation
import AppKit

public enum EditorLauncher {
    public static func open(file: URL, editorAppPath: String) -> Result<Void, Error> {
        let app = URL(fileURLWithPath: editorAppPath)
        guard FileManager.default.fileExists(atPath: app.path) else {
            let error = NSError(domain: "mdv6.editor", code: 1, userInfo: [NSLocalizedDescriptionKey: "The application at \(editorAppPath) could not be found."])
            Diagnostics.log(.editorLaunchFailure(error.localizedDescription))
            return .failure(error)
        }
        let semaphore = DispatchSemaphore(value: 0)
        var outcome: Result<Void, Error> = .success(())
        NSWorkspace.shared.open([file], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error { outcome = .failure(error) }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 10)
        if case .failure(let error) = outcome { Diagnostics.log(.editorLaunchFailure(error.localizedDescription)) }
        return outcome
    }
}
