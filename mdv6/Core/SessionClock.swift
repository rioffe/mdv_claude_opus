// SessionClock — the timers the session needs (K-06: the 0.6 s flash, the 500 ms empty-read retry), injectable for tests.
import Foundation

public final class SessionTimer {
    private let onCancel: () -> Void
    public init(onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    public func cancel() { onCancel() }
}

public protocol SessionClock: AnyObject {
    func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) -> SessionTimer
}

/// The main queue.
public final class LiveClock: SessionClock {
    public init() {}
    public func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) -> SessionTimer {
        let item = DispatchWorkItem(block: block)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return SessionTimer { item.cancel() }
    }
}
