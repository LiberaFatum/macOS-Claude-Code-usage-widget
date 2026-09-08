import AppKit
import SwiftUI

/// Renders the menu content to a PNG so README screenshots stay reproducible.
enum Preview {
    @MainActor
    static func render(to path: String) {
        let view = UsageContentView(usage: UsageReader.read(), stats: StatsReader.read())
            .background(Color(nsColor: NSColor(calibratedWhite: 0.16, alpha: 1)))
            .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("Preview rendering failed.")
            return
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("Wrote \(path)")
        } catch {
            print("Could not write \(path): \(error)")
        }
    }
}
