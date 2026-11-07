import Foundation

public struct Workload: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var colorHex: String
    public var isArchived: Bool
    public var modifiedAt: Date

    public init(id: UUID = UUID(), name: String, colorHex: String, isArchived: Bool = false, modifiedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex.replacingOccurrences(of: "#", with: "").uppercased()
        self.isArchived = isArchived
        self.modifiedAt = modifiedAt
    }

    public static let presets: [Workload] = [
        Workload(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Work", colorHex: "43D10D", modifiedAt: .distantPast),
        Workload(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Study", colorHex: "2699F5", modifiedAt: .distantPast),
        Workload(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: "Personal", colorHex: "7955EB", modifiedAt: .distantPast)
    ]
}

public enum WorkloadColorStyle {
    private static let originalPresetHexes: Set<String> = ["43D10D", "2699F5", "7955EB"]

    public static func phoneNeedsDarkInk(_ hex: String) -> Bool {
        guard !originalPresetHexes.contains(normalizedHex(hex)) else { return false }
        let luminance = relativeLuminance(hex)
        return contrastRatio(luminance, 0) > contrastRatio(luminance, 1)
    }

    public static func watchNeedsLightInk(_ hex: String) -> Bool {
        guard !originalPresetHexes.contains(normalizedHex(hex)) else { return false }
        return !phoneNeedsDarkInk(hex)
    }

    public static func blendsIntoSurface(_ hex: String, onDarkSurface: Bool) -> Bool {
        let luminance = relativeLuminance(hex)
        return onDarkSurface ? luminance < 0.08 : luminance > 0.75
    }

    public static func textNeedsPrimaryInk(_ hex: String, onDarkSurface: Bool) -> Bool {
        guard !originalPresetHexes.contains(normalizedHex(hex)) else { return false }
        let surface = relativeLuminance(onDarkSurface ? "2C2C2E" : "F2F2F7")
        return contrastRatio(relativeLuminance(hex), surface) < 4.5
    }

    private static func contrastRatio(_ first: Double, _ second: Double) -> Double {
        (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private static func normalizedHex(_ hex: String) -> String {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        return value.count == 6 && UInt32(value, radix: 16) != nil ? value : "43D10D"
    }

    private static func relativeLuminance(_ hex: String) -> Double {
        let value = UInt32(normalizedHex(hex), radix: 16) ?? 0x43D10D
        func linear(_ component: UInt32) -> Double {
            let channel = Double(component) / 255
            return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear((value >> 16) & 255)
            + 0.7152 * linear((value >> 8) & 255)
            + 0.0722 * linear(value & 255)
    }
}

public struct TimerBoundary: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var start: Date
    public var timestamp: Date

    public init(id: UUID = UUID(), start: Date, timestamp: Date? = nil) {
        self.id = id
        self.start = start
        self.timestamp = timestamp ?? start
    }

    fileprivate static func isEarlier(_ a: TimerBoundary, _ b: TimerBoundary) -> Bool {
        a.timestamp == b.timestamp ? a.id.uuidString < b.id.uuidString : a.timestamp < b.timestamp
    }
}

public struct WorkSession: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var start: Date
    public var end: Date?
    public var workloadID: UUID
    public var workloadName: String
    public var colorHex: String
    public var source: String
    public var modifiedAt: Date
    public var deletedAt: Date?
    public var automaticallyClosed: Bool?
    // An empty list identifies imported/manual completed history. Nil supports older saved records.
    public var timerBoundaries: [TimerBoundary]?

    public init(id: UUID = UUID(), start: Date, end: Date? = nil, workloadID: UUID = Workload.presets[0].id, workloadName: String = "Work", colorHex: String = "43D10D", source: String = "Manual", modifiedAt: Date = Date(), deletedAt: Date? = nil, automaticallyClosed: Bool? = nil, timerBoundaries: [TimerBoundary]? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.workloadID = workloadID
        self.workloadName = workloadName
        self.colorHex = colorHex
        self.source = source
        self.modifiedAt = modifiedAt
        self.deletedAt = deletedAt
        self.automaticallyClosed = automaticallyClosed
        self.timerBoundaries = timerBoundaries ?? [TimerBoundary(id: id, start: start)]
    }

    public var effectiveTimerBoundaries: [TimerBoundary] {
        timerBoundaries ?? [TimerBoundary(id: id, start: start)]
    }
    public var isActive: Bool { end == nil && deletedAt == nil }
    public func duration(at now: Date = Date()) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }
}

public enum TrackingFocus: String, Codable, CaseIterable, Identifiable, Sendable {
    case balance
    case momentum
    case observe

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .balance: return "Find Balance"
        case .momentum: return "Build Momentum"
        case .observe: return "Just Observe"
        }
    }
    public var systemImage: String {
        switch self {
        case .balance: return "sun.horizon.fill"
        case .momentum: return "figure.run"
        case .observe: return "eye.fill"
        }
    }
}

