import XCTest
import UIKit

@MainActor
final class PunchinoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.count, 3)
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testFirstTapRevealsColorsWithoutStartingSession() {
        openTrack()
        let punch = app.buttons["punchButton"]
        XCTAssertEqual(punch.label, "Punch in")
        XCTAssertFalse(app.buttons["punchWorkload-Work"].exists)
        XCTAssertTrue(app.staticTexts["Tap to punch in"].exists)
        XCTAssertFalse(app.staticTexts["Today"].isHittable)
        attachScreenshot("Idle Track layout")

        punch.tap()

        for workload in ["Work", "Study", "Personal"] {
            XCTAssertTrue(app.buttons["punchWorkload-\(workload)"].waitForExistence(timeout: 5))
        }
        XCTAssertEqual(punch.label, "Punch in", "The first tap must wait for a workload selection.")
        XCTAssertTrue(app.staticTexts["Choose your workload"].exists)
        attachScreenshot("Workload color choices")
    }

    func testEachSessionKeepsItsSelectedWorkload() {
        openTrack()
        let idleFrame = app.buttons["punchButton"].frame
        attachScreenshot("Idle anchor for live layout")
        startSession(workload: "Work")
        assertActiveTrackingLayout(idleFrame: idleFrame)
        attachScreenshot("Active Work live layout")
        app.buttons["punchButton"].tap()
        waitForPunchLabel("Punch in")

        startSession(workload: "Study")
        assertActiveTrackingLayout(idleFrame: idleFrame)
        XCTAssertTrue(app.staticTexts["Study"].exists)
        attachScreenshot("Active Study session")
        selectTab(0)
        openTrack()
        assertActiveTrackingLayout(idleFrame: idleFrame)
        XCTAssertTrue(app.staticTexts["Study"].exists)
        attachScreenshot("Active Study after tab return")
        app.buttons["punchButton"].tap()
        waitForPunchLabel("Punch in")

        selectTab(0)
        app.buttons["dayGoalCard"].tap()
        let rows = app.buttons.matching(identifier: "sessionRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 2)
        let labels = rows.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.contains { $0.contains("Work") })
        XCTAssertTrue(labels.contains { $0.contains("Study") })
        XCTAssertFalse(labels.contains { $0.contains("Now") }, "Punch-out must close the session.")
        attachScreenshot("Recorded workloads in day history")
    }

    func testManualSessionRecordsSelectedWorkload() {
        app.buttons["dayGoalCard"].tap()
        let add = app.buttons["addManualSession"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        XCTAssertTrue(app.navigationBars["New Session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sessionStart"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["sessionEnd"].exists)
        XCTAssertFalse(app.buttons["saveSession"].isEnabled)
        let personal = app.buttons["editorWorkload-Personal"]
        scrollUntilHittable(personal)
        personal.tap()
        let ended = app.switches["sessionEndedToggle"]
        scrollUntilHittable(ended, direction: .down)
        XCTAssertEqual(ended.value as? String, "1")
        // The accessibility frame includes the label. Tap the switch at the trailing edge.
        ended.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let switchedOff = expectation(for: NSPredicate(format: "value == %@", "0"), evaluatedWith: ended)
        XCTAssertEqual(XCTWaiter.wait(for: [switchedOff], timeout: 5), .completed, app.debugDescription)
        XCTAssertTrue(app.buttons["saveSession"].isEnabled)
        app.buttons["saveSession"].tap()

        let row = app.buttons.matching(identifier: "sessionRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Personal"))
        XCTAssertTrue(row.label.contains("iPhone"))
        XCTAssertTrue(row.label.contains("Now"))
        XCTAssertEqual(app.buttons.matching(identifier: "sessionRow").count, 1)
        attachScreenshot("Manual Personal session")
        app.buttons["Done"].firstMatch.tap()
        openTrack()
        waitForPunchLabel("Punch out")
        app.buttons["punchButton"].tap()
        waitForPunchLabel("Punch in")
    }

    func testNewWorkloadAppearsInPunchInChoices() {
        app.buttons["settingsButton"].tap()
        let workloads = app.buttons["workloadsSettings"]
        scrollUntilHittable(workloads)
        workloads.tap()
        app.buttons["addWorkload"].tap()

        let name = app.textFields["workloadNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Research")
        app.buttons["workloadColor-F39538"].tap()
        app.buttons["saveWorkload"].tap()

        let settingsBack = app.navigationBars.buttons["Settings"].firstMatch
        if settingsBack.exists { settingsBack.tap() }
        let done = app.buttons["settingsDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        openTrack()
        app.buttons["punchButton"].tap()
        let research = app.buttons["punchWorkload-Research"]
        XCTAssertTrue(research.waitForExistence(timeout: 5))
        attachScreenshot("Custom workload punch button")
        research.tap()
        waitForPunchLabel("Punch out")
        XCTAssertTrue(app.staticTexts["Research"].exists)
    }

    func testCustomWhiteAndBlackWorkloadsRemainUsable() {
        app.buttons["settingsButton"].tap()
        let workloads = app.buttons["workloadsSettings"]
        scrollUntilHittable(workloads)
        workloads.tap()
        for (name, hex) in [("White", "FFFFFF"), ("Black", "000000")] {
            app.buttons["addWorkload"].tap()
            let field = app.textFields["workloadNameField"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(name)
            setCustomWorkloadColor(hex)
            attachScreenshot("Custom \(name) workload preview")
            app.buttons["saveWorkload"].tap()
            XCTAssertTrue(app.buttons["workloadRow-\(name)"].waitForExistence(timeout: 5))
        }
        app.navigationBars.buttons["Settings"].firstMatch.tap()
        app.buttons["settingsDone"].tap()

        openTrack()
        app.buttons["punchButton"].tap()
        for name in ["White", "Black"] {
            XCTAssertTrue(app.buttons["punchWorkload-\(name)"].waitForExistence(timeout: 5))
        }
        attachScreenshot("Custom white and black punch buttons light")
        app.buttons["punchWorkload-White"].tap()
        waitForPunchLabel("Punch out")
        XCTAssertTrue(app.staticTexts["White"].exists)
        attachScreenshot("Custom White active light")
        app.buttons["punchButton"].tap()
        waitForPunchLabel("Punch in")
        selectTab(0)
        app.buttons["dayGoalCard"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "sessionRow").firstMatch.waitForExistence(timeout: 5))
        attachScreenshot("Custom White day timeline light")
        app.buttons["Done"].firstMatch.tap()
        openTrack()
        startSession(workload: "Black")
        XCTAssertTrue(app.staticTexts["Black"].exists)
        attachScreenshot("Custom Black active light")
        app.buttons["punchButton"].tap()
        waitForPunchLabel("Punch in")
        inspectCustomWorkloadHistory(appearance: "light", sessionCount: 2)

        app.terminate()
        app.launchArguments = ["--ui-testing", "--preserve-data", "--demo-dark"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        openTrack()
        for name in ["Black", "White"] {
            startSession(workload: name)
            XCTAssertTrue(app.staticTexts[name].exists)
            attachScreenshot("Custom \(name) active dark")
            app.buttons["punchButton"].tap()
            waitForPunchLabel("Punch in")
        }
        inspectCustomWorkloadHistory(appearance: "dark", sessionCount: 4)
    }

    func testCalendarUsesEqualSquareColumns() {
        let first = app.buttons["day-1"]
        let second = app.buttons["day-2"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.frame.width, second.frame.width, accuracy: 1)
        XCTAssertEqual(first.frame.width, first.frame.height, accuracy: 1)
        XCTAssertGreaterThan(first.frame.width, 30)
        attachScreenshot("Calendar layout")
        let title = app.staticTexts["monthTitle"].label
        app.buttons["Previous month"].tap()
        XCTAssertNotEqual(app.staticTexts["monthTitle"].label, title)
        app.buttons["Next month"].tap()
        XCTAssertEqual(app.staticTexts["monthTitle"].label, title)
    }

    func testSessionPersistsAfterRelaunch() {
        openTrack()
        startSession(workload: "Personal")
        app.buttons["punchButton"].tap()
        waitForPunchLabel("Punch in")
        app.terminate()
        app.launchArguments = ["--ui-testing", "--preserve-data"]
        app.launch()
        XCTAssertTrue(app.buttons["dayGoalCard"].waitForExistence(timeout: 10))
        app.buttons["dayGoalCard"].tap()
        let row = app.buttons.matching(identifier: "sessionRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Personal"))
    }

    func testDarkOverviewAndCSVExport() {
        app.terminate()
        app.launchArguments = ["--ui-testing", "--demo-data", "--demo-dark"]
        app.launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
        attachScreenshot("Dark calendar overview")
        app.buttons["settingsButton"].tap()
        let export = app.buttons["exportCSV"]
        scrollUntilHittable(export)
        export.tap()
        let close = app.buttons["Close"].firstMatch
        let activities = app.descendants(matching: .any)["ActivityListView"]
        XCTAssertTrue(close.waitForExistence(timeout: 5) || activities.exists, app.debugDescription)
        attachScreenshot("Native CSV share sheet")
        if close.isHittable { close.tap() }
    }

    func testAllFiveStatisticsRanges() {
        selectTab(1)
        let ranges = app.segmentedControls["statisticsRange"]
        XCTAssertTrue(ranges.waitForExistence(timeout: 5))
        let expected = [
            ("D", "Last 24 Hours"),
            ("W", "Last 7 Days"),
            ("M", "Last 30 Days"),
            ("6M", "Last 6 Months"),
            ("Y", "Last 12 Months")
        ]
        for (label, heading) in expected {
            let button = ranges.buttons[label]
            XCTAssertTrue(button.isHittable)
            button.tap()
            XCTAssertTrue(button.isSelected)
            XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 5))
            attachScreenshot("Statistics \(label)")
        }
    }

    func testFocusModesChangeStatisticsCards() {
        selectTab(1)
        for (focus, title) in [("balance", "Balance Tracking"), ("momentum", "Progress Tracking"), ("observe", "Patterns")] {
            app.buttons["settingsButton"].firstMatch.tap()
            let choice = app.buttons["focus-\(focus)"]
            scrollUntilHittable(choice)
            choice.tap()
            attachScreenshot("Settings focus \(focus)")
            app.buttons["settingsDone"].tap()
            let heading = app.staticTexts[title]
            scrollUntilHittable(heading)
            XCTAssertTrue(heading.exists)
            attachScreenshot("Focus \(focus)")
        }
    }

    func testNativeTabsPreserveScreenState() {
        let originalMonth = app.staticTexts["monthTitle"].label
        app.buttons["Previous month"].tap()
        let previousMonth = app.staticTexts["monthTitle"].label
        XCTAssertNotEqual(originalMonth, previousMonth)

        selectTab(1)
        let monthRange = app.segmentedControls["statisticsRange"].buttons["M"]
        XCTAssertTrue(monthRange.waitForExistence(timeout: 5))
        monthRange.tap()
        XCTAssertTrue(monthRange.isSelected)

        selectTab(0)
        XCTAssertEqual(app.staticTexts["monthTitle"].label, previousMonth)
        selectTab(1)
        XCTAssertTrue(app.segmentedControls["statisticsRange"].buttons["M"].isSelected)

        openTrack()
        app.buttons["punchButton"].tap()
        XCTAssertTrue(app.buttons["punchWorkload-Study"].waitForExistence(timeout: 5))
        selectTab(0)
        openTrack()
        XCTAssertTrue(app.buttons["punchWorkload-Study"].exists)
        XCTAssertEqual(app.buttons["punchButton"].label, "Punch in")
        attachScreenshot("Native tabs preserve state")
    }

    func testWeekDetailsEmptyNavigationAndWorkedDays() {
        app.terminate()
        app.launchArguments = ["--ui-testing", "--reference-empty"]
        app.launch()
        XCTAssertTrue(app.buttons["weekGoalCard"].waitForExistence(timeout: 10))
        app.buttons["weekGoalCard"].tap()
        XCTAssertTrue(app.staticTexts["No Sessions This Week"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Week Total"].exists)
        XCTAssertTrue(app.staticTexts["Goal"].exists)
        XCTAssertTrue(app.staticTexts["21h 0m"].exists)
        XCTAssertTrue(app.staticTexts["21h 0m remaining"].exists)
        XCTAssertFalse(app.buttons["Next week"].isEnabled)
        let currentWeek = app.staticTexts["weekRangeTitle"].label
        attachScreenshot("Empty week summary")

        app.buttons["Previous week"].tap()
        XCTAssertNotEqual(app.staticTexts["weekRangeTitle"].label, currentWeek)
        XCTAssertTrue(app.buttons["Next week"].isEnabled)
        app.buttons["Next week"].tap()
        XCTAssertEqual(app.staticTexts["weekRangeTitle"].label, currentWeek)
        XCTAssertFalse(app.buttons["Next week"].isEnabled)

        app.terminate()
        app.launchArguments = ["--ui-testing", "--demo-data", "--demo-dark"]
        app.launch()
        XCTAssertTrue(app.buttons["weekGoalCard"].waitForExistence(timeout: 10))
        app.buttons["weekGoalCard"].tap()
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: Date())
        let week = calendar.dateInterval(of: .weekOfYear, for: today)!
        var expectedDays = (0..<7).compactMap { index -> Date? in
            guard let day = calendar.date(byAdding: .day, value: index, to: week.start),
                  day < today, !calendar.isDateInWeekend(day) else { return nil }
            return day
        }
        if expectedDays.isEmpty {
            app.buttons["Previous week"].tap()
            let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week.start)!
            expectedDays = (0..<5).map { calendar.date(byAdding: .day, value: $0, to: previous)! }
        }
        let rows = app.descendants(matching: .any).matching(identifier: "weekSessionRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(rows.count, expectedDays.count)
        XCTAssertEqual(app.buttons.matching(identifier: "weekSessionRow").count, 0)
        XCTAssertEqual(app.buttons.matching(identifier: "sessionRow").count, 0)
        XCTAssertFalse(app.staticTexts["Saturday"].exists)
        XCTAssertFalse(app.staticTexts["Sunday"].exists)
        for day in expectedDays {
            XCTAssertTrue(app.staticTexts[day.formatted(.dateTime.weekday(.wide))].exists)
        }
        for row in rows.allElementsBoundByIndex {
            XCTAssertNotEqual(row.elementType, .button)
            XCTAssertTrue(row.label.contains("iPhone") || row.label.contains("Siri"))
            XCTAssertTrue(row.label.contains("–"))
        }
        attachScreenshot("Worked days in read-only week")
        rows.firstMatch.tap()
        XCTAssertFalse(app.navigationBars["Edit Session"].exists)
    }

    func testExistingSessionDiscardChangesAndDelete() {
        openTrack()
        startSession(workload: "Study")
        app.buttons["punchButton"].tap()
        waitForPunchLabel("Punch in")
        selectTab(0)
        app.buttons["dayGoalCard"].tap()
        let rows = app.buttons.matching(identifier: "sessionRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(rows.firstMatch.label.contains("Study"))
        rows.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit Session"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveSession"].isEnabled)
        attachScreenshot("Unchanged Study session editor")

        let personal = app.buttons["editorWorkload-Personal"]
        scrollUntilHittable(personal)
        personal.tap()
        XCTAssertTrue(app.buttons["saveSession"].isEnabled)
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(rows.firstMatch.label.contains("Study"))
        XCTAssertFalse(rows.firstMatch.label.contains("Personal"))

        rows.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit Session"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveSession"].isEnabled)
        let delete = app.buttons["deleteSession"]
        scrollUntilHittable(delete)
        delete.tap()
        let sheetDelete = app.sheets.buttons["Delete Session"].firstMatch
        if sheetDelete.waitForExistence(timeout: 3) {
            attachScreenshot("Delete session confirmation")
            sheetDelete.tap()
        } else {
            let alertDelete = app.alerts.buttons["Delete Session"].firstMatch
            XCTAssertTrue(alertDelete.waitForExistence(timeout: 3), app.debugDescription)
            attachScreenshot("Delete session confirmation")
            alertDelete.tap()
        }
        XCTAssertTrue(app.staticTexts["No Sessions"].waitForExistence(timeout: 5))
        XCTAssertEqual(rows.count, 0)
        XCTAssertFalse(app.buttons["deleteAllSessions"].isEnabled)
        attachScreenshot("Day after deleting the only session")
    }

    func testStatisticsEmptyAnalysisAndSummary() {
        app.terminate()
        app.launchArguments = ["--ui-testing", "--reference-empty"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        selectTab(1)
        let ranges = app.segmentedControls["statisticsRange"]
        XCTAssertTrue(ranges.waitForExistence(timeout: 5))
        XCTAssertEqual(ranges.buttons.count, 5)
        for (label, heading) in [
            ("D", "Last 24 Hours"), ("W", "Last 7 Days"), ("M", "Last 30 Days"),
            ("6M", "Last 6 Months"), ("Y", "Last 12 Months")
        ] {
            let button = ranges.buttons[label]
            XCTAssertTrue(button.isHittable)
            button.tap()
            XCTAssertTrue(button.isSelected)
            XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 5))
        }
        ranges.buttons["D"].tap()
        XCTAssertTrue(app.staticTexts["Last 24 Hours"].waitForExistence(timeout: 5))
        attachScreenshot("Empty Day statistics chart")

        let analysis = app.staticTexts["No sessions to analyze"]
        scrollUntilHittable(analysis)
        XCTAssertTrue(analysis.exists)
        let averages = app.staticTexts["No sessions to calculate averages"]
        scrollUntilHittable(averages)
        XCTAssertTrue(averages.exists)
        XCTAssertTrue(app.staticTexts["Outliers (Day)"].exists)
        XCTAssertTrue(app.staticTexts["Summary (Day)"].exists)
        XCTAssertGreaterThanOrEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "No sessions in selected range")).count, 2)
        XCTAssertFalse(app.staticTexts["Average"].exists)
        XCTAssertFalse(app.staticTexts["Periods Worked"].exists)
        // SwiftUI can expose either the image identifier or its card identifier.
        let trackingIcon = app.images.matching(NSPredicate(format: "identifier IN %@", ["statisticsEmptyTrackingIcon", "statisticsProgress", "lightbulb"])).firstMatch
        let outliersIcon = app.images.matching(NSPredicate(format: "identifier IN %@", ["statisticsEmptyOutliersIcon", "statisticsOutliers", "chart.line.uptrend.xyaxis"])).firstMatch
        XCTAssertTrue(trackingIcon.exists, app.debugDescription)
        XCTAssertTrue(outliersIcon.exists, app.debugDescription)
        attachScreenshot("Empty Day analysis outliers and summary")
        let accessibility = XCTAttachment(string: app.debugDescription)
        accessibility.name = "Empty Day statistics accessibility"
        accessibility.lifetime = .keepAlways
        add(accessibility)

        // The reference fixture starts in Momentum. Check the other two focus modes.
        for (focus, heading) in [("balance", "Balance Tracking"), ("observe", "Patterns")] {
            app.buttons["settingsButton"].firstMatch.tap()
            let choice = app.buttons["focus-\(focus)"]
            scrollUntilHittable(choice)
            choice.tap()
            app.buttons["settingsDone"].tap()
            XCTAssertTrue(app.staticTexts["Summary (Day)"].exists)
            XCTAssertTrue(app.staticTexts[heading].exists)
            XCTAssertTrue(analysis.exists)
            XCTAssertTrue(averages.exists)
            XCTAssertFalse(app.staticTexts["Average"].exists)
            XCTAssertFalse(app.staticTexts["Periods Worked"].exists)
            scrollUntilHittable(averages)
            attachScreenshot("Empty Day statistics focus \(focus)")
        }
    }

    func testReferenceAppearance() {
        app.terminate()
        app.launchArguments = ["--ui-testing", "--reference-empty"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["dayGoalCard"].waitForExistence(timeout: 5))
        attachScreenshot("Reference Home")

        app.buttons["settingsButton"].firstMatch.tap()
        XCTAssertTrue(app.buttons["settingsDone"].waitForExistence(timeout: 5))
        attachScreenshot("Reference Settings top")
        let daily = app.sliders["dailyGoalSlider"]
        scrollUntilHittable(daily)
        attachScreenshot("Reference Settings goals")
        let accessibility = XCTAttachment(string: app.debugDescription)
        accessibility.name = "Reference Settings accessibility"
        accessibility.lifetime = .keepAlways
        add(accessibility)
        app.buttons["settingsDone"].tap()

        openTrack()
        XCTAssertEqual(app.buttons["punchButton"].label, "Punch in")
        attachScreenshot("Reference Idle Track")
        selectTab(1)
        XCTAssertTrue(app.segmentedControls["statisticsRange"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["statisticsRange"].buttons["W"].isSelected)
        attachScreenshot("Reference Statistics W")

        openTrack()
        let idleFrame = app.buttons["punchButton"].frame
        startSession(workload: "Study")
        assertActiveTrackingLayout(idleFrame: idleFrame)
        XCTAssertTrue(app.staticTexts["Study"].exists)
        attachScreenshot("Reference Active Track")
        app.buttons["punchButton"].tap()
        waitForPunchLabel("Punch in")
    }

    private enum ScrollDirection { case up, down }

    private func scrollUntilHittable(_ element: XCUIElement, direction: ScrollDirection = .up, maxSwipes: Int = 5,
                                     file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            if direction == .up { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.exists && element.isHittable, "The control must be visible and tappable.\n\(app.debugDescription)", file: file, line: line)
    }

    private func selectTab(_ index: Int) {
        let tab = app.tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
    }

    private func openTrack() {
        selectTab(2)
        XCTAssertTrue(app.buttons["punchButton"].waitForExistence(timeout: 5))
    }

    private func startSession(workload: String) {
        app.buttons["punchButton"].tap()
        let choice = app.buttons["punchWorkload-\(workload)"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        waitForPunchLabel("Punch out")
        XCTAssertFalse(choice.exists)
    }

    private func setCustomWorkloadColor(_ hex: String, file: StaticString = #filePath, line: UInt = #line) {
        let picker = app.descendants(matching: .any)["workloadCustomColor"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), file: file, line: line)
        picker.tap()
        let sliders = app.buttons["Sliders"].firstMatch
        XCTAssertTrue(sliders.waitForExistence(timeout: 5), app.debugDescription, file: file, line: line)
        sliders.tap()
        // The native picker exposes its hex field by value, with no label or identifier.
        let field = app.textFields.matching(NSPredicate(format: "value MATCHES %@", "[0-9A-Fa-f]{6}")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription, file: file, line: line)
        field.tap()
        let previous = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + hex)
        XCTAssertEqual((field.value as? String)?.uppercased(), hex, file: file, line: line)
        let close = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "close")).firstMatch
        XCTAssertTrue(close.exists, app.debugDescription, file: file, line: line)
        close.tap()
        XCTAssertTrue(app.buttons["saveWorkload"].waitForExistence(timeout: 5), file: file, line: line)
    }

    private func inspectCustomWorkloadHistory(appearance: String, sessionCount: Int) {
        selectTab(0)
        app.buttons["dayGoalCard"].tap()
        let dayRows = app.buttons.matching(identifier: "sessionRow")
        XCTAssertTrue(dayRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(dayRows.count, sessionCount)
        for name in ["White", "Black"] {
            XCTAssertTrue(dayRows.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch.exists)
        }
        attachScreenshot("Custom white and black day history \(appearance)")

        dayRows.matching(NSPredicate(format: "label CONTAINS %@", "White")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit Session"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["saveSession"].isEnabled)
        let black = app.buttons["editorWorkload-Black"]
        scrollUntilHittable(black)
        black.tap()
        XCTAssertTrue(app.buttons["saveSession"].isEnabled)
        let white = app.buttons["editorWorkload-White"]
        scrollUntilHittable(white, direction: .down)
        white.tap()
        XCTAssertFalse(app.buttons["saveSession"].isEnabled)
        XCTAssertTrue(black.isHittable)
        attachScreenshot("Custom white and black editor choices \(appearance)")
        app.buttons["Back"].firstMatch.tap()
        XCTAssertTrue(dayRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(dayRows.count, sessionCount)
        app.buttons["Done"].firstMatch.tap()

        app.buttons["weekGoalCard"].tap()
        let weekRows = app.descendants(matching: .any).matching(identifier: "weekSessionRow")
        XCTAssertTrue(weekRows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(weekRows.count, sessionCount)
        for name in ["White", "Black"] {
            XCTAssertTrue(weekRows.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch.exists)
        }
        attachScreenshot("Custom white and black week history \(appearance)")
        app.buttons["Done"].firstMatch.tap()
    }

    private func assertActiveTrackingLayout(idleFrame: CGRect) {
        let punch = app.buttons["punchButton"]
        XCTAssertEqual(punch.label, "Punch out")
        XCTAssertEqual(punch.frame.midX, idleFrame.midX, accuracy: 0.5)
        XCTAssertEqual(punch.frame.midY, idleFrame.midY, accuracy: 0.5)
        if abs(app.frame.width - 430) < 0.5 && abs(app.frame.height - 932) < 0.5 {
            // Allow one point for native-shell and pixel rounding on the matched iOS 26 canvas.
            XCTAssertEqual(punch.frame.midY, 486.7, accuracy: 1)
        }
        let elapsed = punch.value as? String ?? ""
        XCTAssertNotNil(elapsed.range(of: "^\\d{2}:\\d{2}$", options: .regularExpression), elapsed)
        for title in ["Today", "This Week", "This Month"] {
            XCTAssertFalse(app.staticTexts[title].isHittable)
        }
        XCTAssertFalse(app.scrollViews.allElementsBoundByIndex.contains { $0.isHittable })
        let tab = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertEqual(tab.label, "IN")
        assertNativeLineIcon(tab)
    }

    private func assertNativeLineIcon(_ tab: XCUIElement) {
        guard let image = tab.screenshot().image.cgImage else { return XCTFail("The tab screenshot must contain an image.") }
        let width = image.width, height = image.height
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
        defer { bytes.deallocate() }
        guard let context = CGContext(data: bytes, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
            return XCTFail("The tab image must support pixel inspection.")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let mask = (0..<(width * height)).map { pixel in
            let offset = pixel * 4
            let red = Int(bytes[offset]), green = Int(bytes[offset + 1]), blue = Int(bytes[offset + 2])
            return max(red, max(green, blue)) - min(red, min(green, blue)) > 50
        }
        var visited = Array(repeating: false, count: mask.count)
        var tallest = (width: 0, height: 0)
        // Separate the native saturated icon from its shorter IN text label.
        for pixel in mask.indices where mask[pixel] && !visited[pixel] {
            var queue = [pixel], head = 0
            var left = pixel % width, right = left, top = pixel / width, bottom = top
            visited[pixel] = true
            while head < queue.count {
                let next = queue[head]; head += 1
                let x = next % width, y = next / width
                left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y)
                for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] where nx >= 0 && nx < width && ny >= 0 && ny < height {
                    let neighbor = ny * width + nx
                    if mask[neighbor] && !visited[neighbor] { visited[neighbor] = true; queue.append(neighbor) }
                }
            }
            if bottom - top + 1 > tallest.height { tallest = (right - left + 1, bottom - top + 1) }
        }
        XCTAssertGreaterThan(tallest.height, 10)
        XCTAssertGreaterThan(Double(tallest.height), Double(tallest.width) * 2.5, "The active tab icon must be a vertical line.")
    }

    private func waitForPunchLabel(_ label: String) {
        let expected = NSPredicate(format: "label == %@", label)
        let result = XCTWaiter.wait(for: [expectation(for: expected, evaluatedWith: app.buttons["punchButton"])], timeout: 5)
        XCTAssertEqual(result, .completed)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
