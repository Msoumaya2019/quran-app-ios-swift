import XCTest

final class PhaseOneUITests: XCTestCase {
    func testProgramCanBeEditedFromSettingsOffline() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated", "--ui-test-program-edit"]; app.launch()
        app.buttons["settings.open"].tap()
        let editor = app.buttons["settings.program.open"]
        guard editor.waitForExistence(timeout: 10) else { XCTFail("Program settings unavailable"); return }
        editor.tap()
        let save = app.buttons["program.editor.save"]
        for _ in 0..<5 { if save.isHittable { break }; app.swipeUp() }
        guard save.isHittable else { XCTFail("Program save unavailable: \(app.debugDescription)"); return }
        save.tap()
        XCTAssertTrue(app.staticTexts["program.editor.result"].waitForExistence(timeout: 10))
        attach(app, name: "Réglages natifs — modification du programme hors ligne")
    }
    func testAuthenticationScreenAndDisabledEmptyLogin() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["auth.submit"].isEnabled)
        attach(app, name: "Authentification native")
    }
    func testCachedHomeNavigationSettingsAndNativeBack() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated"]; app.launch()
        XCTAssertTrue(app.staticTexts["home.name"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["home.name"].label, "Mohamed")
        attach(app, name: "Accueil natif")
        let tabs = app.tabBars
        tabs.buttons["Coran"].tap()
        XCTAssertTrue(app.buttons["quran.action.Plus"].waitForExistence(timeout: 5))
        app.buttons["quran.action.Accueil"].tap()
        for title in ["Programme", "Progrès", "Amis", "Accueil"] { tabs.buttons[title].tap(); XCTAssertTrue(tabs.buttons[title].isSelected) }
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 5))
        attach(app, name: "Réglages natifs")
        app.buttons["Fermer"].tap()
        app.buttons["home.continue"].tap()
        XCTAssertTrue(app.buttons["quran.action.Plus"].waitForExistence(timeout: 5))
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)), to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let pages = app.images.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quran.page."))
        print("[ReaderNavigationTest] \(pages.allElementsBoundByIndex.map { $0.label })")
        from.press(forDuration: 0.1, thenDragTo: to)
        XCTAssertTrue(app.buttons["home.continue"].waitForExistence(timeout: 5))
    }
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
