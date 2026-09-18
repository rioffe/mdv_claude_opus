// FileWatcher — R-05 / E-21 / K-06: watches a file **by path** through FSEvents on its parent directory (a plain write,
// an atomic rename over it and a delete-and-recreate all report), 50 ms latency without deferral: the first event of a
// burst is delivered at once and later events within 50 ms batch into at most one further delivery.
import Foundation
import CoreServices

public protocol FileWatching: AnyObject {
    func cancel()
}

public final class FileWatcher: FileWatching {
    /// K-06: 50 ms.
    public static let latency: TimeInterval = 0.05

    private var stream: FSEventStreamRef?
    private let path: String
    private let onChange: () -> Void

    public init(path: URL, onChange: @escaping () -> Void) {
        self.path = path.standardizedFileURL.path
        self.onChange = onChange
        let directory = path.standardizedFileURL.deletingLastPathComponent().path
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, eventPaths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
            var hit = false
            for i in 0..<count {
                let p = URL(fileURLWithPath: paths[i]).standardizedFileURL.path
                if p == watcher.path || p == (watcher.path as NSString).deletingLastPathComponent { hit = true; break }
            }
            if hit { watcher.onChange() }
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        guard let s = FSEventStreamCreate(nil, callback, &context, [directory] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                          FileWatcher.latency, flags) else { return }
        stream = s
        FSEventStreamSetDispatchQueue(s, DispatchQueue.main)
        FSEventStreamStart(s)
    }

    deinit { cancel() }

    public func cancel() {
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }
}
