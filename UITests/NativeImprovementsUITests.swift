import XCTest

final class NativeImprovementsUITests: XCTestCase {
    func testProfileAndSettingsHaveSeparateDestinations() {
        for mode in ["light", "dark"] {
        let app = XCUIApplication(); app.launchArguments=["--ui-test-authenticated", "-native.appearance", mode]; app.launch()
        XCTAssertTrue(app.buttons["profile.open"].waitForExistence(timeout: 10)); app.buttons["profile.open"].tap()
        XCTAssertTrue(app.navigationBars["Mon profil"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Versets connus"].exists)
        attach(app, name: "Mon profil-" + mode)
        app.navigationBars["Mon profil"].buttons["Fermer"].tap()
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 5))
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(app.staticTexts["Version native"].exists)
        XCTAssertFalse(app.staticTexts["Mushaf de Médine • Règles de Tajweed"].exists)
        attach(app, name: "Réglages-" + mode)
        app.terminate()
        }
    }
    func testReaderKeepsThreeSourcesAndNoDuplicateTajweedBlock() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated", "--ui-test-reader-fixtures"]; app.launch()
        app.tabBars.buttons["Coran"].tap()
        XCTAssertTrue(app.images["quran.page.1"].waitForExistence(timeout: 10))
        app.buttons["quran.action.Plus"].tap()
        let tajweed = app.buttons["quran.source.qcf_tajweed_v4"]
        for _ in 0..<6 { if tajweed.exists && tajweed.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(tajweed.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["quran.source.traditional"].exists)
        XCTAssertTrue(app.buttons["quran.source.coran_1441"].exists)
        XCTAssertFalse(app.staticTexts["Mushaf de Médine • Règles de Tajweed"].exists)
        attach(app, name: "Lecture-trois-sources")
    }
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
