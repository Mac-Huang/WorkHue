import Foundation
import XCTest
@testable import PunchinoCore

final class CSVImportTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private var now: Date { date("2026-11-07T12:00:00Z") }

    func testOwnExportRoundTripPreservesQuotedNewlineColorSourceAndID() throws {
        let session = WorkSession(start: date("2026-11-01T09:00:00Z"), end: date("2026-11-01T10:00:00Z"), workloadName: "Research, \"notes\"\nDraft", colorHex: "ABCDEF", source: "Siri")
        let csv = "\u{FEFF}" + CSVExporter.text(sessions: [session], now: now)
        let rows = try CSVImporter.parse(data: Data(csv.utf8), now: now)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].id, session.id)
        XCTAssertEqual(rows[0].workloadName, session.workloadName)
        XCTAssertEqual(rows[0].colorHex, "ABCDEF")
        XCTAssertEqual(rows[0].source, "Siri")
        var snapshot = TrackingSnapshot.empty
        XCTAssertEqual(try CSVImporter.apply(rows, to: &snapshot, replaceExisting: false, now: now), 1)
        XCTAssertEqual(snapshot.sessions[0].start, session.start)
        XCTAssertEqual(snapshot.sessions[0].end, session.end)
        XCTAssertEqual(snapshot.sessions[0].workloadName, session.workloadName)
        XCTAssertTrue(snapshot.workloads.contains(where: { $0.name == session.workloadName && $0.colorHex == session.colorHex }))
    }

    func testOriginalSevenColumnsKeepSeparateOvernightDates() throws {
        let csv = "Start Date,Start Time,End Date,End Time,Duration (minutes),Duration (hours),Source\r\n2026-01-14,23:50:00,2026-01-15,00:34:35,44,0.74,watch\r\n"
        let rows = try CSVImporter.parse(data: Data(csv.utf8), now: now)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(Calendar.current.component(.day, from: rows[0].start), 14)
        XCTAssertEqual(Calendar.current.component(.day, from: rows[0].end!), 15)
        XCTAssertEqual(rows[0].end!.timeIntervalSince(rows[0].start), 2675)
        XCTAssertEqual(rows[0].source, "watch")
    }

    func testOriginalEarlyMorningClockFieldsCannotBecomeDates() throws {
        let csv = "Start Date,Start Time,End Date,End Time,Duration (minutes),Duration (hours),Source\n2026-01-14,01:02:03,2026-01-14,02:03:04,61,1.02,watch\n"
        let row = try XCTUnwrap(CSVImporter.parse(data: Data(csv.utf8), now: now).first)
        XCTAssertEqual(Calendar.current.component(.year, from: row.start), 2026)
        XCTAssertEqual(Calendar.current.component(.hour, from: row.start), 1)
        XCTAssertEqual(Calendar.current.component(.minute, from: row.start), 2)
        XCTAssertEqual(Calendar.current.component(.second, from: row.start), 3)
        XCTAssertEqual(row.end!.timeIntervalSince(row.start), 3661)
    }

    func testExportUsesOriginalPrefixDurationsRawSourceAndFilename() throws {
        let start = date("2026-01-14T09:00:00Z")
        let session = WorkSession(start: start, end: start.addingTimeInterval(2675), source: "watch")
        let csv = CSVExporter.text(sessions: [session], now: now)
        let lines = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(Array(lines[0].components(separatedBy: ",").prefix(7)), ["Start Date", "Start Time", "End Date", "End Time", "Duration (minutes)", "Duration (hours)", "Source"])
        let values = lines[1].components(separatedBy: ",")
        XCTAssertEqual(values[4], "44")
        XCTAssertEqual(values[5], "0.74")
        XCTAssertEqual(values[6], "watch")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try CSVExporter.write(sessions: [session], directory: directory, now: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        XCTAssertEqual(url.lastPathComponent, "punchin-export-\(formatter.string(from: now)).csv")
    }

    func testExportKeepsFractionalSecondsAndAmbiguousDSTTimesLosslessly() throws {
        let start = date("2026-11-01T06:30:00Z").addingTimeInterval(0.1234567)
        let end = date("2026-11-01T07:45:00Z").addingTimeInterval(0.7654321)
        let session = WorkSession(start: start, end: end, workloadName: "@Research", colorHex: "ABCDEF", source: "=Siri")
        let csv = CSVExporter.text(sessions: [session], now: now)
        let row = try XCTUnwrap(CSVImporter.parse(data: Data(csv.utf8), now: now).first)
        XCTAssertEqual(row.start, start)
        XCTAssertEqual(row.end, end)
        XCTAssertEqual(row.workloadName, "@Research")
        XCTAssertEqual(row.source, "=Siri")
        XCTAssertEqual(row.id, session.id)
    }

    func testMalformedQuotedFieldsAreRejected() {
        for csv in [
            "Start,End,Workload\n2026-11-01T09:00:00Z,2026-11-01T10:00:00Z,\"unfinished",
            "Start,End,Workload\n2026-11-01T09:00:00Z,2026-11-01T10:00:00Z,bare\"quote",
            "Start,End,Workload\n2026-11-01T09:00:00Z,2026-11-01T10:00:00Z,\"closed\"text"
        ] {
            XCTAssertThrowsError(try CSVImporter.parse(data: Data(csv.utf8), now: now))
        }
    }

    func testOriginalAliasesAndSeparateDayTimeFields() throws {
        let csv = "Date,Started,Ended,Source\r\n2026-10-15,09:30,10:45,watch\r\n"
        let rows = try CSVImporter.parse(data: Data(csv.utf8), now: now)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.year, from: rows[0].start), 2026)
        XCTAssertEqual(calendar.component(.month, from: rows[0].start), 10)
        XCTAssertEqual(calendar.component(.day, from: rows[0].start), 15)
        XCTAssertEqual(calendar.component(.hour, from: rows[0].start), 9)
        XCTAssertEqual(calendar.component(.minute, from: rows[0].start), 30)
        XCTAssertEqual(rows[0].end!.timeIntervalSince(rows[0].start), 4500)
        XCTAssertEqual(rows[0].source, "watch")
        XCTAssertEqual(rows[0].workloadName, "Work")
        XCTAssertEqual(rows[0].colorHex, "43D10D")
    }

    func testUTF16AndStartTimeAliases() throws {
        let csv = "Start Time,End Time\r\n2026-11-01T09:00:00Z,2026-11-01T10:00:00Z\r\n"
        let rows = try CSVImporter.parse(data: XCTUnwrap(csv.data(using: .utf16)), now: now)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].end!.timeIntervalSince(rows[0].start), 3600)
    }

    func testAppendPreservesOverlapsAndDeduplicatesExplicitIDs() throws {
        let existing = WorkSession(start: date("2026-11-01T09:00:00Z"), end: date("2026-11-01T11:00:00Z"), source: "watch")
        let imported = WorkSession(start: date("2026-11-01T10:00:00Z"), end: date("2026-11-01T12:00:00Z"), source: "Siri")
        let settings = TrackingSettings(weeklyGoalHours: 37.5, dailyLimitHours: 7.5, focus: .observe)
        var snapshot = TrackingSnapshot(sessions: [existing], settings: settings)
        let rows = try CSVImporter.parse(data: Data(CSVExporter.text(sessions: [imported], now: now).utf8), now: now)
        XCTAssertEqual(try CSVImporter.apply(rows, to: &snapshot, replaceExisting: false, now: now), 1)
        XCTAssertEqual(try CSVImporter.apply(rows, to: &snapshot, replaceExisting: false, now: now), 0)
        XCTAssertEqual(snapshot.sessions.count, 2)
        XCTAssertEqual(snapshot.settings, settings)
        XCTAssertEqual(snapshot.sessions.first(where: { $0.id == existing.id }), existing)
        XCTAssertEqual(TimeMath.total(sessions: snapshot.sessions, in: DateInterval(start: existing.start, duration: 86400), now: now), 10800)
    }

    func testUnidentifiedRowsDeduplicateAcrossRepeatedImports() throws {
        let csv = "Start,End\n2026-11-01T09:00:00Z,2026-11-01T10:00:00Z\n2026-11-01T09:00:00Z,2026-11-01T10:00:00Z\n"
        var snapshot = TrackingSnapshot.empty
        let first = try CSVImporter.parse(data: Data(csv.utf8), now: now)
        XCTAssertEqual(try CSVImporter.apply(first, to: &snapshot, replaceExisting: false, now: now), 1)
        let again = try CSVImporter.parse(data: Data(csv.utf8), now: now)
        XCTAssertEqual(try CSVImporter.apply(again, to: &snapshot, replaceExisting: false, now: now), 0)
        XCTAssertEqual(snapshot.sessions.count, 1)
    }

    func testReplaceCreatesTombstonesAndPreservesWorkloadsAndSettings() throws {
        let existing = WorkSession(start: date("2026-11-01T09:00:00Z"), end: date("2026-11-01T10:00:00Z"), modifiedAt: date("2026-11-01T10:00:00Z"))
        let archived = Workload(name: "Archived", colorHex: "7955EB", isArchived: true)
        let settings = TrackingSettings(weeklyGoalHours: 37.5, dailyLimitHours: 7.5, focus: .momentum)
        let original = TrackingSnapshot(sessions: [existing], workloads: Workload.presets + [archived], settings: settings)
        var snapshot = original
        let csv = "Start,End,Workload,Color,Source\n2026-11-02T09:00:00Z,2026-11-02T10:00:00Z,Research,#ABCDEF,Siri\n"
        let rows = try CSVImporter.parse(data: Data(csv.utf8), now: now)
        XCTAssertEqual(try CSVImporter.apply(rows, to: &snapshot, replaceExisting: true, now: now), 1)
        XCTAssertNotNil(snapshot.sessions.first(where: { $0.id == existing.id })?.deletedAt)
        XCTAssertEqual(snapshot.sessions.filter { $0.deletedAt == nil }.count, 1)
        XCTAssertEqual(snapshot.settings, settings)
        XCTAssertEqual(snapshot.workloads.first(where: { $0.id == archived.id }), archived)
        XCTAssertTrue(snapshot.workloads.contains(where: { $0.name == "Research" && $0.colorHex == "ABCDEF" }))
        let merged = snapshot.merged(with: original)
        XCTAssertNotNil(merged.sessions.first(where: { $0.id == existing.id })?.deletedAt)
    }

    func testBadRowDoesNotChangeRepositoryDuringReplace() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SnapshotRepository(fileURL: directory.appendingPathComponent("history.json"))
        let existing = WorkSession(start: date("2026-11-01T09:00:00Z"), end: date("2026-11-01T10:00:00Z"))
        try repository.update { $0.sessions = [existing] }
        let original = try Data(contentsOf: repository.fileURL)
        let csv = "Start,End\n2026-11-02T09:00:00Z,2026-11-02T10:00:00Z\ninvalid,2026-11-03T10:00:00Z\n"
        XCTAssertThrowsError(try {
            let rows = try CSVImporter.parse(data: Data(csv.utf8), now: now)
            try repository.update { _ = try CSVImporter.apply(rows, to: &$0, replaceExisting: true, now: now) }
        }())
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), original)
    }

    func testConflictingDuplicateIDAbortsAtomicApply() throws {
        let id = UUID()
        let csv = "Session ID,Start,End\n\(id),2026-11-01T09:00:00Z,2026-11-01T10:00:00Z\n\(id),2026-11-02T09:00:00Z,2026-11-02T10:00:00Z\n"
        let rows = try CSVImporter.parse(data: Data(csv.utf8), now: now)
        var snapshot = TrackingSnapshot.empty
        let original = snapshot
        XCTAssertThrowsError(try CSVImporter.apply(rows, to: &snapshot, replaceExisting: true, now: now))
        XCTAssertEqual(snapshot, original)
    }

    func testCompletedOverlappingImportDoesNotStopLiveTimer() throws {
        let start = date("2026-11-01T08:00:00Z")
        let active = WorkSession(start: start, modifiedAt: start)
        var snapshot = TrackingSnapshot(sessions: [active])
        let csv = "Start,End,Source\n2026-11-01T09:00:00Z,2026-11-01T10:00:00Z,watch\n"
        let rows = try CSVImporter.parse(data: Data(csv.utf8), now: now)
        XCTAssertEqual(try CSVImporter.apply(rows, to: &snapshot, replaceExisting: false, now: now), 1)
        XCTAssertEqual(snapshot.activeSession?.id, active.id)
        XCTAssertEqual(snapshot.sessions.first(where: { $0.end != nil })?.timerBoundaries, [])
        let merged = snapshot.merged(with: snapshot)
        XCTAssertEqual(merged.activeSession?.id, active.id)
        XCTAssertEqual(merged.merged(with: merged), merged)
    }

    func testActiveTimerGuardsReplaceAndSecondActiveImport() throws {
        let active = WorkSession(start: date("2026-11-07T10:00:00Z"))
        let original = TrackingSnapshot(sessions: [active])
        var snapshot = original
        let completed = try CSVImporter.parse(data: Data("Start,End\n2026-11-01T09:00:00Z,2026-11-01T10:00:00Z\n".utf8), now: now)
        XCTAssertThrowsError(try CSVImporter.apply(completed, to: &snapshot, replaceExisting: true, now: now))
        XCTAssertEqual(snapshot, original)
        let another = try CSVImporter.parse(data: Data("Start,End\n2026-11-07T11:00:00Z,\n".utf8), now: now)
        XCTAssertThrowsError(try CSVImporter.apply(another, to: &snapshot, replaceExisting: false, now: now))
        XCTAssertEqual(snapshot, original)
    }

    func testInvalidChronologyAndFutureRowsAreRejected() {
        for row in ["invalid,2026-11-01T10:00:00Z", "2026-11-01T11:00:00Z,2026-11-01T10:00:00Z", "2026-11-08T09:00:00Z,2026-11-08T10:00:00Z"] {
            XCTAssertThrowsError(try CSVImporter.parse(data: Data("Start,End\n\(row)\n".utf8), now: now))
        }
        XCTAssertThrowsError(try CSVImporter.parse(data: Data("Start,End\n".utf8), now: now))
    }
}
