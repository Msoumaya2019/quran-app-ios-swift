import XCTest

final class StudyEditorUITests: XCTestCase {
    func testJuzSelectionIsSharedWithHizbAndSurahChecklists() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated"]; app.launch()
        app.buttons["settings.open"].tap()
        let edit = app.buttons["settings.study.edit"]
        for _ in 0..<8 { if edit.exists && edit.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); edit.tap()
        let juz = app.buttons["knowledge.juz.1"]
        XCTAssertTrue(juz.waitForExistence(timeout: 5)); juz.tap()
        XCTAssertEqual(juz.value as? String, "Connu")
        app.buttons["Hizb"].tap()
        let hizb = app.buttons["knowledge.hizb.1"]
        XCTAssertTrue(hizb.waitForExistence(timeout: 5)); XCTAssertEqual(hizb.value as? String, "Connu")
        app.buttons["Sourates"].tap()
        let surah = app.buttons["knowledge.surah.1"]
        XCTAssertTrue(surah.waitForExistence(timeout: 5)); XCTAssertEqual(surah.value as? String, "Connu")
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Sélection rapide partagée Juz Hizb Sourates"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testKnowledgeEditorSavesAndOffersRevisionHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-authenticated"]
        app.launch()
        let settings = app.buttons["settings.open"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10)); settings.tap()
        let edit = app.buttons["settings.study.edit"]
        for _ in 0..<8 { if edit.exists && edit.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(edit.waitForExistence(timeout: 5)); edit.tap()
        let partial = app.buttons["knowledge.partial.open"]
        XCTAssertTrue(partial.waitForExistence(timeout: 5)); partial.tap()
        let history = app.buttons["Modifier mes révisions effectuées"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        let save = app.buttons["study.editor.save"]
        for _ in 0..<6 { if save.exists && save.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 5)); save.tap()
        let result = app.staticTexts["study.editor.result"]
        // Form rows are lazy: the acknowledgement is below the save row on this device.
        for _ in 0..<3 { if result.exists && result.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        XCTAssertTrue(result.label.contains("Modifications enregistrées"))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "Correction des connaissances enregistrée"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
