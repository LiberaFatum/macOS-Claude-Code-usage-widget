import SwiftUI

enum Fmt {
    /// 11_228_181_785 -> "11,23 mld."
    static func tokens(_ value: Int) -> String {
        let v = Double(value)
        switch abs(v) {
        case 1_000_000_000...: return decimal(v / 1_000_000_000, places: 2) + " mld."
        case 1_000_000...:     return decimal(v / 1_000_000, places: 1) + " mil."
        case 1_000...:         return decimal(v / 1_000, places: 1) + " tis."
        default:               return grouped(value)
        }
    }

    /// 1234.5 -> "1 234,50 $"
    static func money(_ usd: Double) -> String {
        let places = abs(usd) >= 100 ? 0 : 2
        return decimal(usd, places: places) + " $"
    }

    static func grouped(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{00a0}"
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func decimal(_ value: Double, places: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{00a0}"
        f.decimalSeparator = ","
        f.minimumFractionDigits = places
        f.maximumFractionDigits = places
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.\(places)f", value)
    }

    /// "2 h 34 m" / "5 d 23 h" / "resetuje se"
    static func countdown(to date: Date?) -> String {
        guard let date else { return "?" }
        let seconds = Int(date.timeIntervalSinceNow)
        if seconds <= 0 { return "resetuje se" }
        let d = seconds / 86400, h = (seconds % 86400) / 3600, m = (seconds % 3600) / 60
        if d > 0 { return "\(d) d \(h) h" }
        if h > 0 { return "\(h) h \(m) m" }
        return "\(m) m"
    }

    /// "právě teď" / "před 4 min" / "před 3 h"
    static func ago(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "právě teď" }
        if seconds < 3600 { return "před \(seconds / 60) min" }
        if seconds < 86400 { return "před \(seconds / 3600) h" }
        return "před \(seconds / 86400) dny"
    }

    /// Kompaktní tvar do hlavičky: "teď" / "6 min" / "3 h" / "2 dny"
    static func agoShort(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "teď" }
        if seconds < 3600 { return "\(seconds / 60) min" }
        if seconds < 86400 { return "\(seconds / 3600) h" }
        return "\(seconds / 86400) dny"
    }

    static func color(forPercent percent: Double) -> Color {
        switch percent {
        case ..<50: return .green
        case ..<80: return .yellow
        case ..<95: return .orange
        default: return .red
        }
    }

    /// "claude-haiku-4-5-20251001" -> "Haiku 4.5"
    static func modelName(_ id: String) -> String {
        var name = id
        if name.hasPrefix("claude-") { name.removeFirst("claude-".count) }
        let parts = name.split(separator: "-").filter { !($0.count == 8 && Int($0) != nil) }
        guard let family = parts.first else { return id }
        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? family.capitalized : "\(family.capitalized) \(version)"
    }

    /// Monocraft, s bezpečným ústupem na systémový monospace, když font chybí.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let face = weight == .regular ? "Monocraft" : "Monocraft-SemiBold"
        if NSFont(name: face, size: size) != nil {
            return .custom(face, fixedSize: size)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    static func monoNS(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let face = weight == .regular ? "Monocraft" : "Monocraft-SemiBold"
        return NSFont(name: face, size: size)
            ?? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
    }
}
