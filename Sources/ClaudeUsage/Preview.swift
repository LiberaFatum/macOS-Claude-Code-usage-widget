import AppKit
import SwiftUI

/// Renders the menu content to a PNG so README screenshots stay reproducible.
enum Preview {
    @MainActor
    static func render(to path: String) {
        // Snímek do dokumentace má ukazovat čerstvá čísla, ne cache, takže se
        // živé čtení zkouší vždy a na jeho nezdaru nezáleží.
        var usage = UsageReader.read()
        let done = DispatchSemaphore(value: 0)
        UsageAPI.fetch { result in
            switch result {
            case .success(let snapshot): usage = snapshot
            case .failure(let error): print("Živé čtení pro snímek selhalo: \(error)")
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + 12)

        let view = UsageContentView(usage: usage, stats: StatsReader.read())
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