public struct TrackingSettings: Codable, Equatable, Sendable {
    public static let weeklyHoursRange = 0.0...80.0
    public static let dailyHoursRange = 0.0...24.0
    public var weeklyGoalHours: Double
    public var dailyLimitHours: Double
    public var themeHex: String
    public var weekStartsMonday: Bool
    public var focus: TrackingFocus
    public var modifiedAt: Date

    public init(weeklyGoalHours: Double = 40, dailyLimitHours: Double = 8, themeHex: String = "43D10D", weekStartsMonday: Bool = true, focus: TrackingFocus = .balance, modifiedAt: Date = .distantPast) {
        self.weeklyGoalHours = weeklyGoalHours
        self.dailyLimitHours = dailyLimitHours
        self.themeHex = themeHex
        self.weekStartsMonday = weekStartsMonday
        self.focus = focus
        self.modifiedAt = modifiedAt
    }

    private enum CodingKeys: String, CodingKey {
        case weeklyGoalHours, dailyLimitHours, themeHex, weekStartsMonday, focus, modifiedAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        weeklyGoalHours = try values.decodeIfPresent(Double.self, forKey: .weeklyGoalHours) ?? 40
        dailyLimitHours = try values.decodeIfPresent(Double.self, forKey: .dailyLimitHours) ?? 8
        themeHex = try values.decodeIfPresent(String.self, forKey: .themeHex) ?? "43D10D"
        weekStartsMonday = try values.decodeIfPresent(Bool.self, forKey: .weekStartsMonday) ?? true
        focus = try values.decodeIfPresent(TrackingFocus.self, forKey: .focus) ?? .balance
        modifiedAt = try values.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? .distantPast
    }
}

