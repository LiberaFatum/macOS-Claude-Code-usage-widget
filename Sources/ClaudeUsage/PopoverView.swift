import SwiftUI

struct UsageContentView: View {
    let usage: UsageSnapshot?
    let stats: StatsSnapshot?

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
            } else {
                note("V ~/.claude.json zatím nejsou data o limitech.",
                     "Spusť jednou Claude Code, uloží si je do cache.")
            }

            Divider().opacity(0.4)

            if let stats {
                TokenChart(points: stats.recent(days: Preferences.chartDays))
                    .frame(height: 74)

                tokenTotals(stats)
                Divider().opacity(0.4)
                costSection(stats)
                Divider().opacity(0.4)
                details(stats)
            } else {
                note("Statistiky tokenů nenalezeny.",
                     "Soubor ~/.claude/stats-cache.json zapisuje sám Claude Code.")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: width, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 6) {
            MascotBadge(cell: 1.2)
            Text("Spotřeba Claude Code")
                .font(Fmt.mono(12, weight: .semibold))
            Spacer()
            if let usage {
                Text(Fmt.ago(usage.fetchedAt))
                    .font(Fmt.mono(9))
                    .foregroundStyle(usage.age > 15 * 60 ? Color.orange : Color.secondary)
                    .help("Údaje o limitech pocházejí z cache, kterou obnovuje sám Claude Code (zhruba jednou za 5 minut).")
            }
        }
    }

    private func note(_ text: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text).font(Fmt.mono(10, weight: .semibold))
            Text(detail).font(Fmt.mono(9)).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tokenTotals(_ stats: StatsSnapshot) -> some View {
        HStack(spacing: 0) {
            TotalCell(caption: "7 dní", value: Fmt.tokens(stats.tokens(lastDays: 7)))
            Divider().frame(height: 26).opacity(0.35)
            TotalCell(caption: "30 dní", value: Fmt.tokens(stats.tokens(lastDays: 30)))
            Divider().frame(height: 26).opacity(0.35)
            TotalCell(caption: "celkem", value: Fmt.tokens(stats.allTimeTokens))
        }
    }

    private func costSection(_ stats: StatsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Kdyby to šlo přes API")
                    .font(Fmt.mono(10, weight: .semibold))
                Spacer()
                Text("ceník Claude API")
                    .font(Fmt.mono(8))
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 0) {
                TotalCell(caption: "7 dní", value: Fmt.money(stats.estimatedCost(lastDays: 7)), tint: .orange)
                Divider().frame(height: 26).opacity(0.35)
                TotalCell(caption: "30 dní", value: Fmt.money(stats.estimatedCost(lastDays: 30)), tint: .orange)
                Divider().frame(height: 26).opacity(0.35)
                TotalCell(caption: "celkem", value: Fmt.money(stats.allTimeCost), tint: .orange)
            }
            Text("Celkem je přesné, 7 a 30 dní odhad z poměru typů tokenů.")
                .font(Fmt.mono(8))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func details(_ stats: StatsSnapshot) -> some View {
        let totals = stats.allTimeTotals
        return VStack(alignment: .leading, spacing: 3) {
            DetailRow(label: "Input / output",
                      value: "\(Fmt.tokens(totals.input)) / \(Fmt.tokens(totals.output))")
            DetailRow(label: "Cache read / write",
                      value: "\(Fmt.tokens(totals.cacheRead)) / \(Fmt.tokens(totals.cacheCreation))")
            DetailRow(label: "Sessions / zprávy",
                      value: "\(Fmt.grouped(stats.totalSessions)) / \(Fmt.grouped(stats.totalMessages))")
            if let top = stats.modelBreakdown(lastDays: 7).first {
                DetailRow(label: "Nejvíc za 7 dní",
                          value: "\(Fmt.modelName(top.model)) · \(Fmt.tokens(top.tokens))")
            }
            Text("Statistiky spočtené \(stats.lastComputed)")
                .font(Fmt.mono(8))
                .foregroundStyle(.tertiary)
                .padding(.top, 1)
        }
    }
}

/// Maskot vykreslený jako pixelová mřížka, aby seděl i uvnitř SwiftUI panelu.
struct MascotBadge: View {
    var cell: CGFloat = 1.2

    var body: some View {
        Canvas { context, _ in
            let color = Color(nsColor: Mascot.color)
            for (r, row) in Mascot.rows.enumerated() {
                for (c, char) in row.enumerated() where char == "#" {
                    let rect = CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: cell * CGFloat(Mascot.cols), height: cell * CGFloat(Mascot.rows.count))
    }
}

private struct TotalCell: View {
    let caption: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(Fmt.mono(13, weight: .semibold))
                .foregroundStyle(tint)
            Text(caption)
                .font(Fmt.mono(9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(label).font(Fmt.mono(9)).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value).font(Fmt.mono(9))
        }
    }
}

struct LimitRow: View {
    let limit: LimitEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Text(limit.title)
                    .font(Fmt.mono(10, weight: limit.isActive ? .semibold : .regular))
                Spacer(minLength: 6)
                Text("\(Int(limit.percent.rounded())) %")
                    .font(Fmt.mono(10, weight: .semibold))
                    .foregroundStyle(Fmt.color(forPercent: limit.percent))
            }
            ProgressBar(percent: limit.percent)
            HStack {
                Spacer()
                Text("reset za \(Fmt.countdown(to: limit.resetsAt))")
                    .font(Fmt.mono(8))
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

/// Denní spotřeba tokenů jako sparkline.
struct TokenChart: View {
    let points: [DailyPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Canvas { context, size in
                let gridColor = Color.primary.opacity(0.10)
                for i in 0...5 {
                    let y = size.height * CGFloat(i) / 5
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

                let mascot = Color(nsColor: Mascot.color)
                context.fill(fill, with: .linearGradient(
                    Gradient(colors: [mascot.opacity(0.30), mascot.opacity(0.02)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
                context.stroke(line, with: .color(mascot), lineWidth: 1.4)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.12)))
            )

            HStack(spacing: 4) {
                Circle().fill(Color(nsColor: Mascot.color)).frame(width: 6, height: 6)
                Text("tokeny za den · \(points.count) dní")
                    .font(Fmt.mono(8))
                    .foregroundStyle(.secondary)
                Spacer()
                if let peak = points.map(\.tokens).max() {
                    Text("max \(Fmt.tokens(peak))")
                        .font(Fmt.mono(8))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
