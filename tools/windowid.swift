// Prints "<windowNumber> <title>" for every on-screen, layer-0 window of the given pid (used by tools/observe.sh).
import AppKit
let pid = Int32(CommandLine.arguments[1])!
let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid {
    let layer = (w[kCGWindowLayer as String] as? Int) ?? 0
    guard layer == 0 else { continue }
    print((w[kCGWindowNumber as String] as? Int) ?? 0, (w[kCGWindowName as String] as? String) ?? "")
}
