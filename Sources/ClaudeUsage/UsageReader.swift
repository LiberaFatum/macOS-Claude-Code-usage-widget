import Foundation

/// One rate-limit bucket as reported by Claude Code in `~/.claude.json`.
struct LimitEntry: Identifiable {
    let id = UUID()
    let kind: String        // "session" | "weekly_all" | "weekly_scoped" | ...
    let group: String       // "session" | "weekly"
    let percent: Double     // 0...100
    let severity: String    // "normal" | "warning" | ...
    let resetsAt: Date?
    let scopeLabel: String? // e.g. "Opus" for weekly_scoped
    let isActive: Bool

    var title: String {
        switch kind {
        case "session": return "Session (5h)"
        case "weekly_all": return "Weekly"
        case "weekly_scoped": return "Weekly · \(scopeLabel ?? "scoped")"
        default: return scopeLabel ?? kind.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

struct UsageSnapshot {
    let fetchedAt: Date
    let limits: [LimitEntry]

    var session: LimitEntry? { limits.first { $0.kind == "session" } }
    var weeklyAll: LimitEntry? { limits.first { $0.kind == "weekly_all" } }
    var weeklyScoped: [LimitEntry] { limits.filter { $0.kind == "weekly_scoped" } }

    /// How stale the cached numbers are. Claude Code only refreshes them while it runs.
    var age: TimeInterval { Date().timeIntervalSince(fetchedAt) }
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
        let fetchedAt = Date(timeIntervalSince1970: fetchedMs / 1000)
        let util = cached["utilization"] as? [String: Any] ?? [:]

        var entries: [LimitEntry] = []

        if let raw = util["limits"] as? [[String: Any]] {
            for item in raw {
                guard let kind = item["kind"] as? String,
                      let percent = item["percent"] as? Double else { continue }
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

        // Older Claude Code builds only expose the five_hour / seven_day objects.
        if entries.isEmpty {
            if let e = legacy(util["five_hour"], kind: "session", group: "session") { entries.append(e) }
            if let e = legacy(util["seven_day"], kind: "weekly_all", group: "weekly") { entries.append(e) }
        }

        return UsageSnapshot(fetchedAt: fetchedAt, limits: entries)
    }

    private static func legacy(_ any: Any?, kind: String, group: String) -> LimitEntry? {
        guard let dict = any as? [String: Any],
              let percent = dict["utilization"] as? Double else { return nil }
        return LimitEntry(
            kind: kind, group: group, percent: percent, severity: "normal",
            resetsAt: parseDate(dict["resets_at"] as? String),
            scopeLabel: nil, isActive: false
        )
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
