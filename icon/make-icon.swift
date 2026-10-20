// Renders icon/icon.png (1024px). Run: swift icon/make-icon.swift
import AppKit

let S: CGFloat = 1024
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}
func gradient(_ a: CGColor, _ b: CGColor) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [a, b] as CFArray, locations: [0, 1])!
}
func circle(_ c: CGPoint, _ r: CGFloat) -> CGRect { CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2) }

// Body: macOS-style rounded square, soft pastel gradient
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x000000, 0.22))
ctx.addPath(bodyPath); ctx.setFillColor(rgb(0x7C6CF7)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(bodyPath); ctx.clip()
ctx.drawLinearGradient(gradient(rgb(0xB9AEFF), rgb(0x7462F5)), start: CGPoint(x: 300, y: 924), end: CGPoint(x: 724, y: 100), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
ctx.restoreGState()

// Two round eyes glancing up at the notification dot
let pupilShift = CGPoint(x: 20, y: 28)
for x in [CGFloat(404), 620] {
    let e = CGRect(x: x - 92, y: 380, width: 184, height: 224)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: rgb(0x3B2AA8, 0.25))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillEllipse(in: e)
    ctx.restoreGState()
    let p = CGPoint(x: e.midX + pupilShift.x, y: e.midY + pupilShift.y)
    ctx.saveGState()
    ctx.addEllipse(in: e.insetBy(dx: 10, dy: 10)); ctx.clip() // keep pupils inside the eye
    ctx.setFillColor(rgb(0x221D4A))
    ctx.fillEllipse(in: circle(p, 54))
    ctx.restoreGState()
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillEllipse(in: circle(CGPoint(x: p.x + 18, y: p.y + 20), 16))
}

// Notification dot with a soft glow
let d = CGPoint(x: 742, y: 742)
ctx.drawRadialGradient(gradient(rgb(0xFF7A90, 0.45), rgb(0xFF7A90, 0)), startCenter: d, startRadius: 30, endCenter: d, endRadius: 110, options: [])
ctx.saveGState()
ctx.addEllipse(in: circle(d, 48)); ctx.clip()
ctx.drawLinearGradient(gradient(rgb(0xFFA0AE), rgb(0xFF5C7A)), start: CGPoint(x: d.x, y: d.y + 48), end: CGPoint(x: d.x, y: d.y - 48), options: [])
ctx.restoreGState()

let url = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon/icon.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
