import XCTest
@testable import PunchinoCore

final class CoreTests: XCTestCase {
    private func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }

    func testBuiltInWorkloadColorsKeepTheirExistingInkAndSurfaceStyles() {
        for workload in Workload.presets {
            for hex in [workload.colorHex, " #" + workload.colorHex.lowercased() + "\n"] {
                XCTAssertFalse(WorkloadColorStyle.phoneNeedsDarkInk(hex), workload.name)
                XCTAssertFalse(WorkloadColorStyle.watchNeedsLightInk(hex), workload.name)
                XCTAssertFalse(WorkloadColorStyle.textNeedsPrimaryInk(hex, onDarkSurface: true), workload.name)
                XCTAssertFalse(WorkloadColorStyle.textNeedsPrimaryInk(hex, onDarkSurface: false), workload.name)
            }
            XCTAssertFalse(WorkloadColorStyle.blendsIntoSurface(workload.colorHex, onDarkSurface: true), workload.name)
            XCTAssertFalse(WorkloadColorStyle.blendsIntoSurface(workload.colorHex, onDarkSurface: false), workload.name)
        }
    }

    func testCustomLightAndDarkColorsChooseReadableInk() {
        for hex in ["FFFFFF", "FFFF00", "F4E8FF", "CCCCCC"] {
            XCTAssertTrue(WorkloadColorStyle.phoneNeedsDarkInk(hex), hex)
            XCTAssertFalse(WorkloadColorStyle.watchNeedsLightInk(hex), hex)
        }
        for hex in ["000000", "151515", "000066", "333333"] {
            XCTAssertFalse(WorkloadColorStyle.phoneNeedsDarkInk(hex), hex)
            XCTAssertTrue(WorkloadColorStyle.watchNeedsLightInk(hex), hex)
        }
    }

    func testCustomMiddleColorInkMeetsMeasuredBaseColorContrast() {
        let colors: [(String, Double)] = [
            ("BFBFBF", 0.520995573), ("B0B0B0", 0.434153636),
            ("606060", 0.116970668), ("808080", 0.215860500),
            ("757575", 0.177888416), ("777777", 0.184474995),
            ("00FF00", 0.7152), ("FF00FF", 0.2848),
            ("0000FF", 0.0722), ("FF0000", 0.2126)
        ]
        for (hex, luminance) in colors {
            let phoneInk = WorkloadColorStyle.phoneNeedsDarkInk(hex) ? 0.0 : 1.0
            let watchInk = WorkloadColorStyle.watchNeedsLightInk(hex) ? 1.0 : 0.0
            for ink in [phoneInk, watchInk] {
                let contrast = (max(ink, luminance) + 0.05) / (min(ink, luminance) + 0.05)
                XCTAssertGreaterThanOrEqual(contrast, 4.5, hex)
            }
        }
    }

    func testCustomLabelTextMeetsMeasuredNeutralSurfaceContrast() {
        let colors: [(String, Double)] = [
            ("BFBFBF", 0.520995573), ("606060", 0.116970668),
            ("808080", 0.215860500), ("777777", 0.184474995),
            ("00FF00", 0.7152), ("FF00FF", 0.2848),
            ("0000FF", 0.0722), ("FF0000", 0.2126)
        ]
        for (onDarkSurface, surface) in [(false, 0.890969073), (true, 0.025340937)] {
            for (hex, luminance) in colors {
                let foreground = WorkloadColorStyle.textNeedsPrimaryInk(hex, onDarkSurface: onDarkSurface)
                    ? (onDarkSurface ? 1.0 : 0.0) : luminance
                let contrast = (max(foreground, surface) + 0.05) / (min(foreground, surface) + 0.05)
                XCTAssertGreaterThanOrEqual(contrast, 4.5, "\(hex), dark: \(onDarkSurface)")
            }
        }
    }

    func testSurfaceBlendingDependsOnSurfaceBrightness() {
        for hex in ["FFFFFF", "EFEFEF", "FFFFDD"] {
            XCTAssertTrue(WorkloadColorStyle.blendsIntoSurface(hex, onDarkSurface: false), hex)
            XCTAssertFalse(WorkloadColorStyle.blendsIntoSurface(hex, onDarkSurface: true), hex)
        }
        for hex in ["000000", "1C1C1E", "333333"] {
            XCTAssertTrue(WorkloadColorStyle.blendsIntoSurface(hex, onDarkSurface: true), hex)
            XCTAssertFalse(WorkloadColorStyle.blendsIntoSurface(hex, onDarkSurface: false), hex)
        }
        XCTAssertFalse(WorkloadColorStyle.blendsIntoSurface("808080", onDarkSurface: true))
        XCTAssertFalse(WorkloadColorStyle.blendsIntoSurface("808080", onDarkSurface: false))
    }

    func testColorStyleAcceptsHexFormattingAndLeavesStoredDataUnchanged() throws {
        let workload = Workload(name: "Custom", colorHex: "#f4e8ff")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let before = try encoder.encode(workload)
        XCTAssertTrue(WorkloadColorStyle.phoneNeedsDarkInk("  #f4e8ff\n"))
        XCTAssertTrue(WorkloadColorStyle.watchNeedsLightInk("#000066"))
        for invalid in ["", "XYZXYZ", "FFF", "12345678"] {
            XCTAssertFalse(WorkloadColorStyle.phoneNeedsDarkInk(invalid))
            XCTAssertFalse(WorkloadColorStyle.watchNeedsLightInk(invalid))
            XCTAssertFalse(WorkloadColorStyle.blendsIntoSurface(invalid, onDarkSurface: true))
            XCTAssertFalse(WorkloadColorStyle.blendsIntoSurface(invalid, onDarkSurface: false))
            XCTAssertFalse(WorkloadColorStyle.textNeedsPrimaryInk(invalid, onDarkSurface: true))
            XCTAssertFalse(WorkloadColorStyle.textNeedsPrimaryInk(invalid, onDarkSurface: false))
        }
        XCTAssertEqual(try encoder.encode(workload), before)
        XCTAssertEqual(workload.colorHex, "F4E8FF")
    }

    func testLegacySettingsWithoutFocusKeepGoalsAndDefaultToBalance() throws {
        let data = Data(#"{"weeklyGoalHours":37.5,"dailyLimitHours":7.5,"themeHex":"2699F5","weekStartsMonday":false,"modifiedAt":0}"#.utf8)
        let settings = try JSONDecoder().decode(TrackingSettings.self, from: data)
        XCTAssertEqual(settings.focus, .balance)
        XCTAssertEqual(settings.weeklyGoalHours, 37.5)
        XCTAssertEqual(settings.dailyLimitHours, 7.5)
        XCTAssertEqual(settings.themeHex, "2699F5")
        XCTAssertFalse(settings.weekStartsMonday)
        XCTAssertEqual(settings.modifiedAt, Date(timeIntervalSinceReferenceDate: 0))
    }

    func testEveryFocusRoundTripsWithoutChangingGoals() throws {
        for focus in TrackingFocus.allCases {
            let settings = TrackingSettings(weeklyGoalHours: 37.5, dailyLimitHours: 7.5, focus: focus)
            let decoded = try JSONDecoder().decode(TrackingSettings.self, from: JSONEncoder().encode(settings))
            XCTAssertEqual(decoded, settings)
            XCTAssertEqual(decoded.weeklyGoalHours, 37.5)
            XCTAssertEqual(decoded.dailyLimitHours, 7.5)
        }
        XCTAssertEqual(TrackingFocus.balance.title, "Find Balance")
        XCTAssertEqual(TrackingFocus.momentum.title, "Build Momentum")
        XCTAssertEqual(TrackingFocus.observe.title, "Just Observe")
    }

    func testMidnightSessionSplitsAcrossDays() {
        let start = date("2026-11-07T23:00:00Z")
        let end = date("2026-11-08T02:00:00Z")
        let session = WorkSession(start: start, end: end)
        let midnight = date("2026-11-08T00:00:00Z")
        XCTAssertEqual(TimeMath.total(sessions: [session], in: DateInterval(start: start, end: midnight), now: end), 3600)
        XCTAssertEqual(TimeMath.total(sessions: [session], in: DateInterval(start: midnight, end: end), now: end), 7200)
    }

    func testDaylightSavingDayUsesActualElapsedTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let start = date("2026-11-01T05:00:00Z")
        let day = calendar.dateInterval(of: .day, for: start)!
        XCTAssertEqual(day.duration, 25 * 3600)
        let session = WorkSession(start: start, end: day.end)
        XCTAssertEqual(TimeMath.total(sessions: [session], in: day, now: day.end), 25 * 3600)
    }

    func testOverlapsDoNotInflateTotal() {
        let start = date("2026-11-07T09:00:00Z")
        let sessions = [WorkSession(start: start, end: start.addingTimeInterval(7200)), WorkSession(start: start.addingTimeInterval(3600), end: start.addingTimeInterval(10800))]
        XCTAssertEqual(TimeMath.total(sessions: sessions, in: DateInterval(start: start, duration: 86400), now: start.addingTimeInterval(20000)), 10800)
    }

    func testActiveSessionUsesCurrentTimeAndPeriodBoundary() {
        let start = date("2026-11-07T09:00:00Z")
        let session = WorkSession(start: start)
        XCTAssertEqual(TimeMath.total(sessions: [session], in: DateInterval(start: start.addingTimeInterval(600), duration: 1200), now: start.addingTimeInterval(1200)), 600)
    }

    func testInvalidRangesFutureDatesAndOverlapAreRejected() {
        let now = date("2026-11-07T12:00:00Z")
        let start = now.addingTimeInterval(-7200)
        XCTAssertThrowsError(try SessionValidator.validate(WorkSession(start: start, end: start), existing: [], now: now)) { XCTAssertEqual($0 as? TrackingError, .invalidDateRange) }
        XCTAssertThrowsError(try SessionValidator.validate(WorkSession(start: now.addingTimeInterval(1)), existing: [], now: now)) { XCTAssertEqual($0 as? TrackingError, .futureDate) }
        let existing = WorkSession(start: start, end: start.addingTimeInterval(3600))
        XCTAssertThrowsError(try SessionValidator.validate(WorkSession(start: start.addingTimeInterval(1800), end: now), existing: [existing], now: now)) { XCTAssertEqual($0 as? TrackingError, .overlappingSession) }
        XCTAssertNoThrow(try SessionValidator.validate(WorkSession(start: existing.end!, end: now), existing: [existing], now: now))
    }

    func testDeletedSessionDoesNotReturnAfterMerge() {
        let start = date("2026-11-07T09:00:00Z")
        let session = WorkSession(start: start, end: start.addingTimeInterval(3600), modifiedAt: start)
        var deleted = session
        deleted.deletedAt = start.addingTimeInterval(7200)
        deleted.modifiedAt = deleted.deletedAt!
        let old = TrackingSnapshot(sessions: [session])
        let new = TrackingSnapshot(sessions: [deleted])
        XCTAssertEqual(old.merged(with: new), new.merged(with: old))
        XCTAssertNotNil(new.merged(with: old).sessions[0].deletedAt)
        XCTAssertEqual(TimeMath.total(sessions: new.sessions, in: DateInterval(start: start, duration: 86400), now: start.addingTimeInterval(10000)), 0)
    }

    func testEqualTimestampTombstoneAndStoppedTimerWin() {
        let start = date("2026-11-07T09:00:00Z")
        let active = WorkSession(start: start, modifiedAt: start)
        var stopped = active
        stopped.end = start.addingTimeInterval(3600)
        let a = TrackingSnapshot(sessions: [active])
        let b = TrackingSnapshot(sessions: [stopped])
        XCTAssertEqual(a.merged(with: b).sessions.first?.end, stopped.end)
        stopped.deletedAt = start
        XCTAssertNotNil(a.merged(with: TrackingSnapshot(sessions: [stopped])).sessions.first?.deletedAt)
    }

    func testConcurrentStartsKeepOneTimerAndPreserveElapsedTime() {
        let start = date("2026-11-07T09:00:00Z")
        let first = WorkSession(start: start, modifiedAt: start)
        let second = WorkSession(start: start.addingTimeInterval(3600), modifiedAt: start.addingTimeInterval(3600))
        let merged = TrackingSnapshot(sessions: [first]).merged(with: TrackingSnapshot(sessions: [second]))
        XCTAssertEqual(merged.sessions.filter(\.isActive).count, 1)
        XCTAssertEqual(merged.activeSession?.id, second.id)
        XCTAssertEqual(merged.sessions.first(where: { $0.id == first.id })?.end, second.start)
        XCTAssertEqual(TimeMath.total(sessions: merged.sessions, in: DateInterval(start: start, duration: 86400), now: start.addingTimeInterval(7200)), 7200)
    }

    func testReconciliationConvergesWhenIntermediateStartArrivesLate() {
        let start = date("2026-11-07T09:00:00Z")
        let a = TrackingSnapshot(sessions: [WorkSession(start: start, modifiedAt: start)])
        let b = TrackingSnapshot(sessions: [WorkSession(start: start.addingTimeInterval(3600), modifiedAt: start.addingTimeInterval(3600))])
        let c = TrackingSnapshot(sessions: [WorkSession(start: start.addingTimeInterval(7200), modifiedAt: start.addingTimeInterval(7200))])
        XCTAssertEqual(a.merged(with: c).merged(with: b), a.merged(with: b).merged(with: c))
    }

    func testThreeDeviceActiveMergeIsIndependentOfRecordOrder() {
        let start = date("2026-11-07T09:00:00Z")
        let snapshots = (0..<3).map { offset in
            let time = start.addingTimeInterval(Double(offset * 3600))
            return TrackingSnapshot(sessions: [WorkSession(start: time, modifiedAt: time)])
        }
        let expected = snapshots.reduce(TrackingSnapshot.empty) { $0.merged(with: $1) }
        for order in permutations(snapshots) {
            let merged = order.reduce(TrackingSnapshot.empty) { $0.merged(with: $1) }
            XCTAssertEqual(merged, expected)
            XCTAssertEqual(merged.merged(with: merged), merged)
            XCTAssertEqual(order[0].merged(with: order[1]).merged(with: order[2]), order[0].merged(with: order[1].merged(with: order[2])))
        }
        XCTAssertEqual(expected.sessions.filter(\.isActive).count, 1)
    }

    func testExplicitStopWinsOverDerivedClosureInEveryMergeOrder() {
        let start = date("2026-11-07T08:00:00Z")
        let original = WorkSession(start: start, modifiedAt: start)
        var stopped = original
        stopped.end = start.addingTimeInterval(3600)
        stopped.modifiedAt = start.addingTimeInterval(3600)
        let next = WorkSession(start: start.addingTimeInterval(7200), modifiedAt: start.addingTimeInterval(7200))
        let snapshots = [TrackingSnapshot(sessions: [original]), TrackingSnapshot(sessions: [stopped]), TrackingSnapshot(sessions: [next])]
        let expected = snapshots.reduce(TrackingSnapshot.empty) { $0.merged(with: $1) }
        for order in permutations(snapshots) {
            let merged = order.reduce(TrackingSnapshot.empty) { $0.merged(with: $1) }
            XCTAssertEqual(merged, expected)
            XCTAssertEqual(merged.sessions.first(where: { $0.id == original.id })?.end, stopped.end)
            XCTAssertEqual(TimeMath.total(sessions: merged.sessions, in: DateInterval(start: start, duration: 86400), now: next.start.addingTimeInterval(3600)), 7200)
        }
    }

    func testDeletionWinsOverDerivedClosureInEveryMergeOrder() {
        let start = date("2026-11-07T08:00:00Z")
        let original = WorkSession(start: start, modifiedAt: start)
        var deleted = original
        deleted.deletedAt = start.addingTimeInterval(3600)
        deleted.modifiedAt = start.addingTimeInterval(3600)
        let next = WorkSession(start: start.addingTimeInterval(7200), modifiedAt: start.addingTimeInterval(7200))
        let snapshots = [TrackingSnapshot(sessions: [original]), TrackingSnapshot(sessions: [deleted]), TrackingSnapshot(sessions: [next])]
        let expected = snapshots.reduce(TrackingSnapshot.empty) { $0.merged(with: $1) }
        for order in permutations(snapshots) {
            let merged = order.reduce(TrackingSnapshot.empty) { $0.merged(with: $1) }
            XCTAssertEqual(merged, expected)
            XCTAssertNotNil(merged.sessions.first(where: { $0.id == original.id })?.deletedAt)
        }
    }

    func testLargeHistoryPatchIncludesActiveStopDeletionAndArchives() throws {
        let start = date("2026-11-07T08:00:00Z")
        var history = (0..<500).map { offset in
            let time = start.addingTimeInterval(Double(offset * 3600))
            return WorkSession(start: time, end: time.addingTimeInterval(1800), modifiedAt: time)
        }
        let active = WorkSession(start: start.addingTimeInterval(-3600), modifiedAt: start)
        var stopped = history[0]
        stopped.modifiedAt = start.addingTimeInterval(3_000_000)
        var deleted = history[1]
        deleted.deletedAt = start.addingTimeInterval(2_999_999)
        deleted.modifiedAt = deleted.deletedAt!
        history[0] = stopped
        history[1] = deleted
        history.append(active)
        var archived = Workload.presets[0]
        archived.isArchived = true
        archived.modifiedAt = stopped.modifiedAt
        let snapshot = TrackingSnapshot(sessions: history, workloads: [archived] + Array(Workload.presets.dropFirst()))
        XCTAssertGreaterThan(try JSONEncoder().encode(snapshot).count, 50_000)
        let patch = try XCTUnwrap(snapshot.immediatePatch())
        XCTAssertTrue(patch.sessions.contains(where: { $0.id == active.id && $0.isActive }))
        XCTAssertTrue(patch.sessions.contains(where: { $0.id == stopped.id && $0.end == stopped.end }))
        XCTAssertTrue(patch.sessions.contains(where: { $0.id == deleted.id && $0.deletedAt != nil }))
        XCTAssertEqual(patch.workloads.count, snapshot.workloads.count)
        XCTAssertTrue(patch.workloads.first(where: { $0.id == archived.id })!.isArchived)
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(patch).count, 48_000)
        XCTAssertEqual(snapshot.merged(with: patch), snapshot.merged(with: snapshot))
    }

    func testImmediatePatchRespectsByteBudgetWithoutRevivingArchives() throws {
        let start = date("2026-11-07T08:00:00Z")
        let workloads = (0..<40).map { index in
            Workload(name: String(repeating: "Workload ", count: 80), colorHex: "43D10D", isArchived: index.isMultiple(of: 2), modifiedAt: start.addingTimeInterval(Double(index)))
        }
        var deleted = WorkSession(start: start, end: start.addingTimeInterval(1800), workloadName: "Deleted", modifiedAt: start.addingTimeInterval(1000))
        deleted.deletedAt = deleted.modifiedAt
        let active = WorkSession(start: start.addingTimeInterval(500), modifiedAt: start.addingTimeInterval(500))
        let snapshot = TrackingSnapshot(sessions: [deleted, active], workloads: workloads)
        let patch = try XCTUnwrap(snapshot.immediatePatch(maximumBytes: 4000))
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(patch).count, 4000)
        XCTAssertTrue(patch.sessions.contains(where: { $0.id == active.id && $0.isActive }))
        XCTAssertTrue(patch.sessions.contains(where: { $0.id == deleted.id && $0.deletedAt != nil }))
        let merged = snapshot.merged(with: patch)
        XCTAssertEqual(merged.workloads.filter(\.isArchived).count, workloads.filter(\.isArchived).count)
        XCTAssertEqual(merged.workloads.count, workloads.count)
        XCTAssertNil(snapshot.immediatePatch(maximumBytes: 1))
    }

    func testNewerCompletedTimerClosesOlderOfflineActiveTimer() {
        let start = date("2026-11-01T08:00:00Z")
        let older = WorkSession(start: start, workloadName: "Work", source: "iPhone", modifiedAt: start)
        let newer = WorkSession(start: start.addingTimeInterval(3600), end: start.addingTimeInterval(7200), workloadName: "Study", source: "watch", modifiedAt: start.addingTimeInterval(7200))
        let a = TrackingSnapshot(sessions: [older])
        let b = TrackingSnapshot(sessions: [newer])
        let merged = a.merged(with: b)
        XCTAssertNil(merged.activeSession)
        XCTAssertEqual(merged.sessions.first(where: { $0.id == older.id })?.end, newer.start)
        XCTAssertEqual(TimeMath.total(sessions: merged.sessions, in: DateInterval(start: start, duration: 86400), now: start.addingTimeInterval(10800)), 7200)
        XCTAssertEqual(merged, b.merged(with: a))
        XCTAssertEqual(merged.merged(with: merged), merged)
    }

    func testDeletedNewerTimerKeepsBoundaryInEveryMergeOrder() {
        let start = date("2026-11-01T08:00:00Z")
        let older = WorkSession(start: start, modifiedAt: start)
        let newer = WorkSession(start: start.addingTimeInterval(3600), end: start.addingTimeInterval(7200), modifiedAt: start.addingTimeInterval(7200))
        var deleted = newer
        deleted.deletedAt = start.addingTimeInterval(10800)
        deleted.modifiedAt = deleted.deletedAt!
        let snapshots = [TrackingSnapshot(sessions: [older]), TrackingSnapshot(sessions: [newer]), TrackingSnapshot(sessions: [deleted])]
        let expected = snapshots.reduce(TrackingSnapshot.empty) { $0.merged(with: $1) }
        for order in permutations(snapshots) {
            let merged = order[0].merged(with: order[1]).merged(with: order[2])
            XCTAssertEqual(merged, order[0].merged(with: order[1].merged(with: order[2])))
            XCTAssertEqual(merged, expected)
            XCTAssertEqual(merged.merged(with: merged), merged)
            XCTAssertNil(merged.activeSession)
            XCTAssertEqual(merged.sessions.first(where: { $0.id == older.id })?.end, newer.start)
            XCTAssertNotNil(merged.sessions.first(where: { $0.id == newer.id })?.deletedAt)
        }
    }

    func testExplicitStopStillBeatsInferredBoundaryFromCompletedTimer() {
        let start = date("2026-11-01T08:00:00Z")
        let older = WorkSession(start: start, modifiedAt: start)
        var stopped = older
        stopped.end = start.addingTimeInterval(1800)
        stopped.modifiedAt = stopped.end!
        let newer = WorkSession(start: start.addingTimeInterval(3600), end: start.addingTimeInterval(7200), modifiedAt: start.addingTimeInterval(7200))
        let snapshots = [TrackingSnapshot(sessions: [older]), TrackingSnapshot(sessions: [stopped]), TrackingSnapshot(sessions: [newer])]
        for order in permutations(snapshots) {
            let merged = order[0].merged(with: order[1]).merged(with: order[2])
            XCTAssertEqual(merged, order[0].merged(with: order[1].merged(with: order[2])))
            XCTAssertEqual(merged.sessions.first(where: { $0.id == older.id })?.end, stopped.end)
            XCTAssertNil(merged.activeSession)
        }
    }

    func testLegacySessionWithoutBoundaryMetadataStillReconciles() throws {
        let start = date("2026-11-01T08:00:00Z")
        let newer = WorkSession(start: start.addingTimeInterval(3600), end: start.addingTimeInterval(7200), modifiedAt: start.addingTimeInterval(7200))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(newer)) as? [String: Any])
        object.removeValue(forKey: "timerBoundaries")
        let legacy = try JSONDecoder().decode(WorkSession.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(legacy.timerBoundaries)
        let merged = TrackingSnapshot(sessions: [WorkSession(start: start, modifiedAt: start)]).merged(with: TrackingSnapshot(sessions: [legacy]))
        XCTAssertNil(merged.activeSession)
        XCTAssertEqual(merged.sessions.first(where: { $0.start == start })?.end, legacy.start)
    }

    func testBoundaryUnionDoesNotChangeEqualTimestampPayloadTie() {
        let start = date("2026-11-01T08:00:00Z")
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let first = TimerBoundary(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, start: start)
        let second = TimerBoundary(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, start: start)
        let names = ["Alpha", "Beta", "Gamma"]
        let snapshots = names.enumerated().map { index, name in
            TrackingSnapshot(sessions: [WorkSession(id: id, start: start, end: start.addingTimeInterval(3600), workloadName: name, modifiedAt: start, timerBoundaries: index == 0 ? [second] : [first])])
        }
        let expected = snapshots.reduce(TrackingSnapshot.empty) { $0.merged(with: $1) }
        for order in permutations(snapshots) {
            let merged = order[0].merged(with: order[1]).merged(with: order[2])
            XCTAssertEqual(merged, order[0].merged(with: order[1].merged(with: order[2])))
            XCTAssertEqual(merged, expected)
            XCTAssertEqual(merged.merged(with: merged), merged)
            XCTAssertEqual(merged.sessions.first?.workloadName, "Gamma")
            XCTAssertEqual(merged.sessions.first?.timerBoundaries?.count, 2)
        }
    }

    func testInferredClosureDoesNotChangeEqualTimestampWorkloadTie() {
        let start = date("2026-11-01T08:00:00Z")
        let id = UUID()
        let a = WorkSession(id: id, start: start, workloadName: "Alpha", modifiedAt: start)
        let b = WorkSession(id: id, start: start, workloadName: "Beta", modifiedAt: start)
        let later = WorkSession(start: start.addingTimeInterval(3600), end: start.addingTimeInterval(7200), modifiedAt: start.addingTimeInterval(7200))
        let snapshots = [TrackingSnapshot(sessions: [a]), TrackingSnapshot(sessions: [b]), TrackingSnapshot(sessions: [later])]
        let expected = snapshots.reduce(TrackingSnapshot.empty) { $0.merged(with: $1) }
        for order in permutations(snapshots) {
            let merged = order[0].merged(with: order[1]).merged(with: order[2])
            XCTAssertEqual(merged, order[0].merged(with: order[1].merged(with: order[2])))
            XCTAssertEqual(merged, expected)
            XCTAssertEqual(merged.merged(with: merged), merged)
            XCTAssertNil(merged.activeSession)
            XCTAssertEqual(merged.sessions.first(where: { $0.id == id })?.workloadName, "Beta")
            XCTAssertEqual(merged.sessions.first(where: { $0.id == id })?.end, later.start)
        }
    }

    private func permutations<T>(_ values: [T]) -> [[T]] {
        if values.isEmpty { return [[]] }
        return values.indices.flatMap { index in
            var remaining = values
            let first = remaining.remove(at: index)
            return permutations(remaining).map { [first] + $0 }
        }
    }

    func testCSVPreservesNamesAndPreventsFormulaExecution() {
        let start = date("2026-11-07T09:00:00Z")
        let session = WorkSession(start: start, end: start.addingTimeInterval(3600), workloadName: "Research, \"notes\"\nDraft", source: "=SUM(A1)")
        let csv = CSVExporter.text(sessions: [session], now: start.addingTimeInterval(4000))
        XCTAssertTrue(csv.contains("\"Research, \"\"notes\"\"\nDraft\""))
        XCTAssertTrue(csv.contains("'" + "=SUM(A1)"))
        XCTAssertTrue(csv.contains(",60,1.00,"))
        XCTAssertTrue(csv.hasPrefix("Start Date,Start Time,End Date,End Time,Duration (minutes),Duration (hours),Source,"))
        XCTAssertTrue(csv.hasSuffix("\r\n"))
    }

    func testRepositoryPreservesUpdatesAndTombstones() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SnapshotRepository(fileURL: directory.appendingPathComponent("tracking.json"))
        XCTAssertTrue(try repository.load().sessions.isEmpty)
        let start = date("2026-11-07T09:00:00Z")
        let a = WorkSession(start: start, end: start.addingTimeInterval(3600), modifiedAt: start)
        let b = WorkSession(start: start.addingTimeInterval(7200), end: start.addingTimeInterval(10800), modifiedAt: start)
        try repository.update { $0.sessions.append(a) }
        try repository.update { $0.sessions.append(b) }
        XCTAssertEqual(try repository.load().sessions.count, 2)
        var deleted = a
        deleted.deletedAt = start.addingTimeInterval(20000)
        deleted.modifiedAt = start.addingTimeInterval(20000)
        try repository.merge(TrackingSnapshot(sessions: [deleted]))
        try repository.merge(TrackingSnapshot(sessions: [a]))
        XCTAssertNotNil(try repository.load().sessions.first(where: { $0.id == a.id })?.deletedAt)
    }

    func testConcurrentWritersKeepEverySession() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SnapshotRepository(fileURL: directory.appendingPathComponent("tracking.json"))
        let errors = LockedErrors()
        let start = date("2026-11-07T09:00:00Z")
        DispatchQueue.concurrentPerform(iterations: 20) { index in
            do {
                let session = WorkSession(start: start.addingTimeInterval(Double(index * 3600)), end: start.addingTimeInterval(Double(index * 3600 + 1800)))
                try repository.update { $0.sessions.append(session) }
            } catch { errors.append(error) }
        }
        XCTAssertTrue(errors.values.isEmpty)
        XCTAssertEqual(try repository.load().sessions.count, 20)
    }

    func testCorruptFileRemainsUnchanged() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("tracking.json")
        let invalid = Data("invalid JSON".utf8)
        try invalid.write(to: url)
        let repository = SnapshotRepository(fileURL: url)
        XCTAssertThrowsError(try repository.update { $0.sessions = [] })
        XCTAssertEqual(try Data(contentsOf: url), invalid)
    }

    func testArchivedWorkloadKeepsRecordedColorAndName() {
        var workload = Workload.presets[0]
        let session = WorkSession(start: date("2026-11-07T09:00:00Z"), workloadID: workload.id, workloadName: workload.name, colorHex: workload.colorHex)
        workload.name = "Updated"
        workload.colorHex = "FFFFFF"
        workload.isArchived = true
        let merged = TrackingSnapshot(sessions: [session]).merged(with: TrackingSnapshot(workloads: [workload]))
        XCTAssertEqual(merged.sessions[0].workloadName, "Work")
        XCTAssertEqual(merged.sessions[0].colorHex, "43D10D")
        XCTAssertTrue(merged.workloads.first(where: { $0.id == workload.id })!.isArchived)
    }
}

private final class LockedErrors: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Error] = []
    var values: [Error] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
    func append(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(error)
    }
}
