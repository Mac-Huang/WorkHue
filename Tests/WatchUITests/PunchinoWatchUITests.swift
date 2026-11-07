import XCTest

@MainActor
final class PunchinoWatchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testWatchReferenceAppearance() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reference-appearance"]
        app.launch()

        let punch = app.buttons["watchPunchButton"]
        XCTAssertTrue(punch.waitForExistence(timeout: 10))
        XCTAssertEqual(punch.label, "Punch in. Choose workload.")
        let todayTotal = app.descendants(matching: .any)["watchTodayTotal"]
        XCTAssertTrue(todayTotal.exists, app.debugDescription)
        print("Watch reference Track frames: punch=\(punch.frame), today=\(todayTotal.frame)")
        print("Watch reference Track environment: \(String(describing: punch.value))")
        print("Watch reference Today environment: \(String(describing: todayTotal.value))")
        attach(app, name: "Watch reference bold Track")

        app.swipeLeft()
        let today = app.descendants(matching: .any)["watchPeriod-Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 5), app.debugDescription)
        let week = app.descendants(matching: .any)["watchPeriod-This Week"]
        let month = app.descendants(matching: .any)["watchPeriod-This Month"]
        XCTAssertTrue(week.exists)
        XCTAssertTrue(month.exists)
        print("Watch reference totals card frames: \(today.frame), \(week.frame), \(month.frame)")
        print("Watch reference Totals environment: \(String(describing: today.value))")
        today.tap()
        XCTAssertTrue(today.isHittable)
        XCTAssertTrue(week.isHittable)
        XCTAssertTrue(month.isHittable)
        XCTAssertFalse(app.buttons["watchSettingsButton"].exists)
        attach(app, name: "Watch reference bold Totals")
    }

    func testWatchReferenceActiveAppearance() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reference-appearance"]
        app.launch()
        let punch = app.buttons["watchPunchButton"]
        XCTAssertTrue(punch.waitForExistence(timeout: 10))
        XCTAssertEqual(punch.label, "Punch in. Choose workload.")
        punch.tap()

        let wheel = app.descendants(matching: .any)["watchWorkloadPicker"]
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        wheel.tap()
        for attempt in 0..<12 {
            let value = wheel.value as? String ?? ""
            if value.contains("Study") { break }
            let amount = [0.10, 0.11, 0.12][attempt % 3]
            XCUIDevice.shared.rotateDigitalCrown(delta: value.contains("Personal") ? -amount : amount, velocity: 0.5)
        }
        XCTAssertTrue((wheel.value as? String)?.contains("Study") == true)
        app.buttons["watchConfirmPunchIn"].tap()
        let active = app.descendants(matching: .any)["watchActiveWorkload"]
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        XCTAssertTrue(active.label.contains("Study"))
        XCTAssertEqual(punch.label, "Punch out")
        print("Watch reference active frames: punch=\(punch.frame), started=\(active.frame)")
        print("Watch reference active environment: \(String(describing: punch.value))")
        XCTAssertTrue((punch.value as? String)?.contains("bold") == true)
        XCTAssertTrue((punch.value as? String)?.contains("timerInkOpacity=0.70") == true)
        attach(app, name: "Watch reference bold Study active")

        punch.tap()
        XCTAssertEqual(punch.label, "Punch in. Choose workload.")
        attach(app, name: "Watch reference idle after synthetic stop")
        app.swipeLeft()
        let today = app.descendants(matching: .any)["watchPeriod-Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        XCTAssertTrue(app.descendants(matching: .any)["watchPeriod-This Week"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["watchPeriod-This Month"].isHittable)
        attach(app, name: "Watch reference read-only Totals after synthetic stop")
    }

    func testCrownWorkloadSelectionPunchOutAndPersistentTotals() async throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let punch = app.buttons["watchPunchButton"]
        XCTAssertTrue(punch.waitForExistence(timeout: 10))
        XCTAssertEqual(punch.label, "Punch in. Choose workload.")
        attach(app, name: "Watch OUT")
        punch.tap()

        let wheel = app.descendants(matching: .any)["watchWorkloadPicker"]
        XCTAssertTrue(wheel.waitForExistence(timeout: 5), app.debugDescription)
        wheel.tap()
        for attempt in 0..<12 {
            let value = wheel.value as? String ?? ""
            print("Workload picker value: \(value)")
            if value.contains("Study") { break }
            let amount = [0.10, 0.11, 0.12][attempt % 3]
            XCUIDevice.shared.rotateDigitalCrown(delta: value.contains("Personal") ? -amount : amount, velocity: 0.5)
        }
        XCTAssertTrue((wheel.value as? String)?.contains("Study") == true, app.debugDescription)
        attach(app, name: "Watch workload wheel")

        app.buttons["watchConfirmPunchIn"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["watchActiveWorkload"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["watchActiveWorkload"].label.contains("Study"))
        XCTAssertEqual(app.buttons["watchPunchButton"].label, "Punch out")
        attach(app, name: "Watch Study active")

        print("Waiting 61 seconds for an observable isolated one-minute session.")
        try await Task.sleep(for: .seconds(61))

        app.buttons["watchPunchButton"].tap()
        XCTAssertEqual(app.buttons["watchPunchButton"].label, "Punch in. Choose workload.")
        app.terminate()
        app.launchArguments = ["--ui-testing", "--preserve-data"]
        app.launch()
        XCTAssertTrue(app.buttons["watchPunchButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["watchPunchButton"].label, "Punch in. Choose workload.")

        app.swipeLeft()
        let today = app.descendants(matching: .any)["watchPeriod-Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 5), app.debugDescription)
        for title in ["Today", "This Week", "This Month"] {
            let card = app.descendants(matching: .any)["watchPeriod-\(title)"]
            XCTAssertTrue(card.exists, app.debugDescription)
            XCTAssertTrue(card.label.contains("1m"), card.label)
        }
        attach(app, name: "Watch persisted one-minute totals after relaunch")
        today.tap()
        XCTAssertTrue(app.descendants(matching: .any)["watchPeriod-This Week"].isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["watchPeriod-This Month"].isHittable)
    }

    func testBlackAndWhiteWorkloadsRemainReadable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--color-extremes"]
        app.launch()
        let punch = app.buttons["watchPunchButton"]
        XCTAssertTrue(punch.waitForExistence(timeout: 10))
        punch.tap()
        let wheel = app.descendants(matching: .any)["watchWorkloadPicker"]
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        XCTAssertTrue((wheel.value as? String)?.contains("Black") == true)
        attach(app, name: "Watch Black workload wheel and confirmation")
        app.buttons["watchConfirmPunchIn"].tap()
        let active = app.descendants(matching: .any)["watchActiveWorkload"]
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        XCTAssertTrue(active.label.contains("Black"))
        attach(app, name: "Watch Black active light ink and outline")
        punch.tap()
        punch.tap()
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        wheel.tap()
        for attempt in 0..<10 {
            if (wheel.value as? String)?.contains("White") == true { break }
            XCUIDevice.shared.rotateDigitalCrown(delta: [0.08, 0.10, 0.12][attempt % 3], velocity: 0.5)
        }
        XCTAssertTrue((wheel.value as? String)?.contains("White") == true, app.debugDescription)
        attach(app, name: "Watch White workload wheel and confirmation")
        app.buttons["watchConfirmPunchIn"].tap()
        XCTAssertTrue(active.waitForExistence(timeout: 5))
        XCTAssertTrue(active.label.contains("White"))
        attach(app, name: "Watch White active dark ink")
        punch.tap()
        app.terminate()
        app.launchArguments = ["--ui-testing", "--color-extremes", "--preserve-data"]
        app.launch()
        XCTAssertTrue(punch.waitForExistence(timeout: 5))
        XCTAssertEqual(punch.label, "Punch in. Choose workload.")
        punch.tap()
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        XCTAssertTrue((wheel.value as? String)?.contains("Black") == true)
        wheel.tap()
        for attempt in 0..<10 {
            if (wheel.value as? String)?.contains("White") == true { break }
            XCUIDevice.shared.rotateDigitalCrown(delta: [0.08, 0.10, 0.12][attempt % 3], velocity: 0.5)
        }
        XCTAssertTrue((wheel.value as? String)?.contains("White") == true)
        attach(app, name: "Watch Black and White workload definitions after relaunch")
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
