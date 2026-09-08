// Vykreslí AppIcon.iconset s maskotem, aby repo neneslo binární přílohy.
// Kompiluje se dohromady se Sources/ClaudeUsage/Mascot.swift.
import AppKit

@main
enum IconMaker {
    static func main() {
        let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
        try? FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

        for (size, name) in [(16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"),
                             (64, "icon_32x32@2x"), (128, "icon_128x128"), (256, "icon_128x128@2x"),
                             (256, "icon_256x256"), (512, "icon_256x256@2x"), (512, "icon_512x512"),
                             (1024, "icon_512x512@2x")] {
            guard let png = render(size: size) else { continue }
            try? png.write(to: URL(fileURLWithPath: "\(output)/\(name).png"))
        }
        print("iconset zapsán do \(output)")
    }

static func render(size: Int) -> Data? {
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
    let plate = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    NSColor(srgbRed: 0.941, green: 0.933, blue: 0.902, alpha: 1).setFill() // krémová #F0EEE6
    NSBezierPath(roundedRect: plate, xRadius: side * 0.22, yRadius: side * 0.22).fill()

    // Celočíselná buňka a počátek, jinak antialiasing nechá mezi bloky světlé spáry.
    let cell = max(1, (plate.width * 0.72 / CGFloat(Mascot.cols)).rounded(.down))
    let artWidth = cell * CGFloat(Mascot.cols)
    let artHeight = cell * CGFloat(Mascot.rows.count)
    let originX = (plate.midX - artWidth / 2).rounded()
    let originY = (plate.midY - artHeight / 2).rounded()

    Mascot.color.setFill()
    for (r, row) in Mascot.rows.enumerated() {
        for (c, char) in row.enumerated() where char == "#" {
            // Řádky jdou shora dolů, souřadnice AppKitu zdola nahoru.
            let y = originY + CGFloat(Mascot.rows.count - 1 - r) * cell
            NSBezierPath(rect: NSRect(x: originX + CGFloat(c) * cell, y: y, width: cell, height: cell)).fill()
        }
    }

    NSGraphicsContext.current?.flushGraphics()
    return rep.representation(using: .png, properties: [:])
}
}
