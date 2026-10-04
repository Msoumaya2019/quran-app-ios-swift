import XCTest

final class PhaseOneUITests: XCTestCase {
    func testMessageSavedOfflineSurvivesConversationReopening() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated", "--ui-test-friends"]; app.launch()
        app.tabBars.buttons["Amis"].tap()
        let friend = app.staticTexts["Yassine"]; XCTAssertTrue(friend.waitForExistence(timeout: 10)); friend.tap()
        let chat = app.buttons["friends.chat.open"]; XCTAssertTrue(chat.waitForExistence(timeout: 5)); chat.tap()
        let field = app.descendants(matching: .any)["chat.composer"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        let body = "Message local \(UUID().uuidString.prefix(8))"; field.typeText(body)
        app.buttons["chat.send"].tap()
        XCTAssertTrue(app.staticTexts[body].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["À synchroniser"].firstMatch.exists)
        attach(app, name: "Conversation native — message conservé hors ligne")
        app.navigationBars.buttons.firstMatch.tap(); app.buttons["friends.chat.open"].tap()
        XCTAssertTrue(app.staticTexts[body].waitForExistence(timeout: 5))
    }
    func testCachedFriendProfileShowsSharedProgress() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated", "--ui-test-friends"]; app.launch()
        app.tabBars.buttons["Amis"].tap()
        let friend = app.staticTexts["Yassine"]
        XCTAssertTrue(friend.waitForExistence(timeout: 10)); friend.tap()
        XCTAssertTrue(app.staticTexts["28 versets · 5 séances"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Coran mémorisé : 33 %"].exists)
        XCTAssertTrue(app.staticTexts["Finir le Hizb 42"].exists)
        attach(app, name: "Profil ami natif — progression partagée en cache")
    }
    func testFriendsScreenOpensOfflineAndRequestRequiresCode() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated"]; app.launch()
        app.tabBars.buttons["Amis"].tap()
        XCTAssertTrue(app.textFields["friends.search"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Mes amis"].exists)
        app.buttons["Ajouter un ami"].tap()
        XCTAssertTrue(app.textFields["Code d’invitation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Envoyer la demande"].isEnabled)
        attach(app, name: "Amis natifs — ajout par code")
        app.buttons["Fermer"].tap()
        XCTAssertTrue(app.textFields["friends.search"].exists)
    }
    func testRevisionRhythmCanBeChangedFromSettingsOffline() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated", "--ui-test-revision"]; app.launch()
        app.buttons["settings.open"].tap()
        let editor = app.buttons["settings.revision.open"]
        guard editor.waitForExistence(timeout: 10) else { XCTFail("Revision settings unavailable"); return }
        editor.tap()
        app.segmentedControls.buttons["Quantité quotidienne"].tap()
        let save = app.buttons["revision.settings.save"]
        for _ in 0..<4 { if save.isHittable { break }; app.swipeUp() }
        guard save.isHittable else { XCTFail("Revision save unavailable: \(app.debugDescription)"); return }
        save.tap()
        XCTAssertTrue(app.staticTexts["revision.settings.result"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["revision.settings.result"].label.contains("1 Hizb / jour"))
        attach(app, name: "Réglages de révision — quantité quotidienne hors ligne")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["settings.revision.open"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Quantité quotidienne"].isSelected)
    }
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
    func testQuizOpensOfflineWithoutAddingNavigationTab() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated"]; app.launch()
        XCTAssertTrue(app.buttons["home.Quiz"].waitForExistence(timeout: 10))
        app.buttons["home.Quiz"].tap()
        XCTAssertTrue(app.buttons["quiz.daily"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.buttons.count, 5)
        app.buttons["quiz.daily"].tap()
        XCTAssertTrue(app.navigationBars["Question du jour"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Aucune question du jour disponible. Connecte-toi pour actualiser le Quiz."].exists)
        attach(app, name: "Question du jour sans réseau")
    }
    func testCachedDailyQuizLocksOfflineAnswerAfterReopening() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated", "--ui-test-quiz"]; app.launch()
        XCTAssertTrue(app.buttons["home.Quiz"].waitForExistence(timeout: 10)); app.buttons["home.Quiz"].tap()
        app.buttons["quiz.daily"].tap()
        XCTAssertTrue(app.buttons["quiz.answer.A"].waitForExistence(timeout: 5))
        app.buttons["quiz.answer.A"].tap()
        XCTAssertFalse(app.buttons["quiz.answer.B"].isEnabled)
        XCTAssertTrue(app.staticTexts["Réponse enregistrée — correction après synchronisation"].exists)
        attach(app, name: "Question du jour — réponse conservée sans réseau")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["quiz.daily"].tap()
        XCTAssertFalse(app.buttons["quiz.answer.C"].isEnabled)
    }
}
