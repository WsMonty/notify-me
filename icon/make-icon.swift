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
ctx.drawLinearGradient(gradient(rgb(0xB3A8FF), rgb(0x6F5CF2)), start: CGPoint(x: 300, y: 924), end: CGPoint(x: 724, y: 100), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
ctx.restoreGState()

// Eye: soft almond with rounded tips (fill + thick round-joined stroke)
let c = CGPoint(x: 512, y: 500), half: CGFloat = 250, bulge: CGFloat = 230
let eye = CGMutablePath()
eye.move(to: CGPoint(x: c.x - half, y: c.y))
eye.addCurve(to: CGPoint(x: c.x + half, y: c.y), control1: CGPoint(x: c.x - half * 0.55, y: c.y + bulge), control2: CGPoint(x: c.x + half * 0.55, y: c.y + bulge))
eye.addCurve(to: CGPoint(x: c.x - half, y: c.y), control1: CGPoint(x: c.x + half * 0.55, y: c.y - bulge), control2: CGPoint(x: c.x - half * 0.55, y: c.y - bulge))
eye.closeSubpath()
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: rgb(0x3B2AA8, 0.28))
ctx.beginTransparencyLayer(auxiliaryInfo: nil) // one shadow for fill + stroke together
ctx.addPath(eye); ctx.setFillColor(rgb(0xFFFFFF)); ctx.setStrokeColor(rgb(0xFFFFFF))
ctx.setLineWidth(70); ctx.setLineJoin(.round)
ctx.drawPath(using: .fillStroke)
ctx.endTransparencyLayer()
ctx.restoreGState()

// Big round pupil + two sparkles
let p = CGPoint(x: c.x, y: c.y - 6)
ctx.saveGState()
ctx.addEllipse(in: circle(p, 128)); ctx.clip()
ctx.drawLinearGradient(gradient(rgb(0x3A3470), rgb(0x1A1638)), start: CGPoint(x: p.x, y: p.y + 128), end: CGPoint(x: p.x, y: p.y - 128), options: [])
ctx.restoreGState()
ctx.setFillColor(rgb(0xFFFFFF))
ctx.fillEllipse(in: circle(CGPoint(x: p.x + 46, y: p.y + 50), 38))
ctx.fillEllipse(in: circle(CGPoint(x: p.x - 50, y: p.y - 52), 16))

// Notification dot
let d = CGPoint(x: 738, y: 708)
ctx.setFillColor(rgb(0xFFFFFF))
ctx.fillEllipse(in: circle(d, 66))
ctx.saveGState()
ctx.addEllipse(in: circle(d, 50)); ctx.clip()
ctx.drawLinearGradient(gradient(rgb(0xFF9AA8), rgb(0xFF5A78)), start: CGPoint(x: d.x, y: d.y + 50), end: CGPoint(x: d.x, y: d.y - 50), options: [])
ctx.restoreGState()

let url = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon/icon.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
