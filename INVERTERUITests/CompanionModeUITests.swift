import XCTest

@MainActor final class CompanionModeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func start(_ language: String = "zh", _ appearance: String = "light") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ai-fixture", "--voice-fixture", "--language=\(language)", "--appearance=\(appearance)"]
        app.launch(); app.buttons["home.bot"].tap()
        XCTAssertTrue(app.staticTexts["chat.reply"].waitForExistence(timeout: 10)); return app
    }
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testFourModesHaveDistinctOpeningsAndVoiceUsesSelectedMode() {
        let app = start()
        for (mode, question) in [("understanding", "最近你对自己的哪一次反应感到困惑？"), ("emotions", "最近哪个片刻让你的情绪停留了很久？"), ("relationships", "最近哪一次相处，让你想更清楚自己的边界？"), ("action", "有什么你很想尝试，却一直停在原地的小事？")] {
            app.buttons["chat.mode.\(mode)"].tap()
            XCTAssertTrue(app.staticTexts[question].waitForExistence(timeout: 8))
            XCTAssertEqual(app.staticTexts.matching(identifier: "chat.reply").count, 1)
            shot(app, "Mode-\(mode)-Light")
        }
        app.buttons["chat.voice"].tap()
        XCTAssertTrue(app.staticTexts["voice.mode"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["voice.mode"].label, "行动勇气")
        app.buttons["voice.end"].tap()
        XCTAssertTrue(app.buttons["chat.mode.action"].waitForExistence(timeout: 8))
    }
    func testSwitchProtectsDraftAndStartsCleanAfterConfirmation() {
        let app = start("en", "dark")
        shot(app, "Modes-English-Dark")
        let editor = app.textViews["chat.input"].exists ? app.textViews["chat.input"] : app.textFields["chat.input"]
        editor.tap(); editor.typeText("I want to take a small step.")
        app.buttons["chat.mode.action"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5)); app.buttons["Cancel"].tap()
        XCTAssertEqual(editor.value as? String, "I want to take a small step.")
        app.buttons["chat.mode.action"].tap(); app.buttons["Switch and start a new conversation"].tap()
        XCTAssertTrue(app.staticTexts["What meaningful small step have you been hesitating to take?"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts.matching(identifier: "chat.user").count, 0)
        XCTAssertFalse((editor.value as? String ?? "").contains("I want to"))
        shot(app, "Mode-Action-Dark")
    }
}
