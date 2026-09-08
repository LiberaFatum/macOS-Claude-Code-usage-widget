import Foundation

/// Ceník Claude API v USD za milion tokenů.
/// Zdroj: https://platform.claude.com/docs/en/about-claude/pricing (ověřeno 2026-09-08).
struct ModelPrice {
    let input: Double
    let cacheWrite: Double   // 5minutový zápis do cache
    let cacheRead: Double
    let output: Double
}

enum Pricing {
    /// Klíč je prefix ID modelu, hledá se od nejdelšího shodného.
    static let table: [String: ModelPrice] = [
        "claude-fable-5-1":  ModelPrice(input: 10, cacheWrite: 12.50, cacheRead: 0.25, output: 50),
        "claude-mythos-5-1": ModelPrice(input: 10, cacheWrite: 12.50, cacheRead: 0.25, output: 50),
        "claude-fable-5":    ModelPrice(input: 10, cacheWrite: 12.50, cacheRead: 1.00, output: 50),
        "claude-mythos-5":   ModelPrice(input: 10, cacheWrite: 12.50, cacheRead: 1.00, output: 50),
        "claude-opus-5":     ModelPrice(input: 5, cacheWrite: 6.25, cacheRead: 0.50, output: 25),
        "claude-opus-4-8":   ModelPrice(input: 5, cacheWrite: 6.25, cacheRead: 0.50, output: 25),
        "claude-opus-4-7":   ModelPrice(input: 5, cacheWrite: 6.25, cacheRead: 0.50, output: 25),
        "claude-opus-4-6":   ModelPrice(input: 5, cacheWrite: 6.25, cacheRead: 0.50, output: 25),
        "claude-opus-4-5":   ModelPrice(input: 5, cacheWrite: 6.25, cacheRead: 0.50, output: 25),
        "claude-opus-4-1":   ModelPrice(input: 15, cacheWrite: 18.75, cacheRead: 1.50, output: 75),
        "claude-sonnet-5":   ModelPrice(input: 2, cacheWrite: 2.50, cacheRead: 0.20, output: 10),
        "claude-sonnet-4-6": ModelPrice(input: 3, cacheWrite: 3.75, cacheRead: 0.30, output: 15),
        "claude-sonnet-4-5": ModelPrice(input: 3, cacheWrite: 3.75, cacheRead: 0.30, output: 15),
        "claude-haiku-4-5":  ModelPrice(input: 1, cacheWrite: 1.25, cacheRead: 0.10, output: 5),
        "claude-haiku-3-5":  ModelPrice(input: 0.80, cacheWrite: 1.00, cacheRead: 0.08, output: 4)
    ]

    static func price(for modelID: String) -> ModelPrice? {
        table.keys
            .filter { modelID.hasPrefix($0) }
            .max(by: { $0.count < $1.count })
            .flatMap { table[$0] }
    }

    static func cost(of totals: ModelTotals, model: String) -> Double? {
        guard let p = price(for: model) else { return nil }
        return (Double(totals.input) * p.input
            + Double(totals.output) * p.output
            + Double(totals.cacheRead) * p.cacheRead
            + Double(totals.cacheCreation) * p.cacheWrite) / 1_000_000
    }
}
