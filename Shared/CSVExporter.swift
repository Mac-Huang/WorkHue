import Foundation

public enum CSVExporter {
    public static func text(sessions: [WorkSession], now: Date = Date()) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.timeZone = .current
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let clockFormatter = DateFormatter()
        clockFormatter.locale = Locale(identifier: "en_US_POSIX")
        clockFormatter.calendar = Calendar(identifier: .gregorian)
        clockFormatter.timeZone = .current
        clockFormatter.dateFormat = "HH:mm:ss"
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        var rows = ["Start Date,Start Time,End Date,End Time,Duration (minutes),Duration (hours),Source,Workload,Color,Session ID,Start,End"]
        for session in sessions.filter({ $0.deletedAt == nil }).sorted(by: { $0.start < $1.start }) {
            let duration = session.duration(at: now)
            rows.append([
                dayFormatter.string(from: session.start),
                clockFormatter.string(from: session.start),
                session.end.map(dayFormatter.string) ?? "",
                session.end.map(clockFormatter.string) ?? "",
                String(Int(duration / 60)),
                String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), duration / 3600),
                safeCell(session.source),
                safeCell(session.workloadName),
                session.colorHex,
                session.id.uuidString,
                preciseTimestamp(session.start, formatter: iso),
                session.end.map { preciseTimestamp($0, formatter: iso) } ?? ""
            ].map(escape).joined(separator: ","))
        }
        return rows.joined(separator: "\r\n") + "\r\n"
    }

    public static func write(sessions: [WorkSession], directory: URL = FileManager.default.temporaryDirectory, now: Date = Date()) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        let url = directory.appendingPathComponent("punchin-export-\(formatter.string(from: now)).csv")
        try Data(text(sessions: sessions, now: now).utf8).write(to: url, options: .atomic)
        return url
    }

    private static func preciseTimestamp(_ date: Date, formatter: ISO8601DateFormatter) -> String {
        let reference = date.timeIntervalSinceReferenceDate
        var whole = floor(reference)
        var nanoseconds = Int(((reference - whole) * 1_000_000_000).rounded())
        if nanoseconds == 1_000_000_000 { whole += 1; nanoseconds = 0 }
        let base = formatter.string(from: Date(timeIntervalSinceReferenceDate: whole))
        return String(base.dropLast()) + String(format: ".%09dZ", nanoseconds)
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    // Prevent spreadsheet programs from interpreting user-entered names as formulas.
    private static func safeCell(_ value: String) -> String {
        if let first = value.first, "=+-@\t\r".contains(first) { return "'" + value }
        return value
    }
}
