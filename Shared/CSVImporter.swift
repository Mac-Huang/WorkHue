import Foundation

public struct CSVImportedSession: Equatable, Sendable {
    public let rowNumber: Int
    public let id: UUID?
    public let start: Date
    public let end: Date?
    public let workloadName: String
    public let colorHex: String
    public let source: String
}

public enum CSVImportError: LocalizedError, Equatable {
    case invalidEncoding
    case malformedCSV(Int)
    case missingStartColumn
    case noSessions
    case duplicateHeader(String)
    case invalidRow(Int, String)
    case activeSessionExists

    public var errorDescription: String? {
        switch self {
        case .invalidEncoding: return "The CSV file must use UTF-8 or UTF-16 text."
        case .malformedCSV(let row): return "CSV row \(row) contains an invalid quoted field."
        case .missingStartColumn: return "The CSV file needs a Start, Start Time, or Started column."
        case .noSessions: return "The CSV file contains no sessions. Your history remains unchanged."
        case .duplicateHeader(let name): return "The CSV file contains the duplicate column \(name)."
        case .invalidRow(let row, let reason): return "CSV row \(row): \(reason)"
        case .activeSessionExists: return "Punch out before replacing history or importing another active session."
        }
    }
}

public enum CSVImporter {
    public static func parse(data: Data, now: Date = Date()) throws -> [CSVImportedSession] {
        let text: String
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            guard let decoded = String(data: data, encoding: .utf16) else { throw CSVImportError.invalidEncoding }
            text = decoded
        } else {
            guard let decoded = String(data: data, encoding: .utf8) else { throw CSVImportError.invalidEncoding }
            text = decoded
        }
        let records = try parseFields(text)
        guard let header = records.first, header.contains(where: { !$0.isEmpty }) else { throw CSVImportError.noSessions }
        var columns: [String: Int] = [:]
        for (index, value) in header.enumerated() {
            let key = normalized(value)
            guard !key.isEmpty else { continue }
            guard columns[key] == nil else { throw CSVImportError.duplicateHeader(value) }
            columns[key] = index
        }
        let startAliases = ["start", "starttime", "started", "startdate", "starttimestamp", "startdatetime", "startutc", "clockin", "punchin"]
        guard startAliases.contains(where: { columns[$0] != nil }) else { throw CSVImportError.missingStartColumn }
        func field(_ row: [String], _ aliases: [String]) -> String {
            for alias in aliases {
                if let index = columns[alias] {
                    let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty { return value }
                }
            }
            return ""
        }
        func timestamp(_ row: [String], side: String, fallbackDay: String) -> Date? {
            let completeAliases = side == "start" ?
                ["start", "startutc", "starttimestamp", "startdatetime", "clockin", "punchin"] :
                ["end", "endutc", "endtimestamp", "enddatetime", "clockout", "punchout"]
            let complete = field(row, completeAliases)
            if !complete.isEmpty { return parseDate(complete, day: fallbackDay) }
            let dateKey = side + "date"
            let timeKey = side + "time"
            let dateValue = field(row, [dateKey])
            let clockValue = field(row, [timeKey, side == "start" ? "started" : "ended"])
            if columns[dateKey] != nil, columns[timeKey] != nil {
                guard !dateValue.isEmpty, !clockValue.isEmpty else { return nil }
                return parseDate(clockValue, day: dateValue)
            }
            if !clockValue.isEmpty { return parseDate(clockValue, day: dateValue.isEmpty ? fallbackDay : dateValue) }
            return parseDate(dateValue, day: fallbackDay)
        }
        let isOwnExport = columns["sessionid"] != nil &&
            (columns["status"] != nil || (columns["workload"] != nil && columns["color"] != nil))
        var sessions: [CSVImportedSession] = []
        for (offset, row) in records.dropFirst().enumerated() {
            let rowNumber = offset + 2
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
            guard row.count == header.count else { throw CSVImportError.invalidRow(rowNumber, "The number of fields does not match the header.") }
            let dateField = field(row, ["date", "day"])
            guard let start = timestamp(row, side: "start", fallbackDay: dateField) else {
                throw CSVImportError.invalidRow(rowNumber, "The start timestamp is invalid.")
            }
            let endField = field(row, ["end", "endtime", "ended", "enddate", "endtimestamp", "enddatetime", "endutc", "clockout", "punchout"])
            let end: Date?
            if endField.isEmpty {
                let status = normalized(field(row, ["status"]))
                guard status.isEmpty || ["active", "inprogress", "running"].contains(status) else {
                    throw CSVImportError.invalidRow(rowNumber, "A completed session needs an end timestamp.")
                }
                end = nil
            } else {
                guard let parsed = timestamp(row, side: "end", fallbackDay: dateField) else { throw CSVImportError.invalidRow(rowNumber, "The end timestamp is invalid.") }
                end = parsed
            }
            let idField = field(row, ["sessionid", "id", "uuid"])
            let id: UUID?
            if idField.isEmpty { id = nil }
            else {
                guard let parsed = UUID(uuidString: idField) else { throw CSVImportError.invalidRow(rowNumber, "The session ID is invalid.") }
                id = parsed
            }
            var name = field(row, ["workload", "workloadname", "category", "project"])
            var source = field(row, ["source", "device"])
            if isOwnExport {
                name = restoredCell(name)
                source = restoredCell(source)
            }
            if name.isEmpty { name = "Work" }
            if source.isEmpty { source = "Import" }
            let rawColor = field(row, ["color", "colour", "colorhex", "colourhex", "workloadcolor"])
            let color = rawColor.isEmpty ? "43D10D" : rawColor.replacingOccurrences(of: "#", with: "").uppercased()
            let workload = Workload(name: name, colorHex: color)
            do {
                try SessionValidator.validate(workload)
                try SessionValidator.validate(WorkSession(start: start, end: end), existing: [], now: now)
            } catch { throw CSVImportError.invalidRow(rowNumber, error.localizedDescription) }
            sessions.append(CSVImportedSession(rowNumber: rowNumber, id: id, start: start, end: end, workloadName: name, colorHex: color, source: source))
        }
        guard !sessions.isEmpty else { throw CSVImportError.noSessions }
        return sessions
    }

    /// Apply a validated batch to a copy. A failed batch cannot change the caller's snapshot.
    @discardableResult
    public static func apply(_ rows: [CSVImportedSession], to snapshot: inout TrackingSnapshot, replaceExisting: Bool, now: Date = Date()) throws -> Int {
        guard !rows.isEmpty else { throw CSVImportError.noSessions }
        if replaceExisting, snapshot.activeSession != nil { throw CSVImportError.activeSessionExists }
        var candidate = snapshot
        let stamp = snapshot.nextModificationDate
        let existingIDs = Set(snapshot.sessions.map(\.id))
        var signatures = Set(snapshot.sessions.map(SessionSignature.init))
        var seenIDs: [UUID: SessionSignature] = [:]
        var seenUnidentified: Set<SessionSignature> = []
        var workloadIDs: [WorkloadKey: UUID] = [:]
        for workload in snapshot.workloads { workloadIDs[WorkloadKey(name: workload.name, color: workload.colorHex)] = workload.id }
        for session in snapshot.sessions {
            let key = WorkloadKey(name: session.workloadName, color: session.colorHex)
            if workloadIDs[key] == nil { workloadIDs[key] = session.workloadID }
        }
        if replaceExisting {
            for index in candidate.sessions.indices where candidate.sessions[index].deletedAt == nil {
                candidate.sessions[index].deletedAt = stamp
                candidate.sessions[index].modifiedAt = stamp
            }
        }
        var count = 0
        for row in rows {
            let signature = SessionSignature(row)
            do {
                try SessionValidator.validate(WorkSession(start: row.start, end: row.end), existing: [], now: now)
                try SessionValidator.validate(Workload(name: row.workloadName, colorHex: row.colorHex))
            } catch { throw CSVImportError.invalidRow(row.rowNumber, error.localizedDescription) }
            if let id = row.id {
                if let seen = seenIDs[id] {
                    guard seen == signature else { throw CSVImportError.invalidRow(row.rowNumber, "This session ID occurs with conflicting values.") }
                    continue
                }
                seenIDs[id] = signature
                if !replaceExisting, existingIDs.contains(id) { continue }
            } else {
                if seenUnidentified.contains(signature) || (!replaceExisting && signatures.contains(signature)) { continue }
                seenUnidentified.insert(signature)
            }
            let key = WorkloadKey(name: row.workloadName, color: row.colorHex)
            let workloadID: UUID
            if let found = workloadIDs[key] { workloadID = found }
            else {
                let workload = Workload(name: row.workloadName, colorHex: row.colorHex, modifiedAt: stamp)
                workloadID = workload.id
                candidate.workloads.append(workload)
                workloadIDs[key] = workload.id
            }
            let id = row.id ?? UUID()
            var boundaries = snapshot.sessions.first(where: { $0.id == id })?.effectiveTimerBoundaries ?? []
            if row.end == nil { boundaries.append(TimerBoundary(start: row.start, timestamp: stamp)) }
            let imported = WorkSession(id: id, start: row.start, end: row.end, workloadID: workloadID, workloadName: row.workloadName, colorHex: row.colorHex, source: row.source, modifiedAt: stamp, timerBoundaries: boundaries)
            if let index = candidate.sessions.firstIndex(where: { $0.id == imported.id }) { candidate.sessions[index] = imported }
            else { candidate.sessions.append(imported) }
            signatures.insert(signature)
            count += 1
        }
        guard candidate.sessions.filter(\.isActive).count <= 1 else { throw CSVImportError.activeSessionExists }
        candidate.reconcileActiveSessions()
        snapshot = candidate
        return count
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func restoredCell(_ value: String) -> String {
        if value.first == "'", let second = value.dropFirst().first, "=+-@\t\r".contains(second) { return String(value.dropFirst()) }
        return value
    }

    private static func parseDate(_ value: String, day: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let dot = value.lastIndex(of: "."), value.contains("T") {
            let tail = value[value.index(after: dot)...]
            let digits = tail.prefix(while: { $0.isNumber })
            let zone = tail.dropFirst(digits.count)
            if !digits.isEmpty, let fraction = Double("0." + digits),
               let whole = iso.date(from: String(value[..<dot]) + zone) {
                return whole.addingTimeInterval(fraction)
            }
        }
        if let date = iso.date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        if !day.isEmpty, value.contains(":"), !value.contains("-"), !value.contains("/"), !value.contains("T") {
            guard let date = parseDate(day, day: "") else { return nil }
            for format in ["H:mm:ss", "H:mm", "h:mm:ss a", "h:mm a"] {
                formatter.dateFormat = format
                if let time = formatter.date(from: value) {
                    let components = Calendar.current.dateComponents([.hour, .minute, .second], from: time)
                    return Calendar.current.date(bySettingHour: components.hour ?? 0, minute: components.minute ?? 0, second: components.second ?? 0, of: date)
                }
            }
            return nil
        }
        for format in ["yyyy-MM-dd HH:mm:ss XXXXX", "yyyy-MM-dd HH:mm:ss Z", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "M/d/yyyy h:mm:ss a", "M/d/yyyy h:mm a", "M/d/yyyy H:mm:ss", "M/d/yyyy H:mm", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private static func parseFields(_ input: String) throws -> [[String]] {
        let text = input.first == "\u{FEFF}" ? String(input.dropFirst()) : input
        let scalars = Array(text.unicodeScalars)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var afterQuote = false
        var index = 0
        func finishField() { row.append(field); field = ""; afterQuote = false }
        func finishRow() { finishField(); rows.append(row); row = [] }
        while index < scalars.count {
            let scalar = scalars[index]
            if quoted {
                if scalar == "\"" {
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" { field.append("\""); index += 1 }
                    else { quoted = false; afterQuote = true }
                } else { field.unicodeScalars.append(scalar) }
            } else if scalar == "," { finishField() }
            else if scalar == "\n" || scalar == "\r" {
                finishRow()
                if scalar == "\r", index + 1 < scalars.count, scalars[index + 1] == "\n" { index += 1 }
            } else if scalar == "\"", field.isEmpty, !afterQuote { quoted = true }
            else {
                if afterQuote || scalar == "\"" { throw CSVImportError.malformedCSV(rows.count + 1) }
                field.unicodeScalars.append(scalar)
            }
            index += 1
        }
        if quoted { throw CSVImportError.malformedCSV(rows.count + 1) }
        if !field.isEmpty || !row.isEmpty || afterQuote { finishRow() }
        return rows
    }
}

private struct WorkloadKey: Hashable {
    let name: String
    let color: String
    init(name: String, color: String) {
        self.name = name.lowercased()
        self.color = color.uppercased()
    }
}

private struct SessionSignature: Hashable {
    let start: Date
    let end: Date?
    let name: String
    let color: String
    let source: String
    init(_ session: WorkSession) {
        start = session.start; end = session.end; name = session.workloadName; color = session.colorHex; source = session.source
    }
    init(_ row: CSVImportedSession) {
        start = row.start; end = row.end; name = row.workloadName; color = row.colorHex; source = row.source
    }
}