public struct TrackingSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var sessions: [WorkSession]
    public var workloads: [Workload]
    public var settings: TrackingSettings

    public init(sessions: [WorkSession] = [], workloads: [Workload] = Workload.presets, settings: TrackingSettings = TrackingSettings(), schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
        self.sessions = sessions
        self.workloads = workloads
        self.settings = settings
    }

    public static let empty = TrackingSnapshot()
    public var activeSession: WorkSession? {
        sessions.filter(\.isActive).sorted { a, b in
            a.start == b.start ? a.id.uuidString > b.id.uuidString : a.start > b.start
        }.first
    }

    public func merged(with other: TrackingSnapshot) -> TrackingSnapshot {
        var result = self
        var sessionMap = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: Self.preferredSession)
        for session in other.sessions {
            sessionMap[session.id] = sessionMap[session.id].map { Self.preferredSession($0, session) } ?? session
        }
        var workloadMap = Dictionary(workloads.map { ($0.id, $0) }, uniquingKeysWith: Self.preferredWorkload)
        for workload in other.workloads {
            workloadMap[workload.id] = workloadMap[workload.id].map { Self.preferredWorkload($0, workload) } ?? workload
        }
        result.sessions = sessionMap.values.sorted { $0.id.uuidString < $1.id.uuidString }
        result.workloads = workloadMap.values.sorted { $0.id.uuidString < $1.id.uuidString }
        result.settings = Self.preferredSettings(settings, other.settings)
        result.schemaVersion = max(schemaVersion, other.schemaVersion)
        result.reconcileActiveSessions()
        return result
    }

    // Timer starts remain boundaries after stop or deletion. Completed imports carry no boundary.
    public mutating func reconcileActiveSessions() {
        for index in sessions.indices {
            sessions[index].timerBoundaries = Self.canonicalBoundaries(sessions[index].effectiveTimerBoundaries)
            if sessions[index].automaticallyClosed != true { sessions[index].automaticallyClosed = nil }
        }
        let boundaries = Self.canonicalBoundaries(sessions.flatMap(\.effectiveTimerBoundaries))
        for index in sessions.indices where sessions[index].isActive || sessions[index].automaticallyClosed == true {
            guard let own = sessions[index].effectiveTimerBoundaries.max(by: TimerBoundary.isEarlier),
                  let next = boundaries.first(where: { TimerBoundary.isEarlier(own, $0) }) else { continue }
            sessions[index].end = max(sessions[index].start, next.start)
            sessions[index].automaticallyClosed = true
        }
    }

    private static func canonicalBoundaries(_ boundaries: [TimerBoundary]) -> [TimerBoundary] {
        let byID = Dictionary(boundaries.map { ($0.id, $0) }, uniquingKeysWith: { a, b in
            if a.timestamp != b.timestamp { return a.timestamp < b.timestamp ? a : b }
            return a.start <= b.start ? a : b
        })
        return byID.values.sorted(by: TimerBoundary.isEarlier)
    }

    private static func sessionPayload(_ session: WorkSession) -> WorkSession {
        var payload = session
        payload.timerBoundaries = nil
        if payload.automaticallyClosed == true { payload.end = nil }
        payload.automaticallyClosed = nil
        return payload
    }

    private static func preferredSession(_ a: WorkSession, _ b: WorkSession) -> WorkSession {
        let payloadA = sessionPayload(a)
        let payloadB = sessionPayload(b)
        var preferred: WorkSession
        if payloadA.modifiedAt != payloadB.modifiedAt { preferred = payloadA.modifiedAt > payloadB.modifiedAt ? a : b }
        else if (payloadA.deletedAt != nil) != (payloadB.deletedAt != nil) { preferred = payloadA.deletedAt != nil ? a : b }
        else if (payloadA.end != nil) != (payloadB.end != nil) { preferred = payloadA.end != nil ? a : b }
        else if payloadA != payloadB { preferred = stableValue(payloadA) > stableValue(payloadB) ? a : b }
        else if a.automaticallyClosed == true, b.automaticallyClosed == true, let aEnd = a.end, let bEnd = b.end, aEnd != bEnd {
            preferred = aEnd < bEnd ? a : b
        } else if (a.automaticallyClosed == true) != (b.automaticallyClosed == true) {
            preferred = a.automaticallyClosed == true ? a : b
        } else { preferred = a }
        if preferred.automaticallyClosed != true { preferred.automaticallyClosed = nil }
        preferred.timerBoundaries = canonicalBoundaries(a.effectiveTimerBoundaries + b.effectiveTimerBoundaries)
        return preferred
    }

    private static func preferredWorkload(_ a: Workload, _ b: Workload) -> Workload {
        if a.modifiedAt != b.modifiedAt { return a.modifiedAt > b.modifiedAt ? a : b }
        if a.isArchived != b.isArchived { return a.isArchived ? a : b }
        return stableValue(a) > stableValue(b) ? a : b
    }

    private static func preferredSettings(_ a: TrackingSettings, _ b: TrackingSettings) -> TrackingSettings {
        if a.modifiedAt != b.modifiedAt { return a.modifiedAt > b.modifiedAt ? a : b }
        return stableValue(a) > stableValue(b) ? a : b
    }

    private static func stableValue<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? String(decoding: encoder.encode(value), as: UTF8.self)) ?? ""
    }

    /// Build a small mergeable update. Missing records remain in the receiving history.
    public func immediatePatch(maximumBytes: Int = 48_000, recentSessionLimit: Int = 20) -> TrackingSnapshot? {
        let recent = sessions.sorted { a, b in
            a.modifiedAt == b.modifiedAt ? a.id.uuidString < b.id.uuidString : a.modifiedAt > b.modifiedAt
        }
        var chosen: [WorkSession] = activeSession.map { [$0] } ?? []
        let limit = max(1, recentSessionLimit)
        for session in recent.prefix(limit) where !chosen.contains(where: { $0.id == session.id }) {
            chosen.append(session)
        }
        let orderedWorkloads = workloads.sorted { a, b in
            a.modifiedAt == b.modifiedAt ? a.id.uuidString < b.id.uuidString : a.modifiedAt > b.modifiedAt
        }
        var patch = TrackingSnapshot(sessions: chosen, workloads: orderedWorkloads, settings: settings, schemaVersion: schemaVersion)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        func fits(_ value: TrackingSnapshot) -> Bool {
            guard let data = try? encoder.encode(value) else { return false }
            return data.count <= maximumBytes
        }
        // Reserve the active timer and the newest mutation before reducing workload history.
        let reservedCount = min(chosen.count, activeSession == nil ? 1 : 2)
        while !fits(patch), patch.sessions.count > reservedCount { patch.sessions.removeLast() }
        while !fits(patch), !patch.workloads.isEmpty { patch.workloads.removeLast() }
        while !fits(patch), patch.sessions.count > 1 { patch.sessions.removeLast() }
        return fits(patch) ? patch : nil
    }

    public var nextModificationDate: Date {
        let latest = (sessions.map(\.modifiedAt) + workloads.map(\.modifiedAt) + [settings.modifiedAt]).max() ?? .distantPast
        return max(Date(), latest.addingTimeInterval(0.001))
    }
}

