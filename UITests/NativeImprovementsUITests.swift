import XCTest

final class NativeImprovementsUITests: XCTestCase {
    func testProfileAndSettingsHaveSeparateDestinations() {
        let app = XCUIApplication(); app.launchArguments=["--ui-test-authenticated"]; app.launch()
        XCTAssertTrue(app.buttons["profile.open"].waitForExistence(timeout: 10)); app.buttons["profile.open"].tap()
        XCTAssertTrue(app.navigationBars["Mon profil"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Versets connus"].exists)
        app.navigationBars["Mon profil"].buttons["Fermer"].tap()
        app.buttons["settings.open"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 5))
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(app.staticTexts["Version native"].exists)
        XCTAssertFalse(app.staticTexts["Mushaf de Médine • Règles de Tajweed"].exists)
    }
}
