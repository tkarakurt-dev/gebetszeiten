// Zeichnet das App-Icon (1024 px) und schreibt icon_1024.png
// Navy-Glasfläche, Countdown-Ring, Mondsichel mit Stern
import AppKit

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocusFlipped(true)
let ctx = NSGraphicsContext.current!.cgContext

// Icon-Form nach macOS-Raster (824 px Fläche, 100 px Rand)
let inset: CGFloat = 100
let body = NSRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

// Schatten
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 44, color: NSColor.black.withAlphaComponent(0.38).cgColor)
NSColor.black.setFill(); shape.fill()
ctx.restoreGState()

// Hintergrund: tiefes Navy, oben heller (CI-Farbe #455782)
ctx.saveGState()
shape.addClip()
NSGradient(colorsAndLocations:
    (NSColor(srgbRed: 0.33, green: 0.42, blue: 0.62, alpha: 1), 0.0),
    (NSColor(srgbRed: 0.18, green: 0.23, blue: 0.38, alpha: 1), 0.55),
    (NSColor(srgbRed: 0.07, green: 0.09, blue: 0.17, alpha: 1), 1.0))!
    .draw(in: body, angle: 90)
// weicher Lichtschein hinter dem Mond
NSGradient(colorsAndLocations: (NSColor(srgbRed: 0.70, green: 0.78, blue: 1.0, alpha: 0.30), 0.0), (NSColor.white.withAlphaComponent(0), 1.0))!
    .draw(in: NSBezierPath(ovalIn: NSRect(x: 212, y: 212, width: 600, height: 600)), relativeCenterPosition: .zero)
// Glanz oben (Glas)
let gloss = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: body.width, height: body.height * 0.48), xRadius: 185, yRadius: 185)
NSGradient(colors: [NSColor.white.withAlphaComponent(0.16), NSColor.white.withAlphaComponent(0)])!.draw(in: gloss, angle: 90)
ctx.restoreGState()

// Glaskante
let edge = NSBezierPath(roundedRect: body.insetBy(dx: 3, dy: 3), xRadius: 182, yRadius: 182)
edge.lineWidth = 6
NSColor.white.withAlphaComponent(0.22).setStroke(); edge.stroke()

let c = NSPoint(x: S / 2, y: S / 2)

// Countdown-Ring: dünner Grundring, darüber ein Bogen (ca. 3/4)
let R: CGFloat = 300
let base = NSBezierPath(); base.appendArc(withCenter: c, radius: R, startAngle: 0, endAngle: 360)
base.lineWidth = 26
NSColor.white.withAlphaComponent(0.14).setStroke(); base.stroke()

let arc = NSBezierPath()
// Im gespiegelten Koordinatensystem: -90° = oben, Bogen läuft im Uhrzeigersinn
arc.appendArc(withCenter: c, radius: R, startAngle: -90, endAngle: 180, clockwise: false)
arc.lineWidth = 26
arc.lineCapStyle = .round
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 24, color: NSColor(srgbRed: 0.75, green: 0.82, blue: 1, alpha: 0.7).cgColor)
NSColor.white.withAlphaComponent(0.95).setStroke(); arc.stroke()
ctx.restoreGState()

// Mondsichel: großer Kreis minus versetzter Kreis
let mr: CGFloat = 190
let moonCenter = NSPoint(x: c.x - 18, y: c.y + 6)
let moon = NSBezierPath(ovalIn: NSRect(x: moonCenter.x - mr, y: moonCenter.y - mr, width: mr * 2, height: mr * 2))
let cutRect = NSRect(x: moonCenter.x - mr + 92, y: moonCenter.y - mr - 52, width: mr * 2, height: mr * 2)
ctx.saveGState()
// Clip = alles außer dem versetzten Kreis, so bleibt nur die Sichel übrig
let outside = NSBezierPath(rect: NSRect(x: 0, y: 0, width: S, height: S))
outside.append(NSBezierPath(ovalIn: cutRect))
outside.windingRule = .evenOdd
outside.addClip()
ctx.setShadow(offset: .zero, blur: 30, color: NSColor(srgbRed: 0.85, green: 0.9, blue: 1, alpha: 0.6).cgColor)
NSGradient(colors: [NSColor.white, NSColor(srgbRed: 0.84, green: 0.88, blue: 0.98, alpha: 1)])!.draw(in: moon, angle: 90)
ctx.restoreGState()

// Stern rechts oben in der Öffnung der Sichel
func star(center: NSPoint, outer: CGFloat, inner: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    for i in 0..<10 {
        let r = i % 2 == 0 ? outer : inner
        let a = CGFloat(i) * .pi / 5 - .pi / 2
        let pt = NSPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
        i == 0 ? p.move(to: pt) : p.line(to: pt)
    }
    p.close()
    return p
}
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 18, color: NSColor.white.withAlphaComponent(0.7).cgColor)
NSColor.white.setFill()
star(center: NSPoint(x: c.x + 118, y: c.y - 70), outer: 50, inner: 21).fill()
ctx.restoreGState()

img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "icon_1024.png"))
print("icon_1024.png geschrieben")
