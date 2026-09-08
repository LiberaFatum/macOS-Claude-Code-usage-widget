import Foundation

/// Jeden limitní koš tak, jak ho hlásí Claude Code.
struct LimitEntry: Identifiable {
    let id = UUID()
    let kind: String        // "session" | "weekly_all" | "weekly_scoped" | ...
    let group: String       // "session" | "weekly"
    let percent: Double     // 0...100
    let severity: String
    let resetsAt: Date?
    let scopeLabel: String? // např. "Opus" u weekly_scoped
    let isActive: Bool

    var title: String {
        switch kind {
        case "session": return "Session (5 h)"
        case "weekly_all": return "Weekly"
        case "weekly_scoped": return "Weekly · \(scopeLabel ?? "scoped")"
        default: return scopeLabel ?? kind.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

struct UsageSnapshot {
    enum Source {
        case api    // živě z /api/oauth/usage
        case cache  // z ~/.claude.json, obnovuje ho Claude Code
    }

    let fetchedAt: Date
    let limits: [LimitEntry]
    let source: Source

    var session: LimitEntry? { limits.first { $0.kind == "session" } }
    var weeklyAll: LimitEntry? { limits.first { $0.kind == "weekly_all" } }
    var weeklyScoped: [LimitEntry] { limits.filter { $0.kind == "weekly_scoped" } }

    var age: TimeInterval { Date().timeIntervalSince(fetchedAt) }
    var isStale: Bool { source == .cache && age > 15 * 60 }

    var freshnessLabel: String {
        (source == .api ? "živě · " : "cache · ") + Fmt.elapsed(since: fetchedAt)
    }
}

enum UsageReader {
    static var path: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    static func read() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: path),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let cached = root["cachedUsageUtilization"] as? [String: Any] else { return nil }

        let fetchedMs = cached["fetchedAtMs"] as? Double ?? 0
        let util = cached["utilization"] as? [String: Any] ?? [:]

        return UsageSnapshot(
            fetchedAt: Date(timeIntervalSince1970: fetchedMs / 1000),
            limits: limits(from: util),
            source: .cache
        )
    }

    /// Vytáhne limity z objektu `utilization`, ať přijde z API nebo ze souboru.
    static func limits(from util: [String: Any]) -> [LimitEntry] {
        var entries: [LimitEntry] = []

        if let raw = util["limits"] as? [[String: Any]] {
            for item in raw {
                guard let kind = item["kind"] as? String,
                      let percent = number(item["percent"]) else { continue }
                var scopeLabel: String?
                if let scope = item["scope"] as? [String: Any],
                   let model = scope["model"] as? [String: Any] {
                    scopeLabel = model["display_name"] as? String
                }
                entries.append(LimitEntry(
                    kind: kind,
                    group: item["group"] as? String ?? kind,
                    percent: percent,
                    severity: item["severity"] as? String ?? "normal",
                    resetsAt: parseDate(item["resets_at"] as? String),
                    scopeLabel: scopeLabel,
                    isActive: item["is_active"] as? Bool ?? false
                ))
            }
        }

        // Starší tvar odpovědi nese jen five_hour / seven_day.
        if entries.isEmpty {
            if let e = legacy(util["five_hour"], kind: "session", group: "session") { entries.append(e) }
            if let e = legacy(util["seven_day"], kind: "weekly_all", group: "weekly") { entries.append(e) }
        }

        return entries
    }

    private static func legacy(_ any: Any?, kind: String, group: String) -> LimitEntry? {
        guard let dict = any as? [String: Any],
              let percent = number(dict["utilization"]) else { return nil }
        return LimitEntry(
            kind: kind, group: group, percent: percent, severity: "normal",
            resetsAt: parseDate(dict["resets_at"] as? String),
            scopeLabel: nil, isActive: false
        )
    }

    private static func number(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        return nil
    }

    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: string) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
