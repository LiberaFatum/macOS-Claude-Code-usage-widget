import SwiftUI

enum Fmt {
    /// 11_228_181_785 -> "11.23B"
    static func tokens(_ value: Int) -> String {
        let v = Double(value)
        switch abs(v) {
        case 1_000_000_000...: return String(format: "%.2fB", v / 1_000_000_000)
        case 1_000_000...:     return String(format: "%.1fM", v / 1_000_000)
        case 1_000...:         return String(format: "%.1fK", v / 1_000)
        default:               return "\(value)"
        }
    }

    static func grouped(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "2h 34m" / "5d 23h" / "resets now"
    static func countdown(to date: Date?) -> String {
        guard let date else { return "—" }
        let seconds = Int(date.timeIntervalSinceNow)
        if seconds <= 0 { return "resetting" }
        let d = seconds / 86400, h = (seconds % 86400) / 3600, m = (seconds % 3600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// "just now" / "4 min ago" / "3 h ago"
    static func ago(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60) min ago" }
        if seconds < 86400 { return "\(seconds / 3600) h ago" }
        return "\(seconds / 86400) d ago"
    }

    static func color(forPercent percent: Double) -> Color {
        switch percent {
        case ..<50: return .green
        case ..<80: return .yellow
        case ..<95: return .orange
        default: return .red
        }
    }

    /// "claude-opus-4-5-20251101" -> "Opus 4.5"
    static func modelName(_ id: String) -> String {
        var name = id
        if name.hasPrefix("claude-") { name.removeFirst("claude-".count) }
        let parts = name.split(separator: "-").filter { !($0.count == 8 && Int($0) != nil) }
        guard let family = parts.first else { return id }
        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? family.capitalized : "\(family.capitalized) \(version)"
    }
}
