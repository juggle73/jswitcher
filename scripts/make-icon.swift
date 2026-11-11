// Draws the app icon: a light keyboard key with "EN" and "RU" legends.
// Usage: swift scripts/make-icon.swift <out.png>   (1024×1024)
// Then scripts/make-icon.sh turns it into Resources/AppIcon.icns.
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// macOS icon grid: 824×824 body centred in 1024, corner radius ≈ 185.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// Drop shadow under the key.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35).cgColor)
color(0xB9BEC6).setFill()
bodyPath.fill()
ctx.restoreGState()

// Key skirt: darker gradient, visible as the rim around the top surface.
NSGradient(starting: color(0xE4E7EC), ending: color(0xA9AFB9))!.draw(in: bodyPath, angle: -90)

// Key top: slightly inset and raised towards the top edge.
let top = NSRect(x: body.minX + 58, y: body.minY + 92, width: body.width - 116, height: body.height - 140)
let topPath = NSBezierPath(roundedRect: top, xRadius: 130, yRadius: 130)
NSGradient(starting: color(0xFFFFFF), ending: color(0xEEF0F3))!.draw(in: topPath, angle: -90)
color(0xFFFFFF, 0.9).setStroke()
topPath.lineWidth = 3
topPath.stroke()

// Legends: EN top-left, RU bottom-right, like a dual-language keycap.
func legend(_ text: String, _ fill: NSColor, at point: NSPoint, alignRight: Bool) {
    let font = NSFont.systemFont(ofSize: 250, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fill, .kern: -4]
    let s = NSAttributedString(string: text, attributes: attrs)
    let w = s.size().width
    s.draw(at: NSPoint(x: alignRight ? point.x - w : point.x, y: point.y))
}
legend("EN", color(0x2B2F36), at: NSPoint(x: top.minX + 80, y: top.midY + 20), alignRight: false)
legend("RU", color(0x2F6FEB), at: NSPoint(x: top.maxX - 80, y: top.minY + 50), alignRight: true)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
