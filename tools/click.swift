// Observation aid: a real pointer event at global screen coordinates (System Events' `click at` presses the accessibility
// element instead, which never reaches a SwiftUI tap gesture). Usage: swift tools/click.swift X Y [move|click|right|drag X2 Y2]
import Foundation
import CoreGraphics
let a = CommandLine.arguments
guard a.count >= 3, let x = Double(a[1]), let y = Double(a[2]) else { print("usage: click.swift X Y [move|click|right]"); exit(2) }
let mode = a.count > 3 ? a[3] : "click"
let p = CGPoint(x: x, y: y)
func post(_ type: CGEventType, _ button: CGMouseButton) { CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: button)?.post(tap: .cghidEventTap) }
post(.mouseMoved, .left); usleep(120_000)
switch mode {
case "move": break
case "right": post(.rightMouseDown, .right); usleep(60_000); post(.rightMouseUp, .right)
case "drag":
    guard a.count >= 6, let x2 = Double(a[4]), let y2 = Double(a[5]) else { print("drag needs X2 Y2"); exit(2) }
    post(.leftMouseDown, .left); usleep(400_000)
    for i in 1...40 {
        let t = Double(i) / 40
        let q = CGPoint(x: x + (x2 - x) * t, y: y + (y2 - y) * t)
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: q, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(25_000)
    }
    usleep(150_000)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: x2, y: y2), mouseButton: .left)?.post(tap: .cghidEventTap)
default: post(.leftMouseDown, .left); usleep(60_000); post(.leftMouseUp, .left)
}
