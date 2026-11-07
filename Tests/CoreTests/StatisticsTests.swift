import XCTest
@testable import PunchinoCore

final class StatisticsTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-11-07T12:00:00Z")!
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func data(_ range: StatisticsRange, sessions: [WorkSession] = [], settings: TrackingSettings = TrackingSettings()) -> StatisticsData {
        StatisticsData(range: range, sessions: sessions, settings: settings, now: now, calendar: calendar)
    }

    func testTrailingChartRangesAndBucketSizes() {
        let day = data(.day)
        XCTAssertEqual(day.buckets.count, 24)
        XCTAssertEqual(day.chartInterval.start, date("2026-11-06T13:00:00Z"))
        XCTAssertEqual(day.chartInterval.end, date("2026-11-07T13:00:00Z"))
        let week = data(.week)
        XCTAssertEqual(week.buckets.count, 7)
        XCTAssertEqual(week.chartInterval.start, date("2026-11-01T00:00:00Z"))
        XCTAssertEqual(week.chartInterval.end, date("2026-11-08T00:00:00Z"))
        XCTAssertEqual(week.axisDates.map(week.axisLabel), ["Nov 1", "Nov 3", "Nov 5", "Nov 7"])
        let month = data(.month)
        XCTAssertEqual(month.buckets.count, 30)
        XCTAssertEqual(month.chartInterval.start, date("2026-10-09T00:00:00Z"))
        let halfYear = data(.sixMonths)
        XCTAssertEqual(halfYear.chartInterval.start, date("2026-05-07T00:00:00Z"))
        XCTAssertEqual(halfYear.buckets.count, 27)
        XCTAssertEqual(halfYear.axisDates.map(halfYear.axisLabel), ["Jul 1", "Sep 1", "Nov 1"])
        XCTAssertTrue(halfYear.buckets.dropFirst().dropLast().allSatisfy { calendar.component(.weekday, from: $0.start) == 2 })
        let year = data(.year)
        XCTAssertEqual(year.buckets.count, 12)
        XCTAssertEqual(year.chartInterval.start, date("2025-12-01T00:00:00Z"))
        XCTAssertEqual(year.chartInterval.end, date("2026-12-01T00:00:00Z"))
        XCTAssertTrue(year.buckets.allSatisfy { calendar.component(.day, from: $0.start) == 1 })
    }

    func testRollingDailyChartIncludesBothRepeatedHoursOnDaylightSavingDay() {
        var chicago = calendar
        chicago.timeZone = TimeZone(identifier: "America/Chicago")!
        let clock = date("2026-11-01T18:00:00Z")
        let statistics = StatisticsData(range: .day, sessions: [], settings: TrackingSettings(), now: clock, calendar: chicago)
        XCTAssertEqual(statistics.chartInterval.duration, 24 * 3600)
        XCTAssertEqual(statistics.buckets.count, 24)
        XCTAssertEqual(Set(statistics.buckets.map(\.start)).count, 24)
        XCTAssertEqual(statistics.buckets.filter { chicago.component(.hour, from: $0.start) == 1 }.count, 2)
    }

    func testCrossMidnightSessionContributesToBothDaysButCountsOnce() {
        let session = WorkSession(start: date("2026-11-06T23:30:00Z"), end: date("2026-11-07T01:30:00Z"))
        let statistics = data(.week, sessions: [session])
        XCTAssertEqual(statistics.totalSeconds, 2 * 3600)
        XCTAssertEqual(statistics.sessionCount, 1)
        XCTAssertEqual(statistics.workedBuckets.count, 2)
        XCTAssertEqual(statistics.averageSeconds, 3600)
        XCTAssertEqual(statistics.buckets.first { $0.start == date("2026-11-06T00:00:00Z") }?.seconds, 1800)
        XCTAssertEqual(statistics.buckets.first { $0.start == date("2026-11-07T00:00:00Z") }?.seconds, 5400)
        XCTAssertEqual(data(.day, sessions: [session]).totalSeconds, 7200)
        XCTAssertEqual(data(.day, sessions: [session]).currentSeconds, 5400)
    }

    func testEmptyRangesHaveZeroMetricsAndRangeSpecificChartGoals() {
        let settings = TrackingSettings(weeklyGoalHours: 21, dailyLimitHours: 3)
        for range in StatisticsRange.allCases {
            let statistics = data(range, settings: settings)
            XCTAssertEqual(statistics.totalSeconds, 0)
            XCTAssertEqual(statistics.averageSeconds, 0)
            XCTAssertEqual(statistics.sessionCount, 0)
            XCTAssertEqual(statistics.currentSeconds, 0)
            XCTAssertEqual(statistics.previousSeconds, 0)
            XCTAssertEqual(statistics.goalsHit, 0)
            XCTAssertEqual(statistics.averageOverGoal, 0)
            let expectedGoal: Double = range == .year ? 84 : range == .sixMonths ? 21 : 3
            XCTAssertEqual(statistics.chartGoalHours, expectedGoal)
        }
    }

    func testYearProgressUsesDailyGoalWhileChartUsesFourWeeklyGoals() {
        let session = WorkSession(start: date("2026-10-01T00:00:00Z"), end: date("2026-10-01T23:00:00Z"))
        let statistics = data(.year, sessions: [session], settings: TrackingSettings(weeklyGoalHours: 21, dailyLimitHours: 3, focus: .momentum))
        XCTAssertEqual(statistics.chartGoalHours, 84)
        XCTAssertEqual(statistics.workedBuckets.count, 1)
        XCTAssertEqual(statistics.goalsHit, 1)
        XCTAssertEqual(statistics.averageOverGoal, 20 * 3600)
        XCTAssertEqual(statistics.averageSeconds, 23 * 3600)
        XCTAssertEqual(statistics.totalSeconds, 23 * 3600)
        XCTAssertEqual(statistics.currentSeconds, 23 * 3600)
        XCTAssertEqual(statistics.previousSeconds, 0)
    }

    func testWeekComparisonUsesCalendarWeeksInsteadOfChartRange() {
        let session = WorkSession(start: date("2026-11-01T09:00:00Z"), end: date("2026-11-01T11:00:00Z"))
        let statistics = data(.week, sessions: [session])
        XCTAssertEqual(statistics.totalSeconds, 2 * 3600)
        XCTAssertEqual(statistics.currentSeconds, 0)
        XCTAssertEqual(statistics.previousSeconds, 2 * 3600)
    }

    func testHalfYearComparisonUsesConsecutiveSixMonthRanges() {
        let previous = WorkSession(start: date("2026-03-01T09:00:00Z"), end: date("2026-03-01T14:00:00Z"))
        let current = WorkSession(start: date("2026-10-01T09:00:00Z"), end: date("2026-10-01T12:00:00Z"))
        let statistics = data(.sixMonths, sessions: [previous, current])
        XCTAssertEqual(statistics.currentSeconds, 3 * 3600)
        XCTAssertEqual(statistics.previousSeconds, 5 * 3600)
        XCTAssertEqual(statistics.sessionCount, 1)
    }

    func testActiveAndDeletedSessionsRespectCurrentRange() {
        let active = WorkSession(start: date("2026-11-07T11:30:00Z"))
        var deleted = WorkSession(start: date("2026-11-07T09:00:00Z"), end: date("2026-11-07T10:00:00Z"))
        deleted.deletedAt = now
        let statistics = data(.day, sessions: [active, deleted])
        XCTAssertEqual(statistics.totalSeconds, 1800)
        XCTAssertEqual(statistics.currentSeconds, 1800)
        XCTAssertEqual(statistics.sessionCount, 1)
        XCTAssertEqual(statistics.workedBuckets.count, 1)
    }
    func testYearBalanceUsesDailyLimitAgainstMonthlyBuckets() {
        let session = WorkSession(start: date("2026-10-01T00:00:00Z"), end: date("2026-10-01T23:00:00Z"))
        let statistics = data(.year, sessions: [session], settings: TrackingSettings(weeklyGoalHours: 21, dailyLimitHours: 3, focus: .balance))
        XCTAssertEqual(statistics.chartGoalHours, 84)
        XCTAssertEqual(statistics.workedBuckets.count, 1)
        XCTAssertEqual(statistics.periodsWithinLimit, 0)
        XCTAssertEqual(statistics.averageUnderLimit, 0)
    }

    func testBalanceAverageUsesOnlyWorkedPeriodsWithinLimit() {
        let sessions = [
            WorkSession(start: date("2026-11-02T09:00:00Z"), end: date("2026-11-02T10:00:00Z")),
            WorkSession(start: date("2026-11-03T09:00:00Z"), end: date("2026-11-03T11:00:00Z")),
            WorkSession(start: date("2026-11-04T09:00:00Z"), end: date("2026-11-04T15:00:00Z"))
        ]
        let statistics = data(.week, sessions: sessions, settings: TrackingSettings(dailyLimitHours: 3, focus: .balance))
        XCTAssertEqual(statistics.workedBuckets.count, 3)
        XCTAssertEqual(statistics.periodsWithinLimit, 2)
        XCTAssertEqual(statistics.averageUnderLimit, 1.5 * 3600)
        XCTAssertEqual(statistics.goalsHit, 1)
        XCTAssertEqual(statistics.averageOverGoal, 3 * 3600)
    }

    func testExactLimitCountsAsWithinLimitWithZeroRemainingHours() {
        let session = WorkSession(start: date("2026-11-07T09:00:00Z"), end: date("2026-11-07T12:00:00Z"))
        let statistics = data(.week, sessions: [session], settings: TrackingSettings(dailyLimitHours: 3, focus: .balance))
        XCTAssertEqual(statistics.periodsWithinLimit, 1)
        XCTAssertEqual(statistics.averageUnderLimit, 0)
    }

    func testObservePatternsAggregateWeekdaysAcrossActualDays() {
        let sessions = [
            WorkSession(start: date("2026-10-04T09:00:00Z"), end: date("2026-10-04T17:00:00Z")),
            WorkSession(start: date("2026-10-11T09:00:00Z"), end: date("2026-10-11T14:00:00Z")),
            WorkSession(start: date("2026-10-05T09:00:00Z"), end: date("2026-10-05T18:00:00Z"))
        ]
        let statistics = data(.year, sessions: sessions, settings: TrackingSettings(focus: .observe))
        XCTAssertEqual(statistics.mostActiveWeekday, 1)
        XCTAssertEqual(statistics.workedBuckets.count, 1)
        XCTAssertEqual(statistics.typicalRange, (22 * 3600)...(22 * 3600))
    }

    func testObserveTypicalRangeIncludesOnlyNonzeroBuckets() {
        let sessions = [
            WorkSession(start: date("2026-11-02T09:00:00Z"), end: date("2026-11-02T10:00:00Z")),
            WorkSession(start: date("2026-11-03T09:00:00Z"), end: date("2026-11-03T12:00:00Z")),
            WorkSession(start: date("2026-11-04T09:00:00Z"), end: date("2026-11-04T11:00:00Z"))
        ]
        let statistics = data(.week, sessions: sessions, settings: TrackingSettings(focus: .observe))
        XCTAssertEqual(statistics.typicalRange, 3600...10800)
        XCTAssertEqual(statistics.mostActiveWeekday, 3)
        XCTAssertNil(data(.week).typicalRange)
        XCTAssertNil(data(.week).mostActiveWeekday)
    }

    func testObserveTypicalRangeUsesIndexedMiddleHalfWithoutInterpolation() {
        let hours: [Double] = [0.25, 0.5, 0.75, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 8]
        let today = calendar.startOfDay(for: now)
        let sessions = hours.enumerated().map { index, hours in
            let day = calendar.date(byAdding: .day, value: -(index + 1), to: today)!
            let start = calendar.date(byAdding: .hour, value: 9, to: day)!
            return WorkSession(start: start, end: start.addingTimeInterval(hours * 3600))
        }
        let statistics = data(.month, sessions: sessions, settings: TrackingSettings(focus: .observe))
        XCTAssertEqual(statistics.workedBuckets.count, 12)
        XCTAssertEqual(statistics.typicalRange, 3600...18000)
        XCTAssertEqual(statistics.workedBuckets.map(\.hours).min(), 0.25)
        XCTAssertEqual(statistics.workedBuckets.map(\.hours).max(), 8)
    }

    func testMonthAxisFollowsConfiguredWeekStartsAcrossMonthBoundary() {
        let monday = data(.month)
        XCTAssertEqual(monday.axisDates.map(monday.axisLabel), ["Oct 12", "Oct 19", "Oct 26", "Nov 2"])
        XCTAssertTrue(monday.axisDates.allSatisfy { calendar.component(.weekday, from: $0) == 2 })

        var sundayCalendar = calendar
        sundayCalendar.firstWeekday = 1
        let sunday = StatisticsData(range: .month, sessions: [], settings: TrackingSettings(weekStartsMonday: false), now: now, calendar: sundayCalendar)
        XCTAssertEqual(sunday.axisDates.map(sunday.axisLabel), ["Oct 11", "Oct 18", "Oct 25", "Nov 1"])
        XCTAssertTrue(sunday.axisDates.allSatisfy { sundayCalendar.component(.weekday, from: $0) == 1 })
        XCTAssertTrue(sunday.axisDates.allSatisfy { $0 >= sunday.chartInterval.start && $0 < sunday.chartInterval.end })
    }

    func testRollingDayChartTicksAdvanceWithCurrentHour() {
        let early = StatisticsData(range: .day, sessions: [], settings: TrackingSettings(), now: date("2026-11-07T00:20:00Z"), calendar: calendar)
        let later = StatisticsData(range: .day, sessions: [], settings: TrackingSettings(), now: date("2026-11-07T01:49:00Z"), calendar: calendar)
        XCTAssertEqual(early.axisDates.map(early.axisLabel), ["1AM", "7AM", "1PM", "7PM"])
        XCTAssertEqual(later.axisDates.map(later.axisLabel), ["2AM", "8AM", "2PM", "8PM"])
        XCTAssertEqual(later.chartInterval.start, date("2026-11-06T02:00:00Z"))
        XCTAssertEqual(later.rawInterval.start, date("2026-11-06T01:49:00Z"))
        XCTAssertEqual(later.chartInterval.duration, 24 * 3600)
    }

    func testWeekRawSummaryAndWeekdayCanContainSessionsBeforeChartBuckets() {
        let sessions = [
            WorkSession(start: date("2026-10-31T13:00:00Z"), end: date("2026-10-31T13:30:00Z")),
            WorkSession(start: date("2026-10-31T14:00:00Z"), end: date("2026-10-31T15:12:00Z"))
        ]
        let statistics = data(.week, sessions: sessions, settings: TrackingSettings(focus: .observe))
        XCTAssertEqual(statistics.rawInterval.start, date("2026-10-31T12:00:00Z"))
        XCTAssertEqual(statistics.chartInterval.start, date("2026-11-01T00:00:00Z"))
        XCTAssertEqual(statistics.sessionCount, 2)
        XCTAssertEqual(statistics.totalSeconds, 1.7 * 3600)
        XCTAssertEqual(statistics.chartTotalSeconds, 0)
        XCTAssertEqual(statistics.averageSeconds, 0)
        XCTAssertEqual(statistics.workedBuckets.count, 0)
        XCTAssertEqual(statistics.mostActiveWeekday, 7)
        XCTAssertNil(statistics.typicalRange)
        XCTAssertEqual(statistics.goalsHit, 0)
        XCTAssertEqual(statistics.periodsWithinLimit, 0)
        XCTAssertEqual(statistics.averageOverGoal, 0)
        XCTAssertEqual(statistics.averageUnderLimit, 0)
    }

}
