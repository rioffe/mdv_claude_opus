// ScrollKeys — K-18 keyboard-scroll steps (R-49) and the R-48 history step, as pure functions. The event monitors
// that use them are added by W12.
import CoreGraphics

public enum ScrollKey: Equatable, Sendable { case down, up, pageDown, pageUp, space, home, end }

public enum ScrollKeys {
    /// K-18: arrow step in points.
    public static let lineStep: CGFloat = 40
    /// K-18: fraction of the usable height a page key moves.
    public static let pageFraction: CGFloat = 0.875
    /// K-18: *End* re-aims at the bottom every 1/60 s at most this many times.
    public static let endRetries = 10

    /// R-49: ↓ 125, ↑ 126, PgDn 121, PgUp 116, Space 49 (⇧Space = page up), Home 115, End 119; others pass through.
    public static func key(keyCode: UInt16, shift: Bool) -> ScrollKey? {
        switch (keyCode, shift) {
        case (125, false): return .down
        case (126, false): return .up
        case (121, false): return .pageDown
        case (116, false): return .pageUp
        case (49, false): return .space
        case (49, true): return .pageUp
        case (115, false): return .home
        case (119, false): return .end
        default: return nil
        }
    }

    /// K-18: the proposed clip origin; the scroll view clamps it (Home/End aim past the ends so the clamp lands on them).
    public static func target(_ key: ScrollKey, y: CGFloat, usable: CGFloat, documentHeight: CGFloat) -> CGFloat {
        let page = max(usable * pageFraction, lineStep)
        let beyond = documentHeight + max(usable, 0) + 1
        switch key {
        case .down: return y + lineStep
        case .up: return y - lineStep
        case .pageDown, .space: return y + page
        case .pageUp: return y - page
        case .home: return -beyond
        case .end: return beyond
        }
    }
}

public enum HistoryStep {
    /// R-48: the row `offset` away from `current`, or nil at the ends (no wrap) or with nothing displayed.
    public static func target(current: Int?, offset: Int, count: Int) -> Int? {
        guard let current else { return nil }
        let t = current + offset
        return (0 ..< count).contains(t) ? t : nil
    }
}

import AppKit

extension ScrollKeys {
    /// E-37: what holds first responder, as R-49 classifies it.
    public enum ResponderKind: Equatable, Sendable { case none, window, readOnlyText, editableText, other }

    public static func responderKind(_ responder: NSResponder?, window: NSWindow?) -> ResponderKind {
        guard let responder else { return .none }
        if responder === window { return .window }
        if let text = responder as? NSText { return text.isEditable ? .editableText : .readOnlyText }
        return .other
    }

    /// R-49 / E-37: the document takes the key only with no ⌘/⌥/⌃ and when nothing, the window, or a read-only text view
    /// holds first responder.
    public static func documentOwnsKey(responder: ResponderKind, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard modifiers.intersection([.command, .option, .control]).isEmpty else { return false }
        return responder == .none || responder == .window || responder == .readOnlyText
    }

    /// R-48: ⌃⇥ → +1, ⌃⇧⇥ → −1; any Tab without Control passes through.
    public static func fileStep(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Int? {
        guard keyCode == 48, modifiers.contains(.control) else { return nil }
        return modifiers.contains(.shift) ? -1 : 1
    }
}

/// R-49: scrolls the article's own `NSScrollView` from the keyboard, in the window the key was typed into (K-18).
@MainActor
public final class ScrollKeyMonitor {
    private var monitor: Any?
    public weak var scrollView: NSScrollView?

    public init() {}

    public func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let scroller = self.scrollView, let window = event.window, scroller.window === window,
                  let key = ScrollKeys.key(keyCode: event.keyCode, shift: event.modifierFlags.contains(.shift)),
                  ScrollKeys.documentOwnsKey(responder: ScrollKeys.responderKind(window.firstResponder, window: window),
                                             modifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask)) else { return event }
            self.scroll(scroller, key: key)
            return nil                                                   // handled: no beep (R-49)
        }
    }

    /// K-18: the target from `ScrollKeys.target`, clamped by the clip view (content insets included); *End* re-aims at
    /// the bottom every 1/60 s until the lazily laid-out document stops growing, at most `endRetries` times.
    public func scroll(_ scroller: NSScrollView, key: ScrollKey) {
        let clip = scroller.contentView
        let usable = clip.bounds.height - scroller.contentInsets.top - scroller.contentInsets.bottom
        let docHeight = scroller.documentView?.frame.height ?? 0
        let landed = Self.move(scroller, to: ScrollKeys.target(key, y: clip.bounds.origin.y, usable: usable, documentHeight: docHeight))
        if key == .end { settle(scroller, previous: landed, remaining: ScrollKeys.endRetries) }
    }

    @discardableResult
    static func move(_ scroller: NSScrollView, to y: CGFloat) -> CGFloat {
        var b = scroller.contentView.bounds
        b.origin.y = y
        let landed = scroller.contentView.constrainBoundsRect(b).origin
        scroller.contentView.scroll(to: landed)
        scroller.reflectScrolledClipView(scroller.contentView)
        return landed.y
    }

    private func settle(_ scroller: NSScrollView, previous: CGFloat, remaining: Int) {
        guard remaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60) { [weak self, weak scroller] in
            guard let self, let scroller else { return }
            let h = scroller.documentView?.frame.height ?? 0
            let y = Self.move(scroller, to: ScrollKeys.target(.end, y: 0, usable: scroller.contentView.bounds.height, documentHeight: h))
            if abs(y - previous) > 0.5 { self.settle(scroller, previous: y, remaining: remaining - 1) }
        }
    }

    public func uninstall() { if let m = monitor { NSEvent.removeMonitor(m); monitor = nil } }
}

/// R-48: ⌃⇥ / ⌃⇧⇥ as a second binding for Next / Previous File, in the window the key was typed into.
@MainActor
public final class FileStepMonitor {
    private var monitor: Any?
    public init() {}
    public func install(window: @escaping () -> NSWindow?, step: @escaping (Int) -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let w = window(), event.window === w,
                  let d = ScrollKeys.fileStep(keyCode: event.keyCode, modifiers: event.modifierFlags.intersection(.deviceIndependentFlagsMask)) else { return event }
            step(d)
            return nil
        }
    }
    public func uninstall() { if let m = monitor { NSEvent.removeMonitor(m); monitor = nil } }
}
