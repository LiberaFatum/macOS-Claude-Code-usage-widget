import AppKit

/// Pixelový maskot Claude, 17 x 11 buněk.
/// Mřížka je odečtená z předlohy, `#` je vybarvená buňka.
enum Mascot {
    static let color = NSColor(srgbRed: 0.843, green: 0.467, blue: 0.341, alpha: 1) // #D77757

    static let rows = [
        "..#############..",
        "..#############..",
        "..##.#######.##..",
        "..##.#######.##..",
        "#################",
        "#################",
        "#################",
        "..#############..",
        "..#############..",
        "....#.#...#.#....",
        "....#.#...#.#...."
    ]

    static var cols: Int { rows[0].count }

    /// Ikona do lišty. `cell` je velikost jedné buňky v bodech; při 1.5 vychází
    /// na retina displeji přesně 3 fyzické pixely, takže hrany zůstanou ostré.
    static func statusBarImage(cell: CGFloat = 1.5, color: NSColor = color) -> NSImage {
        let size = NSSize(width: cell * CGFloat(cols), height: cell * CGFloat(rows.count))
        let image = NSImage(size: size, flipped: true) { _ in
            color.setFill()
            for (r, row) in rows.enumerated() {
                for (c, char) in row.enumerated() where char == "#" {
                    NSBezierPath(rect: NSRect(
                        x: CGFloat(c) * cell,
                        y: CGFloat(r) * cell,
                        width: cell,
                        height: cell
                    )).fill()
                }
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
