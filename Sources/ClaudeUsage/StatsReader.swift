import Foundation

struct ModelTotals {
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheCreation = 0

    var total: Int { input + output + cacheRead + cacheCreation }
}

struct DailyPoint: Identifiable {
    let id = UUID()
    let date: Date
    let tokens: Int
}

struct StatsSnapshot {
    let lastComputed: String
    let daily: [DailyPoint]                 // ascending by date, total tokens per day
    let dailyByModel: [String: [Date: Int]] // model -> day -> tokens
    let modelUsage: [String: ModelTotals]
    let totalSessions: Int
    let totalMessages: Int
    let firstSessionDate: Date?
    let modifiedAt: Date

    var allTimeTokens: Int { modelUsage.values.reduce(0) { $0 + $1.total } }

    var allTimeTotals: ModelTotals {
        modelUsage.values.reduce(into: ModelTotals()) { acc, m in
            acc.input += m.input
            acc.output += m.output
            acc.cacheRead += m.cacheRead
            acc.cacheCreation += m.cacheCreation
        }
    }

    /// Sum of daily tokens over the last `days` calendar days (today inclusive).
    func tokens(lastDays days: Int) -> Int {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: Date())) else { return 0 }
        return daily.filter { $0.date >= cutoff }.reduce(0) { $0 + $1.tokens }
    }

    /// Continuous series for the last `days` days — days without any usage become 0
    /// so the chart keeps a truthful time axis instead of squeezing gaps shut.
    ///
    /// The series ends on the last day Claude Code actually computed, otherwise today
    /// would always render as a drop to zero just because the cache has not caught up.
    func recent(days: Int) -> [DailyPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let end = min(daily.last?.date ?? today, today)
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: end) else { return daily }
        var lookup: [Date: Int] = [:]
        for point in daily where point.date >= start {
            lookup[cal.startOfDay(for: point.date)] = point.tokens
        }
        return (0..<days).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DailyPoint(date: day, tokens: lookup[day] ?? 0)
        }
    }

    /// Přesná cena podle API ceníku ze všech evidovaných tokenů (rozpad na typy je známý).
    var allTimeCost: Double {
        modelUsage.reduce(0.0) { $0 + (Pricing.cost(of: $1.value, model: $1.key) ?? 0) }
    }

    /// Kolik z all-time tokenů daného modelu nemá známou cenu (neznámý model v ceníku).
    var unpricedModels: [String] {
        modelUsage.keys.filter { Pricing.price(for: $0) == nil }.sorted()
    }

    /// Odhad ceny za posledních `days` dní.
    ///
    /// `dailyModelTokens` drží jen součet tokenů na model a den, bez rozpadu na
    /// input/output/cache. Rozpad se proto odvodí z all-time poměru téhož modelu.
    func estimatedCost(lastDays days: Int) -> Double {
        var total = 0.0
        for (model, tokens) in modelBreakdown(lastDays: days) {
            guard let reference = modelUsage[model], reference.total > 0,
                  let cost = Pricing.cost(of: reference, model: model) else { continue }
            total += cost * Double(tokens) / Double(reference.total)
        }
        return total
    }

    /// Per-model share over the last `days` days, biggest first.
    func modelBreakdown(lastDays days: Int) -> [(model: String, tokens: Int)] {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: Date())) else { return [] }
        var out: [String: Int] = [:]
        for (model, byDay) in dailyByModel {
            for (day, tokens) in byDay where day >= cutoff {
                out[model, default: 0] += tokens
            }
        }
        return out.map { (model: $0.key, tokens: $0.value) }.sorted { $0.tokens > $1.tokens }
    }
}

enum StatsReader {
    static var path: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/stats-cache.json")
    }

    static func read() -> StatsSnapshot? {
        guard let data = try? Data(contentsOf: path),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }

        var daily: [DailyPoint] = []
        var byModel: [String: [Date: Int]] = [:]

        for entry in root["dailyModelTokens"] as? [[String: Any]] ?? [] {
            guard let dateString = entry["date"] as? String,
                  let day = dayFormatter.date(from: dateString),
                  let tokens = entry["tokensByModel"] as? [String: Any] else { continue }
            var sum = 0
            for (model, value) in tokens {
                let count = (value as? Int) ?? Int((value as? Double) ?? 0)
                sum += count
                byModel[model, default: [:]][day, default: 0] += count
            }
            daily.append(DailyPoint(date: day, tokens: sum))
        }
        daily.sort { $0.date < $1.date }

        var usage: [String: ModelTotals] = [:]
        for (model, value) in root["modelUsage"] as? [String: Any] ?? [:] {
            guard let d = value as? [String: Any] else { continue }
            usage[model] = ModelTotals(
                input: int(d["inputTokens"]),
                output: int(d["outputTokens"]),
                cacheRead: int(d["cacheReadInputTokens"]),
                cacheCreation: int(d["cacheCreationInputTokens"])
            )
        }

        var firstSession: Date?
        if let raw = root["firstSessionDate"] as? String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            firstSession = f.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        }

        let mtime = (try? FileManager.default.attributesOfItem(atPath: path.path)[.modificationDate] as? Date) ?? nil

        return StatsSnapshot(
            lastComputed: root["lastComputedDate"] as? String ?? "—",
            daily: daily,
            dailyByModel: byModel,
            modelUsage: usage,
            totalSessions: int(root["totalSessions"]),
            totalMessages: int(root["totalMessages"]),
            firstSessionDate: firstSession,
            modifiedAt: mtime ?? Date.distantPast
        )
    }

    private static func int(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        return 0
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
