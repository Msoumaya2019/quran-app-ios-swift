import XCTest

final class ReaderUITests: XCTestCase {
    func testTwentyPagesBothSourcesOfflineFixtures() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-authenticated", "--ui-test-reader-fixtures"]
        app.launch()
        app.tabBars.buttons["Coran"].tap()
        XCTAssertTrue(app.images["quran.page.1"].waitForExistence(timeout: 10))
        turnTwentyPages(app)
        attach(app, name: "Coran de Médine — lecteur natif")
        app.buttons["quran.action.Plus"].tap()
        app.buttons["Coran 1441"].tap()
        XCTAssertTrue(app.buttons["quran.action.Plus"].waitForExistence(timeout: 10))
        for number in stride(from: 20, through: 1, by: -1) {
            swipe(app, forward: false)
            XCTAssertTrue(app.images["quran.page.\(number)"].waitForExistence(timeout: 5))
        }
        turnTwentyPages(app)
        app.buttons["quran.action.Marque-page"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Coran 1441 — lecteur natif"; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func turnTwentyPages(_ app: XCUIApplication) {
        for page in 2...21 {
            swipe(app, forward: true)
            let image = app.images["quran.page.\(page)"]
            XCTAssertTrue(image.waitForExistence(timeout: 5))
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "ready"), object: image)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        }
    }
    private func attach(_ app: XCUIApplication, name: String) { let value = XCTAttachment(screenshot: app.screenshot()); value.name = name; value.lifetime = .keepAlways; add(value) }
    private func swipe(_ app: XCUIApplication, forward: Bool) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.25 : 0.8, dy: 0.4))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.8 : 0.25, dy: 0.4))
        start.press(forDuration: 0.02, thenDragTo: end)
    }
}
