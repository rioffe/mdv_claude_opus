// Draws MDV6.png (1024×1024): a warm page with a folded corner and the "md" mark. Run by `make icon`.
import AppKit

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))
let inset = size * 0.08
let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.18, yRadius: size * 0.18)
NSColor(calibratedRed: 0.957, green: 0.937, blue: 0.890, alpha: 1).setFill()   // Sevilla cream
path.fill()
NSColor(calibratedRed: 0.176, green: 0.129, blue: 0.094, alpha: 1).setStroke()
path.lineWidth = size * 0.012
path.stroke()
// heading rule + text lines
let ink = NSColor(calibratedRed: 0.176, green: 0.129, blue: 0.094, alpha: 1)
ink.setFill()
CGRect(x: rect.minX + size * 0.14, y: rect.maxY - size * 0.30, width: rect.width - size * 0.28, height: size * 0.012).fill()
for i in 0..<4 {
    let y = rect.maxY - size * (0.38 + Double(i) * 0.07)
    let w = (rect.width - size * 0.28) * (i == 3 ? 0.55 : 0.92)
    NSColor(calibratedRed: 0.416, green: 0.361, blue: 0.290, alpha: 1).setFill()
    NSBezierPath(roundedRect: CGRect(x: rect.minX + size * 0.14, y: y, width: w, height: size * 0.030), xRadius: size * 0.015, yRadius: size * 0.015).fill()
}
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: size * 0.20, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.690, green: 0.384, blue: 0.243, alpha: 1),   // terracotta
]
let s = NSAttributedString(string: "md", attributes: attrs)
let ts = s.size()
s.draw(at: NSPoint(x: rect.midX - ts.width / 2, y: rect.minY + size * 0.10))
image.unlockFocus()
let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
