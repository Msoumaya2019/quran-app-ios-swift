import XCTest

final class StudyEditorUITests: XCTestCase {
    func testKnowledgeEditorSavesAndOffersRevisionHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-authenticated"]
        app.launch()
        let settings = app.buttons["settings.open"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10)); settings.tap()
        let edit = app.buttons["settings.study.edit"]
        for _ in 0..<8 { if edit.exists && edit.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); edit.tap()
        let history = app.buttons["Modifier mes révisions effectuées"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        let save = app.buttons["study.editor.save"]
        for _ in 0..<6 { if save.exists && save.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 5)); save.tap()
        let result = app.staticTexts["study.editor.result"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("Modifications enregistrées"))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Correction des connaissances enregistrée"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