public enum TrackingError: LocalizedError, Equatable {
    case invalidDateRange
    case futureDate
    case overlappingSession
    case emptyWorkloadName
    case invalidColor
    case lastWorkload
    case unsupportedSchema

    public var errorDescription: String? {
        switch self {
        case .invalidDateRange: return "The end time must be later than the start time."
        case .futureDate: return "A session cannot start or end in the future."
        case .overlappingSession: return "This session overlaps another session. Choose a different time."
        case .emptyWorkloadName: return "Enter a workload name."
        case .invalidColor: return "Choose a valid color."
        case .lastWorkload: return "Keep at least one workload available."
        case .unsupportedSchema: return "This data requires a newer app version."
        }
    }
}

public enum SessionValidator {
    public static func validate(_ session: WorkSession, existing: [WorkSession], now: Date = Date()) throws {
        guard session.start <= now, session.end.map({ $0 <= now }) ?? true else { throw TrackingError.futureDate }
        if let end = session.end, end <= session.start { throw TrackingError.invalidDateRange }
        let end = session.end ?? .distantFuture
        let overlaps = existing.contains { other in
            guard other.id != session.id, other.deletedAt == nil else { return false }
            return session.start < (other.end ?? .distantFuture) && end > other.start
        }
        if overlaps { throw TrackingError.overlappingSession }
    }

    public static func validate(_ workload: Workload) throws {
        guard !workload.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw TrackingError.emptyWorkloadName }
        let hex = workload.colorHex.replacingOccurrences(of: "#", with: "")
        guard hex.count == 6, UInt32(hex, radix: 16) != nil else { throw TrackingError.invalidColor }
    }
}
