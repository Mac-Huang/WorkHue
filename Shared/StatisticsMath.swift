import Foundation

enum StatisticsRange: String, CaseIterable, Identifiable {
    case day = "D", week = "W", month = "M", sixMonths = "6M", year = "Y"
    var id: String { rawValue }
    var chartTitle: String {
        switch self {
        case .day: "Last 24 Hours"
        case .week: "Last 7 Days"
        case .month: "Last 30 Days"
        case .sixMonths: "Last 6 Months"
        case .year: "Last 12 Months"
        }
    }
    var periodTitle: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .sixMonths: "6 Months"
        case .year: "Year"
        }
    }
    var comparisonTitle: String { self == .sixMonths ? "6-Month Comparison" : "\(periodTitle) Comparison" }
    var currentLabel: String {
        switch self {
        case .day: "Today"
        case .week: "This Week"
        case .month: "This Month"
        case .sixMonths: "Last 6 Months"
        case .year: "This Year"
        }
    }
    var previousLabel: String {
        switch self {
        case .day: "Yesterday"
        case .week: "Last Week"
        case .month: "Last Month"
        case .sixMonths: "Previous 6 Months"
        case .year: "Last Year"
        }
    }
    var bucketTitle: String {
        switch self {
        case .day: "Hour"
        case .week, .month: "Day"
        case .sixMonths: "Week"
        case .year: "Month"
        }
    }
}

struct StatisticsBucket: Identifiable {
    let start: Date
    let end: Date
    let seconds: TimeInterval
    var id: Date { start }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    var hours: Double { seconds / 3600 }
}

struct StatisticsData {
    let range: StatisticsRange
    let chartInterval: DateInterval
    let rawInterval: DateInterval
    let buckets: [StatisticsBucket]
    let currentSeconds: TimeInterval
    let previousSeconds: TimeInterval
    let chartGoalHours: Double
    let dailyGoalSeconds: TimeInterval
    let sessionCount: Int
    let totalSeconds: TimeInterval
    let axisDates: [Date]
    let mostActiveWeekday: Int?
    private let calendar: Calendar

    var workedBuckets: [StatisticsBucket] { buckets.filter { $0.seconds > 0 } }
    var chartTotalSeconds: TimeInterval { buckets.reduce(0) { $0 + $1.seconds } }
    var mostActiveDay: String? { mostActiveWeekday.map { calendar.shortWeekdaySymbols[$0 - 1] } }
    var typicalRange: ClosedRange<TimeInterval>? {
        let values = workedBuckets.map(\.seconds).sorted()
        guard !values.isEmpty else { return nil }
        return values[values.count / 4]...values[(3 * values.count) / 4]
    }
    var averageSeconds: TimeInterval { workedBuckets.isEmpty ? 0 : chartTotalSeconds / Double(workedBuckets.count) }
    var goalsHit: Int { workedBuckets.filter { $0.seconds >= dailyGoalSeconds }.count }
    var periodsWithinLimit: Int { workedBuckets.filter { $0.seconds <= dailyGoalSeconds }.count }
    var averageUnderLimit: TimeInterval {
        let within = workedBuckets.filter { $0.seconds <= dailyGoalSeconds }
        return within.isEmpty ? 0 : within.reduce(0) { $0 + max(0, dailyGoalSeconds - $1.seconds) } / Double(within.count)
    }
    var averageOverGoal: TimeInterval {
        let hit = workedBuckets.filter { $0.seconds >= dailyGoalSeconds }
        return hit.isEmpty ? 0 : hit.reduce(0) { $0 + max(0, $1.seconds - dailyGoalSeconds) } / Double(hit.count)
    }

