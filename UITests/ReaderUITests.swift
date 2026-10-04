import XCTest

final class ReaderUITests: XCTestCase {
    func testRecordingCanBeSavedAndFoundOffline() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-authenticated", "--ui-test-reader-fixtures", "--ui-test-recording"]
        app.launch(); app.tabBars.buttons["Coran"].tap()
        app.buttons["quran.action.Enregistrer"].tap()
        XCTAssertTrue(app.buttons["recitation.start"].waitForExistence(timeout: 10))
        app.buttons["recitation.start"].tap()
        XCTAssertTrue(app.buttons["recitation.stop"].waitForExistence(timeout: 5))
        attach(app, name: "Récitation native — enregistrement")
        app.buttons["recitation.stop"].tap()
        app.buttons["recitation.save"].tap()
        XCTAssertTrue(app.buttons["quran.action.Plus"].waitForExistence(timeout: 5))
        app.buttons["quran.action.Plus"].tap()
        let library = app.buttons["recitations.open"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        library.tap()
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "recitation.item."))
        XCTAssertTrue(saved.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(saved.count, 1)
        attach(app, name: "Récitation native — sauvegarde hors ligne")
    }
    func testOfflineAudioTimelineAndReaderViewport() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-authenticated", "--ui-test-reader-fixtures", "--ui-test-audio"]
        app.launch(); app.tabBars.buttons["Coran"].tap()
        let image = app.images["quran.page.1"]
        XCTAssertTrue(image.waitForExistence(timeout: 10))
        let original = image.frame
        app.buttons["quran.action.Écouter"].tap()
        let slider = app.sliders["quran.audio.timeline"]
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: slider)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        app.buttons["quran.audio.toggle"].tap()
        slider.adjust(toNormalizedSliderPosition: 0.5)
        let elapsed = app.staticTexts["quran.audio.elapsed"]
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label MATCHES %@", "0:(2[89]|3[0-2])"), object: elapsed)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 5), .completed)
        XCTAssertEqual(image.frame.midX, original.midX, accuracy: 1)
        XCTAssertLessThan(image.frame.height, original.height)
        attach(app, name: "Audio natif — timeline hors ligne")
        app.buttons["quran.audio.close"].tap()
        XCTAssertEqual(image.frame.height, original.height, accuracy: 1)
        XCTAssertTrue(app.buttons["quran.action.Plus"].exists)
    }
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
