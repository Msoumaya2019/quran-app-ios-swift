import XCTest

final class ReaderUITests: XCTestCase {
    func testProgramOpensPassageWithNativeSessionHeader() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-authenticated", "--ui-test-reader-fixtures", "--ui-test-program"]
        app.launch(); app.tabBars.buttons["Programme"].tap()
        XCTAssertTrue(app.buttons["program.task.preview-learning"].firstMatch.waitForExistence(timeout: 5))
        attach(app, name: "Programme natif — séances locales")
        app.buttons["program.task.preview-learning"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["quran.session.header"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["quran.page.1"].waitForExistence(timeout: 5))
        attach(app, name: "Apprentissage natif — passage et capsule")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["program.task.preview-learning"].firstMatch.waitForExistence(timeout: 5))
    }
    func testLearningCanBePartiallyValidatedOffline() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-authenticated", "--ui-test-reader-fixtures", "--ui-test-program"]
        app.launch(); app.tabBars.buttons["Programme"].tap()
        let task = app.buttons["program.task.preview-learning"].firstMatch
        guard task.waitForExistence(timeout: 10) else { XCTFail("Learning task unavailable"); return }
        task.tap(); app.buttons["quran.action.Plus"].tap()
        let open = app.buttons["learning.open"]
        guard open.waitForExistence(timeout: 10) else { XCTFail("Learning validation unavailable"); return }
        open.tap()
        app.buttons["learning.validate"].tap()
        app.buttons["J’ai appris jusqu’ici"].tap()
        XCTAssertTrue(app.staticTexts["learning.result"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["1 / 7 versets validés"].exists)
        attach(app, name: "Apprentissage natif — validation partielle hors ligne")
    }
    func testNativeIndexSearchAndDivisionNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-authenticated", "--ui-test-reader-fixtures"]
        app.launch(); app.tabBars.buttons["Coran"].tap()
        app.buttons["quran.action.Plus"].tap()
        XCTAssertTrue(app.buttons["quran.index.open"].waitForExistence(timeout: 5))
        app.buttons["quran.index.open"].tap()
        XCTAssertTrue(app.buttons["quran.index.surah.1"].waitForExistence(timeout: 5))
        attach(app, name: "Index natif — sourates")
        app.segmentedControls.buttons["Juz’"].tap()
        XCTAssertTrue(app.buttons["quran.index.juz.1"].exists)
        app.segmentedControls.buttons["Hizb"].tap()
        XCTAssertTrue(app.buttons["quran.index.hizb.1"].exists)
        app.segmentedControls.buttons["Liste"].tap()
        let search = app.searchFields.firstMatch
        search.tap(); search.typeText("Fatiha")
        XCTAssertTrue(app.buttons["quran.index.surah.1"].exists)
        XCTAssertFalse(app.buttons["quran.index.surah.2"].exists)
        app.buttons["quran.index.surah.1"].tap()
        XCTAssertTrue(app.images["quran.page.1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["quran.action.Plus"].exists)
    }
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
        guard XCTWaiter.wait(for: [ready], timeout: 30) == .completed else {
            XCTFail("Local audio must be ready before testing seek: \(app.debugDescription)"); return
        }
        app.buttons["quran.audio.toggle"].tap()
        slider.adjust(toNormalizedSliderPosition: 0.5)
        let elapsed = app.staticTexts["quran.audio.elapsed"]
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label MATCHES %@", "0:(2[89]|3[0-2])"), object: elapsed)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 10), .completed)
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
