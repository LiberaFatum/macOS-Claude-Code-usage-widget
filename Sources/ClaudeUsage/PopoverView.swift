import SwiftUI

struct UsageContentView: View {
    let usage: UsageSnapshot?
    let stats: StatsSnapshot?
    var onOpenStatsFolder: () -> Void = {}

    private let width: CGFloat = 340

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if let usage, !usage.limits.isEmpty {
                VStack(spacing: 8) {
                    ForEach(usage.limits.filter { $0.kind != "weekly_scoped" || $0.percent > 0 }) { limit in
                        LimitRow(limit: limit)
                    }
                }
                if usage.age > 15 * 60 {
                    staleNote(usage: usage)
                }
            } else {
                missingNote(
                    text: "No usage data in ~/.claude.json yet.",
                    detail: "Start a Claude Code session once — it caches the limits on launch."
                )
            }

            Divider().opacity(0.4)

            if let stats {
                TokenChart(points: stats.recent(days: Preferences.chartDays))
                    .frame(height: 74)

                tokenTotals(stats)
                Divider().opacity(0.4)
                footer(stats)
            } else {
                missingNote(
                    text: "No token stats found.",
                    detail: "~/.claude/stats-cache.json is written by Claude Code itself."
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: width, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .foregroundStyle(.secondary)
            Text("Claude Code Usage")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if let usage {
                Text(Fmt.ago(usage.fetchedAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func staleNote(usage: UsageSnapshot) -> some View {
        Label(
            "Limits are a cache — last refreshed \(Fmt.ago(usage.fetchedAt)). Run Claude Code to update.",
            systemImage: "exclamationmark.triangle"
        )
        .font(.system(size: 10))
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func missingNote(text: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text).font(.system(size: 11, weight: .medium))
            Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tokenTotals(_ stats: StatsSnapshot) -> some View {
        HStack(spacing: 0) {
            TotalCell(caption: "7 days", value: stats.tokens(lastDays: 7))
            Divider().frame(height: 26).opacity(0.35)
            TotalCell(caption: "30 days", value: stats.tokens(lastDays: 30))
            Divider().frame(height: 26).opacity(0.35)
            TotalCell(caption: "All time", value: stats.allTimeTokens)
        }
    }

    private func footer(_ stats: StatsSnapshot) -> some View {
        let totals = stats.allTimeTotals
        return VStack(alignment: .leading, spacing: 3) {
            FooterRow(icon: "arrow.down.circle", label: "Input / Output",
                      value: "\(Fmt.tokens(totals.input)) / \(Fmt.tokens(totals.output))")
            FooterRow(icon: "externaldrive", label: "Cache read / write",
                      value: "\(Fmt.tokens(totals.cacheRead)) / \(Fmt.tokens(totals.cacheCreation))")
            FooterRow(icon: "bubble.left.and.bubble.right", label: "Sessions / messages",
                      value: "\(Fmt.grouped(stats.totalSessions)) / \(Fmt.grouped(stats.totalMessages))")
            if let top = stats.modelBreakdown(lastDays: 7).first {
                FooterRow(icon: "cpu", label: "Top model (7d)",
                          value: "\(Fmt.modelName(top.model)) · \(Fmt.tokens(top.tokens))")
            }
            Text("Stats computed \(stats.lastComputed)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .padding(.top, 1)
        }
    }
}

private struct TotalCell: View {
    let caption: String
    let value: Int

    var body: some View {
        VStack(spacing: 1) {
            Text(Fmt.tokens(value))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(caption)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .help("\(Fmt.grouped(value)) tokens")
    }
}

private struct FooterRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: 12)
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value).font(.system(size: 10)).monospacedDigit()
        }
    }
}

struct LimitRow: View {
    let limit: LimitEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: limit.group == "session" ? "timer" : "calendar")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(width: 13)
                Text(limit.title)
                    .font(.system(size: 11, weight: limit.isActive ? .semibold : .regular))
                Spacer(minLength: 6)
                Text("\(Int(limit.percent.rounded()))%")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Fmt.color(forPercent: limit.percent))
            }
            ProgressBar(percent: limit.percent)
            HStack {
                Spacer()
                Text("resets in \(Fmt.countdown(to: limit.resetsAt))")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct ProgressBar: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(Fmt.color(forPercent: percent))
                    .frame(width: max(2, geo.size.width * min(percent, 100) / 100))
            }
        }
        .frame(height: 5)
    }
}

/// Sparkline of daily token totals, styled after the graph in Hot.app's menu.
struct TokenChart: View {
    let points: [DailyPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Canvas { context, size in
                let gridColor = Color.primary.opacity(0.10)
                let rows = 5
                for i in 0...rows {
                    let y = size.height * CGFloat(i) / CGFloat(rows)
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(line, with: .color(gridColor), lineWidth: 0.5)
                }

                guard points.count > 1, let peak = points.map(\.tokens).max(), peak > 0 else { return }

                let step = size.width / CGFloat(points.count - 1)
                func point(_ index: Int) -> CGPoint {
                    let value = CGFloat(points[index].tokens) / CGFloat(peak)
                    return CGPoint(x: CGFloat(index) * step, y: size.height - value * (size.height - 4) - 2)
                }

                var line = Path()
                line.move(to: point(0))
                for i in 1..<points.count { line.addLine(to: point(i)) }

                var fill = line
                fill.addLine(to: CGPoint(x: size.width, y: size.height))
                fill.addLine(to: CGPoint(x: 0, y: size.height))
                fill.closeSubpath()

                context.fill(fill, with: .linearGradient(
                    Gradient(colors: [Color.orange.opacity(0.28), Color.orange.opacity(0.02)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
                context.stroke(line, with: .color(.orange), lineWidth: 1.4)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.12)))
            )

            HStack(spacing: 4) {
                Circle().fill(Color.orange).frame(width: 6, height: 6)
                Text("Tokens / day · last \(points.count) d")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                if let peak = points.map(\.tokens).max() {
                    Text("peak \(Fmt.tokens(peak))")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
