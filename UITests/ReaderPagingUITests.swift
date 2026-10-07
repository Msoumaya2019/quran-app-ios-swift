import XCTest

final class ReaderPagingUITests: XCTestCase {
    func testTwentyMedinaPagesAndBackKeepReaderAndRatio() { checkPaging(source: "traditional") }
    func testTwenty1441PagesAndBackKeepReaderAndRatio() { checkPaging(source: "coran_1441") }

    private func checkPaging(source: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-authenticated", "--ui-test-reader-fixtures"]
        app.launch()
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 10))
        app.buttons["home.continue"].tap()
        XCTAssertTrue(app.images["quran.page.1"].waitForExistence(timeout: 10))
        if source != "traditional" {
            app.buttons["quran.action.Plus"].tap()
            let choice = app.buttons["quran.source." + source]
            for _ in 0..<5 { if choice.isHittable { break }; app.swipeUp() }
            XCTAssertTrue(choice.waitForExistence(timeout: 5)); choice.tap()
            XCTAssertTrue(app.navigationBars["Coran 1441"].waitForExistence(timeout: 10))
        }
        let first = app.images["quran.page.1"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let ready = NSPredicate { _, _ in first.isHittable && first.value as? String == "ready" }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 10), .completed)
        let original = first.frame
        for page in 2...21 { turn(app, to: page, forward: true) }
        for page in stride(from: 20, through: 16, by: -1) { turn(app, to: page, forward: false) }
        for page in 17...21 { turn(app, to: page, forward: true) }
        let final = app.images["quran.page.21"].frame
        XCTAssertEqual(final.width, original.width, accuracy: 2)
        XCTAssertEqual(final.height, original.height, accuracy: 2)
        XCTAssertEqual(final.midX, original.midX, accuracy: 2)
        XCTAssertEqual(final.midY, original.midY, accuracy: 2)
        XCTAssertTrue(app.buttons["quran.action.Plus"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "20 pages et retour — " + source; screenshot.lifetime = .keepAlways; add(screenshot)
    }
    private func turn(_ app: XCUIApplication, to page: Int, forward: Bool) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.3 : 0.8, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.8 : 0.3, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        let image = app.images["quran.page.\(page)"]
        let visible = NSPredicate { _, _ in image.exists && image.isHittable && image.value as? String == "ready" }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: visible, object: nil)], timeout: 5), .completed, "Page \(page) must be visible after swipe")
        XCTAssertFalse(app.staticTexts["La page n’a pas pu être chargée. Réessaie depuis le menu Plus."].exists)
    }
}
