import SwiftUI

struct OverviewView: View {
    @Environment(TimeStore.self) private var store
    @State private var monthOffset = 0
    @State private var selectedDay: SelectedDay?
    @State private var showWeek = false
    private var calendar: Calendar { var c = Calendar.current; c.firstWeekday = store.settings.weekStartsMonday ? 2 : 1; return c }
    private var currentMonth: Date { calendar.dateInterval(of: .month, for: Date())!.start }
    private var displayedMonth: Date { calendar.date(byAdding: .month, value: monthOffset, to: currentMonth)! }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                VStack(spacing: 0) {

                    HStack(spacing: 10) {
                        Button { selectedDay = SelectedDay(date: context.date) } label: {
                            OverviewGoalCard(title: "Today", seconds: todayTotal(context.date), goalHours: store.settings.dailyLimitHours, focus: store.settings.focus, tint: store.settings.tint)
                        }
                        .accessibilityIdentifier("dayGoalCard")
                        Button { showWeek = true } label: {
                            OverviewGoalCard(title: "Week", seconds: weekTotal(context.date), goalHours: store.settings.weeklyGoalHours, focus: store.settings.focus, tint: store.settings.tint)
                        }
                        .accessibilityIdentifier("weekGoalCard")
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 22)
                    monthHeader
                    monthGrid(now: context.date)
                        .id(monthOffset)
                        .transition(.opacity.combined(with: .offset(x: monthOffset > 0 ? 12 : -12)))
                        .gesture(DragGesture(minimumDistance: 35).onEnded { value in
                            if value.translation.width < -35 { changeMonth(1) }
                            if value.translation.width > 35 { changeMonth(-1) }
                        })
                    legend.padding(.top, 28).padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(Color(uiColor: .systemBackground))
        }
        .sheet(item: $selectedDay) { day in DayDetailView(initialDate: day.date) }
        .sheet(isPresented: $showWeek) { WeekDetailView() }
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").font(.system(size: 21, weight: .semibold)).frame(width: 44, height: 44) }
                .accessibilityLabel("Previous month")
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 20, weight: .semibold))
                .accessibilityIdentifier("monthTitle")
            Spacer()
            Button { changeMonth(1) } label: { Image(systemName: "chevron.right").font(.system(size: 21, weight: .semibold)).frame(width: 44, height: 44) }
                .disabled(monthOffset >= 0)
                .accessibilityLabel("Next month")
        }
        .padding(.bottom, 0)
    }

    private func monthGrid(now: Date) -> some View {
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = calendar.range(of: .day, in: .month, for: displayedMonth)!.count
        let symbols = store.settings.weekStartsMonday ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(symbols, id: \.self) { symbol in
                    Text(symbol).font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<(leading + days), id: \.self) { index in
                    let day = index - leading + 1
                    if day > 0 {
                        let date = calendar.date(byAdding: .day, value: day - 1, to: displayedMonth)!
                        let seconds = TimeMath.total(sessions: store.sessions, in: calendar.dateInterval(of: .day, for: date)!, now: now)
                        DayCell(day: day, seconds: seconds, isToday: calendar.isDateInToday(date), isFuture: date > calendar.startOfDay(for: now), isCurrentWeek: calendar.dateInterval(of: .weekOfYear, for: now)!.contains(date), focus: store.settings.focus, overLimit: store.settings.dailyLimitHours > 0 && seconds >= store.settings.dailyLimitHours * 3600, tint: store.settings.tint) {
                            selectedDay = SelectedDay(date: date)
                        }
                        .accessibilityIdentifier("day-\(day)")
                        .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(TimeFormat.duration(seconds))")
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }

    private var legend: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                ForEach(0..<8) { value in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(value == 0 ? Color.cardBackground : store.settings.tint.opacity(Double(value) / 8 + 0.1))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.primary.opacity(0.04), lineWidth: 1))
                        .frame(width: 18, height: 18)
                }
            }
            HStack(spacing: 13) {
                ForEach(["0h", "<2h", "2–4h", "4–6h", "6–8h", "8h+"], id: \.self) { Text($0).font(.system(size: 10)).foregroundStyle(.tertiary) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calendar intensity: darker colors represent more hours. Borders mark days that reach your goal or limit.")
    }

    private func todayTotal(_ now: Date) -> TimeInterval { TimeMath.total(sessions: store.sessions, in: calendar.dateInterval(of: .day, for: now)!, now: now) }
    private func weekTotal(_ now: Date) -> TimeInterval { TimeMath.total(sessions: store.sessions, in: calendar.dateInterval(of: .weekOfYear, for: now)!, now: now) }
    private func changeMonth(_ direction: Int) { withAnimation(.easeInOut(duration: 0.2)) { monthOffset = min(0, monthOffset + direction) } }
}

