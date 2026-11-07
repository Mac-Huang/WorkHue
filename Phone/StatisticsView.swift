import SwiftUI
import Charts

struct StatisticsView: View {
    @Environment(TimeStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var range: StatisticsRange = .week

    private var tint: Color { store.settings.tint }
    private var cardColor: Color {
        colorScheme == .dark ? Color(red: 11 / 255, green: 11 / 255, blue: 13 / 255) : Color(uiColor: .secondarySystemBackground)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let data = StatisticsData(range: range, sessions: store.sessions, settings: store.settings, now: context.date)
            ScrollView {
                VStack(spacing: 0) {
                    Picker("Statistics Range", selection: $range) {
                        ForEach(StatisticsRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    .frame(height: 29)
                    .accessibilityIdentifier("statisticsRange")
                    .padding(.bottom, 24)
                    VStack(spacing: 24) {
                        chartCard(data)
                        comparisonCard(data)
                        progressCard(data)
                        outliersCard(data)
                        summaryCard(data)
                    }
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func chartCard(_ data: StatisticsData) -> some View {
        card(title: range.chartTitle) {
            Chart {
                ForEach(data.buckets.filter { $0.seconds > 0 }) { bucket in
                    BarMark(
                        xStart: .value("Start", bucket.start.addingTimeInterval(bucket.duration * 0.12)),
                        xEnd: .value("End", bucket.end.addingTimeInterval(-bucket.duration * 0.12)),
                        y: .value("Hours", bucket.hours)
                    )
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(3)
                    .accessibilityLabel(bucket.start.formatted(date: .abbreviated, time: range == .day ? .shortened : .omitted))
                    .accessibilityValue(hours(bucket.seconds))
                }
                RuleMark(y: .value("Goal", data.chartGoalHours))
                    .foregroundStyle(tint.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .accessibilityLabel("Goal")
                    .accessibilityValue(hours(data.chartGoalHours * 3600))
            }
            .chartXScale(domain: data.chartInterval.start...data.chartInterval.end)
            .chartYScale(domain: .automatic(includesZero: true))
            .chartXAxis {
                AxisMarks(values: data.axisDates) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(data.axisLabel(date)).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let value = value.as(Double.self) {
                            Text("\(value.formatted(.number.precision(.fractionLength(0...1))))h")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 190)
            .accessibilityIdentifier("statisticsChart")
        }
    }

    private func comparisonCard(_ data: StatisticsData) -> some View {
        card(title: range.comparisonTitle) {
            if data.currentSeconds == 0 && data.previousSeconds == 0 {
                VStack(spacing: 9) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 30)).foregroundStyle(.gray.opacity(0.65))
                    Text("No sessions in selected range")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 109)
            } else {
                HStack(spacing: 12) {
                    comparisonTile(range.currentLabel, seconds: data.currentSeconds, highlighted: true)
                    comparisonTile(range.previousLabel, seconds: data.previousSeconds, highlighted: false)
                }
            }
        }
        .accessibilityIdentifier("statisticsComparison")
    }

    private func comparisonTile(_ title: String, seconds: TimeInterval, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13)).foregroundStyle(.secondary)
            Text(hours(seconds)).font(.system(size: 22, weight: .bold))
                .foregroundStyle(highlighted ? tint : Color.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(highlighted ? tint.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10))
    }

    private func progressCard(_ data: StatisticsData) -> some View {
        card(title: store.settings.focus == .observe ? "Patterns" : store.settings.focus == .balance ? "Balance Tracking" : "Progress Tracking") {
            if data.sessionCount == 0 {
                VStack(spacing: 9) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 36)).foregroundStyle(.gray.opacity(0.65))
                        .accessibilityIdentifier("statisticsEmptyTrackingIcon")
                    Text("No sessions to analyze")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 112)
            } else {
                VStack(spacing: 12) {
                    if store.settings.focus == .observe {
                        statisticMetric(symbol: "calendar", color: tint, label: "Most Active Day", value: data.mostActiveDay ?? "—")
                        statisticMetric(symbol: "waveform.path.ecg", color: .purple, label: "Typical Range", value: typicalRange(data))
                    } else if store.settings.focus == .balance {
                        statisticMetric(symbol: "checkmark.shield.fill", color: .green, label: "Days Within Limit", value: "\(data.periodsWithinLimit) / \(data.workedBuckets.count)")
                        statisticMetric(symbol: "hourglass", color: tint, label: "Average Under Limit", value: hours(data.averageUnderLimit))
                    } else {
                        statisticMetric(symbol: "target", color: .green, label: "Goals Hit", value: "\(data.goalsHit) / \(data.workedBuckets.count)")
                        statisticMetric(symbol: "chart.line.uptrend.xyaxis", color: tint, label: "Average Over Goal", value: hours(data.averageOverGoal))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("statisticsProgress")
    }

    private func statisticMetric(symbol: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(color).frame(width: 25)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 18, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func outliersCard(_ data: StatisticsData) -> some View {
        card(title: "Outliers (\(range.periodTitle))") {
            if let best = data.workedBuckets.max(by: { $0.seconds < $1.seconds }),
               let least = data.workedBuckets.min(by: { $0.seconds < $1.seconds }) {
                VStack(spacing: 20) {
                    if store.settings.focus == .observe {
                        outlierRow(best, title: "Longest \(range.bucketTitle)", symbol: "moon.stars.fill", symbolColor: .blue)
                        outlierRow(least, title: "Quietest \(range.bucketTitle)", symbol: "bolt.fill", symbolColor: .yellow)
                    } else if store.settings.focus == .balance {
                        outlierRow(best, title: "Busiest \(range.bucketTitle)", symbol: "exclamationmark.triangle.fill", symbolColor: .orange)
                        outlierRow(least, title: "Best Balanced \(range.bucketTitle)", symbol: "checkmark.circle.fill", symbolColor: .green)
                    } else {
                        outlierRow(best, title: "Most Productive \(range.bucketTitle)", symbol: "star.fill", symbolColor: .green)
                        outlierRow(least, title: "Needs Improvement \(range.bucketTitle)", symbol: "arrow.up.circle.fill", symbolColor: .orange)
                    }
                }
                .padding(.vertical, 3)
            } else {
                VStack(spacing: 9) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 30)).foregroundStyle(.gray.opacity(0.65))
                        .accessibilityIdentifier("statisticsEmptyOutliersIcon")
                    Text("No sessions in selected range")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 105)
            }
        }
        .accessibilityIdentifier("statisticsOutliers")
    }

    private func outlierRow(_ bucket: StatisticsBucket, title: String, symbol: String, symbolColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 23)).foregroundStyle(symbolColor).frame(width: 27)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13)).foregroundStyle(.secondary)
                Text(range == .day ? bucket.start.formatted(date: .omitted, time: .shortened) : bucket.start.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.system(size: 15, weight: .bold))
            }
            Spacer(minLength: 5)
            Text(hours(bucket.seconds))
                .font(.system(size: 19, weight: .bold, design: .monospaced)).foregroundStyle(tint)
        }
    }

    private func summaryCard(_ data: StatisticsData) -> some View {
        card(title: "Summary (\(range.periodTitle))") {
            if data.sessionCount == 0 {
                Text("No sessions to calculate averages")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 66)
            } else {
                VStack(spacing: 23) {
                    HStack {
                        summaryMetric("Average", value: hours(data.averageSeconds))
                        summaryMetric("Total", value: hours(data.totalSeconds))
                    }
                    HStack {
                        summaryMetric("Periods Worked", value: String(data.workedBuckets.count))
                        summaryMetric("Sessions", value: String(data.sessionCount))
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .accessibilityIdentifier("statisticsSummary")
    }

    private func summaryMetric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 20, weight: .bold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 17, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 12))
    }

    private func typicalRange(_ data: StatisticsData) -> String {
        guard let range = data.typicalRange else { return "N/A" }
        let minimum = (max(0, range.lowerBound) / 3600).formatted(.number.precision(.fractionLength(1)))
        let maximum = (max(0, range.upperBound) / 3600).formatted(.number.precision(.fractionLength(1)))
        return minimum == maximum ? "\(minimum)h" : "\(minimum)-\(maximum)h"
    }

    private func hours(_ seconds: TimeInterval) -> String {
        (max(0, seconds) / 3600).formatted(.number.precision(.fractionLength(1))) + "h"
    }
}

