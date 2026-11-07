import Foundation

public enum TimeMath {
    public static func total(sessions: [WorkSession], in interval: DateInterval, now: Date = Date()) -> TimeInterval {
        // Count overlapping history only once. Concurrent offline starts cannot inflate totals.
        let slices = sessions.filter { $0.deletedAt == nil }.compactMap { session -> DateInterval? in
            let start = max(session.start, interval.start)
            let end = min(session.end ?? now, interval.end, now)
            return end > start ? DateInterval(start: start, end: end) : nil
        }.sorted { $0.start < $1.start }
        guard var current = slices.first else { return 0 }
        var total: TimeInterval = 0
        for slice in slices.dropFirst() {
            if slice.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, slice.end))
            } else {
                total += current.duration
                current = slice
            }
        }
        return total + current.duration
    }

    public static func sessions(on date: Date, from sessions: [WorkSession], calendar: Calendar = .current, now: Date = Date()) -> [WorkSession] {
        guard let day = calendar.dateInterval(of: .day, for: date) else { return [] }
        return sessions.filter { session in
            session.deletedAt == nil && session.start < day.end && (session.end ?? now) > day.start
        }.sorted { $0.start < $1.start }
    }

    public static func calendar(for settings: TrackingSettings) -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = settings.weekStartsMonday ? 2 : 1
        calendar.minimumDaysInFirstWeek = settings.weekStartsMonday ? 4 : 1
        return calendar
    }

    public static func interval(_ component: Calendar.Component, containing date: Date = Date(), settings: TrackingSettings = TrackingSettings()) -> DateInterval {
        calendar(for: settings).dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 0)
    }
}

public enum TimeFormat {
    public static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        let hours = minutes / 60
        if hours == 0 { return "\(minutes)m" }
        return "\(hours)h \(minutes % 60)m"
    }

    public static func timer(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
    }

    public static func hours(_ seconds: TimeInterval) -> String {
        if seconds <= 0 { return "0h" }
        if seconds < 3600 { return "\(max(1, Int(seconds / 60)))m" }
        return String(format: "%.1fh", seconds / 3600)
    }
}
