import XCTest
import ImageIO
import CoreGraphics

@MainActor
final class PunchinoWatchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCrownWorkloadSelectionPunchOutAndPersistentHistory() throws {
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
        XCTAssertTrue(app.staticTexts["watchActiveWorkload"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["watchActiveWorkload"].label.contains("Study"))
        XCTAssertEqual(app.buttons["watchPunchButton"].label, "Punch out")
        attach(app, name: "Watch Study active")

        app.buttons["watchPunchButton"].tap()
        XCTAssertEqual(app.buttons["watchPunchButton"].label, "Punch in. Choose workload.")
        app.terminate()
        app.launchArguments = ["--ui-testing", "--preserve-data"]
        app.launch()
        XCTAssertTrue(app.buttons["watchPunchButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["watchPunchButton"].label, "Punch in. Choose workload.")

        app.swipeLeft()
        let today = app.buttons["watchPeriod-Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 5), app.debugDescription)
        print("Watch totals card frames: \(today.frame), \(app.buttons["watchPeriod-This Week"].frame), \(app.buttons["watchPeriod-This Month"].frame)")
        attach(app, name: "Watch Totals")
        today.tap()
        let historyWorkload = app.staticTexts["watchHistoryWorkload"].firstMatch
        XCTAssertTrue(historyWorkload.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(historyWorkload.label, "Study")
        attach(app, name: "Watch history after relaunch")
    }

    func testNativeSmartStackDiscovery() throws {
        guard ProcessInfo.processInfo.environment["SIMULATOR_UDID"] == "F0B67AC3-174C-4ED3-8F0C-B882CF29B587" else {
            throw XCTSkip("Native widget capture requires the approved disposable Watch simulator.")
        }
        let app = XCUIApplication()
        let shell = XCUIApplication(bundleIdentifier: "com.apple.Carousel")
        app.launch()
        let punch = app.buttons["watchPunchButton"]
        XCTAssertTrue(punch.waitForExistence(timeout: 10))
        if punch.label == "Punch out" { punch.tap() }
        punch.tap()
        let wheel = app.descendants(matching: .any)["watchWorkloadPicker"]
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        wheel.tap()
        for attempt in 0..<16 {
            let value = wheel.value as? String ?? ""
            print("Native black workload selection: \(value)")
            if value.contains("Black") { break }
            XCUIDevice.shared.rotateDigitalCrown(delta: value.contains("White") ? -0.08 : [0.08, 0.10, 0.12][attempt % 3], velocity: 0.5)
        }
        XCTAssertTrue((wheel.value as? String)?.contains("Black") == true, app.debugDescription)
        attach(app, name: "Normal Watch selects predefined Black workload")
        app.buttons["watchConfirmPunchIn"].tap()
        XCTAssertTrue(app.staticTexts["watchActiveWorkload"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["watchActiveWorkload"].label.contains("Black"))
        attach(app, name: "Normal Watch Black source session")
        showNativeStack(shell)
        attachNativeState(shell, name: "Native Black workload widget with contrast outline")
        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        shell.coordinate(withNormalizedOffset: CGVector(dx: 0.235, dy: 0.667)).tap()
        Thread.sleep(forTimeInterval: 5)
        attachNativeState(shell, name: "Native Black widget stopped with source app closed")
        XCTAssertEqual(app.state, .notRunning)
    }

    private func showNativeStack(_ shell: XCUIApplication) {
        XCUIDevice.shared.press(.home)
        let launcher = shell.otherElements["CSLLauncherView"]
        if launcher.waitForExistence(timeout: 1.5) {
            XCUIDevice.shared.press(.home)
            XCTAssertTrue(launcher.waitForNonExistence(timeout: 5))
        }
        Thread.sleep(forTimeInterval: 0.5)
        let imageSource = CGImageSourceCreateWithData(XCUIScreen.main.screenshot().pngRepresentation as CFData, nil)!
        let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)!
        var bytes = [UInt8](repeating: 0, count: 32 * 32 * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 32 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        let yellowPixels = stride(from: 0, to: bytes.count, by: 4).filter { bytes[$0] > 150 && bytes[$0 + 1] > 150 && bytes[$0 + 2] < 100 }.count
        print("Observed Numerals Duo face yellow pixels: \(yellowPixels)")
        if yellowPixels > 20 { shell.swipeUp() }
        Thread.sleep(forTimeInterval: 3)
    }

    private func attachNativeState(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + " accessibility"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        print(name + "\n" + app.debugDescription)
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