    init(range: StatisticsRange, sessions: [WorkSession], settings: TrackingSettings, now: Date, calendar providedCalendar: Calendar? = nil) {
        self.range = range
        let calendar = providedCalendar ?? TimeMath.calendar(for: settings)
        self.calendar = calendar
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let currentMonth = calendar.dateInterval(of: .month, for: now)!
        let rollingStart: Date
        switch range {
        case .day: rollingStart = calendar.date(byAdding: .hour, value: -24, to: now)!
        case .week: rollingStart = calendar.date(byAdding: .day, value: -7, to: now)!
        case .month: rollingStart = calendar.date(byAdding: .day, value: -30, to: now)!
        case .sixMonths: rollingStart = calendar.date(byAdding: .month, value: -6, to: now)!
        case .year: rollingStart = calendar.date(byAdding: .month, value: -12, to: now)!
        }
        let rawInterval = DateInterval(start: rollingStart, end: now)
        self.rawInterval = rawInterval
        totalSeconds = TimeMath.total(sessions: sessions, in: rawInterval, now: now)
        let interval: DateInterval
        let bucketComponent: Calendar.Component
        switch range {
        case .day:
            let currentHour = calendar.dateInterval(of: .hour, for: now)!
            interval = DateInterval(start: calendar.date(byAdding: .hour, value: -23, to: currentHour.start)!, end: currentHour.end)
            bucketComponent = .hour
        case .week:
            interval = DateInterval(start: calendar.date(byAdding: .day, value: -6, to: today)!, end: tomorrow)
            bucketComponent = .day
        case .month:
            interval = DateInterval(start: calendar.date(byAdding: .day, value: -29, to: today)!, end: tomorrow)
            bucketComponent = .day
        case .sixMonths:
            interval = DateInterval(start: calendar.date(byAdding: .month, value: -6, to: today)!, end: tomorrow)
            bucketComponent = .weekOfYear
        case .year:
            interval = DateInterval(start: calendar.date(byAdding: .month, value: -11, to: currentMonth.start)!, end: currentMonth.end)
            bucketComponent = .month
        }
        chartInterval = interval
        var built: [StatisticsBucket] = []
        var cursor = interval.start
        while cursor < interval.end {
            let containing = calendar.dateInterval(of: bucketComponent, for: cursor)!
            let end = min(containing.end, interval.end)
            built.append(StatisticsBucket(start: cursor, end: end, seconds: TimeMath.total(sessions: sessions, in: DateInterval(start: cursor, end: end), now: now)))
            cursor = end
        }
        buckets = built
        sessionCount = sessions.filter { $0.deletedAt == nil && $0.start < rawInterval.end && ($0.end ?? now) > rawInterval.start }.count
        var weekdayTotals: [Int: TimeInterval] = [:]
        var dayCursor = calendar.startOfDay(for: rawInterval.start)
        while dayCursor < rawInterval.end {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayCursor)!
            let dayRange = DateInterval(start: max(dayCursor, rawInterval.start), end: min(nextDay, rawInterval.end))
            let seconds = TimeMath.total(sessions: sessions, in: dayRange, now: now)
            if seconds > 0 { weekdayTotals[calendar.component(.weekday, from: dayCursor), default: 0] += seconds }
            dayCursor = nextDay
        }
        mostActiveWeekday = weekdayTotals.keys.sorted().max { weekdayTotals[$0, default: 0] < weekdayTotals[$1, default: 0] }
        dailyGoalSeconds = settings.dailyLimitHours * 3600
        chartGoalHours = range == .year ? settings.weeklyGoalHours * 4 : range == .sixMonths ? settings.weeklyGoalHours : settings.dailyLimitHours

        let current: DateInterval
        let previous: DateInterval
        switch range {
        case .day, .week, .month, .year:
            let component: Calendar.Component = range == .day ? .day : range == .week ? .weekOfYear : range == .month ? .month : .year
            current = calendar.dateInterval(of: component, for: now)!
            let previousDate = calendar.date(byAdding: component, value: -1, to: current.start)!
            previous = calendar.dateInterval(of: component, for: previousDate)!
        case .sixMonths:
            current = interval
            previous = DateInterval(start: calendar.date(byAdding: .month, value: -6, to: interval.start)!, end: interval.start)
        }
        currentSeconds = TimeMath.total(sessions: sessions, in: current, now: now)
        previousSeconds = TimeMath.total(sessions: sessions, in: previous, now: now)

        switch range {
        case .day:
            axisDates = [0, 6, 12, 18].compactMap { calendar.date(byAdding: .hour, value: $0, to: interval.start) }
        case .week:
            axisDates = [0, 2, 4, 6].compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        case .month:
            var tick = calendar.dateInterval(of: .weekOfYear, for: interval.start)!.start
            if tick < interval.start { tick = calendar.date(byAdding: .weekOfYear, value: 1, to: tick)! }
            var dates: [Date] = []
            while tick < interval.end {
                dates.append(tick)
                tick = calendar.date(byAdding: .weekOfYear, value: 1, to: tick)!
            }
            axisDates = dates
        case .sixMonths:
            var tick = calendar.dateInterval(of: .month, for: interval.start)!.start
            if tick < interval.start { tick = calendar.date(byAdding: .month, value: 1, to: tick)! }
            if calendar.component(.month, from: tick).isMultiple(of: 2) { tick = calendar.date(byAdding: .month, value: 1, to: tick)! }
            var dates: [Date] = []
            while tick < interval.end {
                dates.append(tick)
                tick = calendar.date(byAdding: .month, value: 2, to: tick)!
            }
            axisDates = dates
        case .year:
            axisDates = [0, 3, 6, 9].compactMap { calendar.date(byAdding: .month, value: $0, to: interval.start) }
        }
    }

    func axisLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = calendar.locale ?? .current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        switch range {
        case .day: formatter.dateFormat = "ha"
        case .week: formatter.dateFormat = "MMM d"
        case .month: formatter.dateFormat = "MMM d"
        case .sixMonths: formatter.dateFormat = "MMM d"
        case .year: formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }
}
