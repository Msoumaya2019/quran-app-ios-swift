import XCTest

final class PhaseOneUITests: XCTestCase {
    func testAdminCanListenToRecitationAndSendFeedback() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated", "--ui-test-moderation"]; app.launch()
        app.buttons["settings.open"].tap()
        let open = app.buttons["settings.admin.recitations"]; XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
        let user = app.staticTexts["Yassine"]; XCTAssertTrue(user.waitForExistence(timeout: 5)); user.tap()
        let listen = app.buttons["moderation.listen"]; XCTAssertTrue(listen.waitForExistence(timeout: 5)); listen.tap()
        XCTAssertTrue(app.staticTexts["Arrêter l’écoute"].waitForExistence(timeout: 5))
        listen.tap(); app.buttons["Marquer comme écoutée"].tap()
        XCTAssertTrue(app.buttons["Écoutée"].waitForExistence(timeout: 5))
        let field = app.textViews["moderation.feedback"]; field.tap(); field.typeText("Retour technique de test")
        app.buttons["Envoyer le retour"].tap(); XCTAssertTrue(app.staticTexts["Retour envoyé"].waitForExistence(timeout: 5))
        attach(app, name: "Administration — écoute et retour sur une récitation")
    }
    func testAdminDeletesMessageOnlyAfterConfirmation() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated", "--ui-test-moderation"]; app.launch()
        app.buttons["settings.open"].tap()
        let open = app.buttons["settings.admin.messages"]; XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
        let user = app.staticTexts["Yassine"]; XCTAssertTrue(user.waitForExistence(timeout: 5)); user.tap()
        XCTAssertTrue(app.staticTexts["Message de test à modérer"].exists)
        app.buttons["moderation.delete"].tap()
        let confirmations = app.buttons.matching(identifier: "Supprimer le message").allElementsBoundByIndex
        XCTAssertFalse(confirmations.isEmpty); confirmations.last?.tap()
        XCTAssertTrue(app.staticTexts["Message supprimé"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["moderation.delete"].isEnabled)
        attach(app, name: "Administration — message supprimé après confirmation")
    }
    func testSocialPreferencesStayEditableAndDoNotClaimOfflineSave() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated"]; app.launch()
        app.buttons["settings.open"].tap()
        let open = app.buttons["settings.social.open"]; XCTAssertTrue(open.waitForExistence(timeout: 5)); open.tap()
        let save = app.buttons["social.profile.save"]; XCTAssertTrue(save.waitForExistence(timeout: 5)); XCTAssertFalse(save.isEnabled)
        let field = app.textFields["social.profile.name"]; field.tap(); field.typeText("Mohamed")
        save.tap()
        XCTAssertTrue(app.staticTexts["Connexion nécessaire pour cette action."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Préférences enregistrées"].exists)
        XCTAssertEqual(field.value as? String, "Mohamed")
        attach(app, name: "Profil ami — préférences conservées sans faux succès hors ligne")
    }
    func testGroupConversationOpensOfflineAndKeepsItsPendingMessage() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated", "--ui-test-friends", "--ui-test-groups"]; app.launch()
        app.tabBars.buttons["Amis"].tap(); app.buttons["Mes groupes"].tap()
        let group = app.staticTexts["Groupe de test"]; XCTAssertTrue(group.waitForExistence(timeout: 5)); group.tap()
        let chat = app.buttons["groups.chat"]; XCTAssertTrue(chat.waitForExistence(timeout: 5)); chat.tap()
        let field = app.descendants(matching: .any)["chat.composer"].firstMatch; XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        let body = "Message de groupe \(UUID().uuidString.prefix(6))"; field.typeText(body); app.buttons["chat.send"].tap()
        XCTAssertTrue(app.staticTexts[body].waitForExistence(timeout: 5)); XCTAssertTrue(app.staticTexts["À synchroniser"].firstMatch.exists)
        attach(app, name: "Conversation de groupe — message hors connexion")
        app.navigationBars.buttons.firstMatch.tap(); app.buttons["groups.chat"].tap()
        XCTAssertTrue(app.staticTexts[body].waitForExistence(timeout: 5)); XCTAssertEqual(app.tabBars.buttons.count, 5)
    }
    func testCreatingGroupRequiresConnectionAndDoesNotInventLocalGroup() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated"]; app.launch()
        app.tabBars.buttons["Amis"].tap(); app.buttons["Mes groupes"].tap()
        let create = app.buttons["groups.create"]; XCTAssertTrue(create.waitForExistence(timeout: 5)); XCTAssertFalse(create.isEnabled)
        let field = app.textFields["groups.name"]; field.tap(); field.typeText("Nouveau groupe")
        create.tap(); XCTAssertTrue(app.staticTexts["Connexion nécessaire pour cette action."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Aucun groupe synchronisé"].exists)
        attach(app, name: "Groupes — création nécessite une connexion")
    }
    func testProblemReportSheetSavesOfflineWithoutChangingTabs() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-authenticated"]; app.launch()
        let open = app.buttons["home.report"]
        for _ in 0..<4 { if open.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(open.waitForExistence(timeout: 5)); open.tap()
        let send = app.buttons["report.send"]; XCTAssertTrue(send.waitForExistence(timeout: 5)); XCTAssertFalse(send.isEnabled)
        app.buttons["report.type.Audio"].tap()
        let field = app.textViews["report.description"]; field.tap(); field.typeText("Signalement de test hors connexion")
        app.swipeUp(); XCTAssertTrue(send.isEnabled); send.tap()
        XCTAssertTrue(app.descendants(matching: .any)["report.saved"].firstMatch.waitForExistence(timeout: 5))
        attach(app, name: "Signalement natif — enregistré hors connexion")
        app.buttons["Fermer"].firstMatch.tap()
        XCTAssertEqual(app.tabBars.buttons.count, 5)
    }
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
