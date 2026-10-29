import XCTest

final class ExpoUpdatesUITests: XCTestCase {
    func testSoloQuestionCorrectionAndResultWithoutExtraTab() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-authenticated", "--ui-test-quiz-solo"]
        app.launch()
        XCTAssertTrue(app.buttons["home.Quiz"].waitForExistence(timeout: 10)); app.buttons["home.Quiz"].tap()
        XCTAssertEqual(app.tabBars.buttons.count, 5)
        let solo = app.buttons["quiz.solo"]
        XCTAssertTrue(solo.waitForExistence(timeout: 5)); solo.tap()
        XCTAssertTrue(app.buttons["quiz.solo.start"].waitForExistence(timeout: 5)); app.buttons["quiz.solo.start"].tap()
        XCTAssertTrue(app.buttons["quiz.answer.A"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Correction technique enregistrée."].exists)
        app.buttons["quiz.answer.A"].tap()
        XCTAssertTrue(app.staticTexts["Correction technique enregistrée."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["quiz.answer.B"].isEnabled)
        let next = app.buttons["quiz.solo.next"]
        for _ in 0..<3 { if next.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(next.waitForExistence(timeout: 5)); next.tap()
        XCTAssertTrue(app.staticTexts["Quiz terminé"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 / 1"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Quiz solo-resultat"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
