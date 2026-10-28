// Draws Giro's 1024×1024 app icon: a chunky die inside a loop of road, with the yellow pawn on it.
// Run: swift tools/make_icon.swift Giro/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import CoreGraphics

func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: a)
}

let S = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Flip so y grows downward, like a design canvas.
ctx.translateBy(x: 0, y: CGFloat(S)); ctx.scaleBy(x: 1, y: -1)

// Background: peach sky fading to warm orange.
let bg = CGGradient(colorsSpace: cs, colors: [rgb(0xFBE0B8), rgb(0xF5A04A)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: 1024), options: [])

// The loop of road, seen slightly from above.
let center = CGPoint(x: 512, y: 600)
let ring = CGRect(x: center.x - 390, y: center.y - 250, width: 780, height: 500)
ctx.setStrokeColor(rgb(0xB85E14, 0.35)); ctx.setLineWidth(130)
ctx.strokeEllipse(in: ring.offsetBy(dx: 0, dy: 18))
ctx.setStrokeColor(rgb(0xF4E4C6)); ctx.setLineWidth(130)
ctx.strokeEllipse(in: ring)
ctx.setStrokeColor(rgb(0xFFFFFF, 0.9)); ctx.setLineWidth(14)
ctx.setLineDash(phase: 0, lengths: [44, 36]); ctx.setLineCap(.round)
ctx.strokeEllipse(in: ring)
ctx.setLineDash(phase: 0, lengths: [])

// The die, tilted, with a soft shadow.
func roundedRect(_ r: CGRect, _ rad: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil) }
ctx.saveGState()
ctx.translateBy(x: 512, y: 470); ctx.rotate(by: -0.2)
let d: CGFloat = 400
let face = CGRect(x: -d / 2, y: -d / 2, width: d, height: d)
ctx.addPath(roundedRect(face.offsetBy(dx: 10, dy: 34), 92)); ctx.setFillColor(rgb(0x8A4A10, 0.35)); ctx.fillPath()
ctx.addPath(roundedRect(face.offsetBy(dx: 0, dy: 22), 92)); ctx.setFillColor(rgb(0xE7C9A2)); ctx.fillPath()
ctx.addPath(roundedRect(face, 92)); ctx.setFillColor(rgb(0xFFFDF8)); ctx.fillPath()
let pip: CGFloat = 70, o: CGFloat = 104
for p in [CGPoint(x: -o, y: -o), CGPoint(x: o, y: -o), CGPoint(x: -o, y: o), CGPoint(x: o, y: o)] {
    ctx.setFillColor(rgb(0x4A2E1B)); ctx.fillEllipse(in: CGRect(x: p.x - pip / 2, y: p.y - pip / 2, width: pip, height: pip))
}
ctx.setFillColor(rgb(0xE5533D)); ctx.fillEllipse(in: CGRect(x: -pip / 2 - 6, y: -pip / 2 - 6, width: pip + 12, height: pip + 12))
ctx.restoreGState()

// The yellow pawn on the road, front left.
let px: CGFloat = 250, py: CGFloat = 770
ctx.setFillColor(rgb(0x8A4A10, 0.3)); ctx.fillEllipse(in: CGRect(x: px - 70, y: py + 70, width: 140, height: 36))
ctx.setFillColor(rgb(0xF5B700))
ctx.fillEllipse(in: CGRect(x: px - 62, y: py - 40, width: 124, height: 130))   // body
ctx.fillEllipse(in: CGRect(x: px - 50, y: py - 130, width: 100, height: 100))  // head
ctx.setFillColor(rgb(0x2B1A10))
ctx.fillEllipse(in: CGRect(x: px - 24, y: py - 92, width: 16, height: 18))
ctx.fillEllipse(in: CGRect(x: px + 8, y: py - 92, width: 16, height: 18))
ctx.setFillColor(rgb(0xFFFFFF, 0.45))
ctx.fillEllipse(in: CGRect(x: px - 30, y: py - 118, width: 30, height: 22))

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote", CommandLine.arguments[1])
