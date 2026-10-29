import XCTest

final class RoqyaControlsUITests: XCTestCase {
    func testTimerPlaybackAndReturningFromBackground() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated", "--ui-test-roqya"]; app.launch()
        let open = app.buttons["home.roqya"]
        for _ in 0..<4 { if open.exists && open.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
        let play = app.buttons["roqya.play.00000000-0000-0000-0000-000000000006"]
        XCTAssertTrue(play.waitForExistence(timeout: 5)); play.tap()
        let timer = app.buttons["roqya.timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 8)); timer.tap()
        app.buttons["5 minutes"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Arrêt dans")).firstMatch.waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        XCTAssertTrue(play.label.contains("Pause"))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Roqya minuterie et controles natifs"; attachment.lifetime = .keepAlways; add(attachment)
        app.navigationBars["Roqya"].buttons.firstMatch.tap()
        XCTAssertTrue(open.waitForExistence(timeout: 5)); open.tap()
        XCTAssertTrue(play.waitForExistence(timeout: 5)); XCTAssertTrue(play.label.contains("Écouter"))
        XCTAssertFalse(timer.exists)
    }
}
