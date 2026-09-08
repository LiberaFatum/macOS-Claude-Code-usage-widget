// Renders AppIcon.iconset from code so the repo carries no binary blobs.
// Usage: swift Tools/make-icon.swift <output-iconset-dir>
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

func render(size: Int) -> Data? {
    let side = CGFloat(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = side * 0.06
    let rect = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let body = NSBezierPath(roundedRect: rect, xRadius: side * 0.22, yRadius: side * 0.22)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.85, green: 0.45, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.71, green: 0.27, blue: 0.13, alpha: 1)
    ])?.draw(in: body, angle: -90)

    // Gauge arc + needle.
    let center = NSPoint(x: rect.midX, y: rect.midY - side * 0.06)
    let radius = side * 0.26
    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: radius, startAngle: 200, endAngle: -20, clockwise: true)
    track.lineWidth = side * 0.09
    track.lineCapStyle = .round
    NSColor(calibratedWhite: 1, alpha: 0.30).setStroke()
    track.stroke()

    let filled = NSBezierPath()
    filled.appendArc(withCenter: center, radius: radius, startAngle: 200, endAngle: 70, clockwise: true)
    filled.lineWidth = side * 0.09
    filled.lineCapStyle = .round
    NSColor.white.setStroke()
    filled.stroke()

    let needle = NSBezierPath()
    needle.move(to: center)
    needle.line(to: NSPoint(x: center.x + radius * 0.85 * cos(70 * .pi / 180),
                            y: center.y + radius * 0.85 * sin(70 * .pi / 180)))
    needle.lineWidth = side * 0.045
    needle.lineCapStyle = .round
    NSColor.white.setStroke()
    needle.stroke()

    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - side * 0.04, y: center.y - side * 0.04,
                                width: side * 0.08, height: side * 0.08)).fill()

    NSGraphicsContext.current?.flushGraphics()
    return rep.representation(using: .png, properties: [:])
}

for (size, name) in [(16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"),
                     (64, "icon_32x32@2x"), (128, "icon_128x128"), (256, "icon_128x128@2x"),
                     (256, "icon_256x256"), (512, "icon_256x256@2x"), (512, "icon_512x512"),
                     (1024, "icon_512x512@2x")] {
    guard let png = render(size: size) else { continue }
    try? png.write(to: URL(fileURLWithPath: "\(output)/\(name).png"))
}
print("iconset written to \(output)")