private struct SelectedDay: Identifiable { let date: Date; var id: Date { date } }

struct GoalCard: View {
    let title: String
    let seconds: TimeInterval
    let goalHours: Double
    let footnote: String
    let tint: Color
    private var remaining: TimeInterval { max(0, goalHours * 3600 - seconds) }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text("\(TimeFormat.duration(seconds)) / \(TimeFormat.duration(goalHours * 3600))")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
            GeometryReader { geometry in
                Capsule().fill(Color.primary.opacity(0.1))
                    .overlay(alignment: .leading) {
                        Capsule().fill(seconds > goalHours * 3600 ? Color.red : tint)
                            .frame(width: geometry.size.width * min(1, seconds / max(1, goalHours * 3600)))
                    }
            }.frame(height: 4)
            Text(seconds > goalHours * 3600 ? "\(TimeFormat.duration(seconds - goalHours * 3600)) over target" : "\(TimeFormat.duration(remaining)) \(footnote)")
                .font(.system(size: 11)).foregroundStyle(.tertiary).lineLimit(1).minimumScaleFactor(0.75)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.overviewCard, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct DayCell: View {
    let day: Int
    let seconds: TimeInterval
    let isToday: Bool
    let isFuture: Bool
    let isCurrentWeek: Bool
    let focus: TrackingFocus
    let overLimit: Bool
    let tint: Color
    let action: () -> Void
    private var intensity: Double {
        switch seconds / 3600 {
        case ..<2: return 0.3
        case ..<4: return 0.5
        case ..<6: return 0.7
        case ..<8: return 0.9
        default: return 1
        }
    }
    private var highlighted: Bool { overLimit && focus != .observe }
    private var borderColor: Color {
        if highlighted { return focus == .balance ? .red : .green }
        if isToday { return .primary }
        return isCurrentWeek && !isFuture ? tint.opacity(0.35) : Color.primary.opacity(0.075)
    }
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 7)
                .fill(seconds > 0 ? tint.opacity(intensity) : Color.cardBackground)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    VStack(spacing: 3) {
                        Text(String(day)).font(.system(size: 15, weight: .medium))
                        if seconds > 0 { Text(TimeFormat.hours(seconds)).font(.system(size: 9)).opacity(0.75).lineLimit(1).minimumScaleFactor(0.7) }
                    }
                    .foregroundStyle(seconds >= 4 * 3600 ? Color.white : Color.primary)
                }
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(borderColor, lineWidth: highlighted || isToday ? 2 : 1))
        }
        .buttonStyle(.plain)
        .opacity(isFuture ? 0.18 : 1)
        .disabled(isFuture)
    }
}

private struct OverviewGoalCard: View {
    let title: String
    let seconds: TimeInterval
    let goalHours: Double
    let focus: TrackingFocus
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 15, weight: .bold))
            ProgressView(value: min(1, seconds / max(1, goalHours * 3600)))
                .tint(focus == .balance && seconds > goalHours * 3600 ? .red : tint)
                .frame(height: 4)
            Text("\(TimeFormat.duration(seconds)) / \(TimeFormat.duration(goalHours * 3600))")
                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)

        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.overviewCard, in: RoundedRectangle(cornerRadius: 13))
    }
}
