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

// Body: macOS-style rounded square with soft shadow
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.3))
ctx.addPath(bodyPath); ctx.setFillColor(rgb(0x5B4BF5)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(bodyPath); ctx.clip()
ctx.drawLinearGradient(gradient(rgb(0x8B7CFF), rgb(0x4636E3)), start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
// soft top glow
ctx.drawRadialGradient(gradient(rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0)), startCenter: CGPoint(x: 400, y: 860), startRadius: 0,
                       endCenter: CGPoint(x: 400, y: 860), endRadius: 520, options: [])
ctx.restoreGState()

// Eye: almond shape
let cx: CGFloat = 512, cy: CGFloat = 480, half: CGFloat = 290, lift: CGFloat = 250
let eye = CGMutablePath()
eye.move(to: CGPoint(x: cx - half, y: cy))
eye.addQuadCurve(to: CGPoint(x: cx + half, y: cy), control: CGPoint(x: cx, y: cy + lift * 1.6))
eye.addQuadCurve(to: CGPoint(x: cx - half, y: cy), control: CGPoint(x: cx, y: cy - lift * 1.6))
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x1A0F7A, 0.35))
ctx.addPath(eye); ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillPath()
ctx.restoreGState()

// Iris + pupil, clipped to the eye
ctx.saveGState()
ctx.addPath(eye); ctx.clip()
let iris: CGFloat = 150
ctx.addEllipse(in: CGRect(x: cx - iris, y: cy - iris, width: iris * 2, height: iris * 2)); ctx.clip()
ctx.drawLinearGradient(gradient(rgb(0x3FD8C8), rgb(0x1E6FE0)), start: CGPoint(x: cx, y: cy + iris), end: CGPoint(x: cx, y: cy - iris), options: [])
ctx.restoreGState()
ctx.setFillColor(rgb(0x14113A))
ctx.fillEllipse(in: CGRect(x: cx - 72, y: cy - 72, width: 144, height: 144))
// sparkles (the cute part)
ctx.setFillColor(rgb(0xFFFFFF))
ctx.fillEllipse(in: CGRect(x: cx + 10, y: cy + 30, width: 70, height: 70))
ctx.fillEllipse(in: CGRect(x: cx - 70, y: cy - 75, width: 30, height: 30))

// Notification badge
let bc = CGPoint(x: 760, y: 762), br: CGFloat = 92
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: rgb(0x000000, 0.25))
ctx.setFillColor(rgb(0xFFFFFF))
ctx.fillEllipse(in: CGRect(x: bc.x - br - 16, y: bc.y - br - 16, width: (br + 16) * 2, height: (br + 16) * 2))
ctx.restoreGState()
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: bc.x - br, y: bc.y - br, width: br * 2, height: br * 2)); ctx.clip()
ctx.drawLinearGradient(gradient(rgb(0xFF7A6B), rgb(0xF0304A)), start: CGPoint(x: bc.x, y: bc.y + br), end: CGPoint(x: bc.x, y: bc.y - br), options: [])
ctx.restoreGState()
// tiny bell in the badge
ctx.setFillColor(rgb(0xFFFFFF))
let bell = CGMutablePath()
bell.move(to: CGPoint(x: bc.x - 48, y: bc.y - 26))
bell.addLine(to: CGPoint(x: bc.x + 48, y: bc.y - 26))
bell.addCurve(to: CGPoint(x: bc.x + 32, y: bc.y + 10), control1: CGPoint(x: bc.x + 34, y: bc.y - 14), control2: CGPoint(x: bc.x + 32, y: bc.y - 6))
bell.addCurve(to: CGPoint(x: bc.x - 32, y: bc.y + 10), control1: CGPoint(x: bc.x + 32, y: bc.y + 56), control2: CGPoint(x: bc.x - 32, y: bc.y + 56))
bell.addCurve(to: CGPoint(x: bc.x - 48, y: bc.y - 26), control1: CGPoint(x: bc.x - 32, y: bc.y - 6), control2: CGPoint(x: bc.x - 34, y: bc.y - 14))
ctx.addPath(bell); ctx.fillPath()
ctx.fillEllipse(in: CGRect(x: bc.x - 14, y: bc.y - 52, width: 28, height: 28))

let url = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon/icon.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
