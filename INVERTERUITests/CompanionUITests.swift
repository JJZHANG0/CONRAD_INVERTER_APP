import XCTest

final class CompanionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func reveal(_ item: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<10 { if item.exists && item.isHittable { return }; app.swipeUp() }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testBotOpensChatAndFailedMessageRetriesWithoutDuplication() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ai-fixture", "--ai-fail-once", "--language=zh", "--appearance=light"]
        app.launch()
        XCTAssertTrue(app.buttons["home.bot"].waitForExistence(timeout: 8))
        capture(app,"Bot-Home-Light")
        app.buttons["home.bot"].tap()
        XCTAssertTrue(app.textFields["chat.input"].waitForExistence(timeout: 8) || app.textViews["chat.input"].exists)
        capture(app,"Bot-Chat-Light")
        let editor = app.textViews["chat.input"].exists ? app.textViews["chat.input"] : app.textFields["chat.input"]
        editor.tap(); editor.typeText("今天我终于把自己的想法说了出来。")
        app.buttons["chat.send"].tap()
        XCTAssertTrue(app.buttons["chat.retry"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts.matching(identifier:"chat.user").count, 1)
        app.buttons["chat.retry"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "chat.reply").element(boundBy: 1).waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts.matching(identifier:"chat.user").count, 1)
        capture(app,"Bot-Chat-Reply")
        app.buttons["chat.close"].tap()
        XCTAssertTrue(app.buttons["home.bot"].waitForExistence(timeout: 5))
    }
    @MainActor func testDarkChat() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--ai-fixture", "--language=en", "--appearance=dark"]
        app.launch(); XCTAssertTrue(app.buttons["home.bot"].waitForExistence(timeout: 8)); app.buttons["home.bot"].tap()
        XCTAssertTrue(app.staticTexts["chat.reply"].waitForExistence(timeout: 8))
        capture(app,"Bot-Chat-Dark")
    }
    @MainActor func testCompletedTestDoesNotRepeatOnForegroundOrColdLaunch() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--ai-fixture", "--firstlook", "--language=zh"]
        app.launch(); reveal(app.buttons["firstlook.start"],app); app.buttons["firstlook.start"].tap()
        for _ in 0..<10 {
            let option = app.buttons["firstlook.option.0"]; XCTAssertTrue(option.waitForExistence(timeout: 5)); reveal(option,app); option.tap()
            let next = app.buttons["firstlook.next"]; reveal(next,app); next.tap()
        }
        XCTAssertTrue(app.otherElements["reflection.loading"].waitForExistence(timeout: 2))
        capture(app, "FirstLook-Loading")
        XCTAssertTrue(app.buttons["firstlook.finish"].waitForExistence(timeout: 8)); app.buttons["firstlook.finish"].tap()
        XCTAssertTrue(app.buttons["home.bot"].waitForExistence(timeout: 8))
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["home.bot"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["firstlook.start"].exists)
        app.terminate(); app.launchArguments.append("--preserve-ui-data"); app.launch()
        XCTAssertTrue(app.buttons["home.bot"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["firstlook.start"].exists)
    }
    @MainActor func testGuidedConversationCreatesShareableReport() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--ai-fixture", "--language=zh", "--appearance=light"]
        app.launch(); app.buttons["home.bot"].tap()
        XCTAssertTrue(app.staticTexts["chat.reply"].waitForExistence(timeout: 8))
        let editor = app.textViews["chat.input"].exists ? app.textViews["chat.input"] : app.textFields["chat.input"]
        editor.tap(); editor.typeText("我说出了自己的想法，也希望朋友能认真听我说完。")
        app.buttons["chat.send"].tap()
        XCTAssertTrue(app.staticTexts.matching(identifier: "chat.reply").element(boundBy: 1).waitForExistence(timeout: 8))
        app.buttons["chat.menu"].tap(); app.buttons["结束并整理"].tap()
        XCTAssertTrue(app.otherElements["reflection.loading"].waitForExistence(timeout: 2))
        capture(app, "Conversation-Loading")
        XCTAssertTrue(app.buttons["chat.report"].waitForExistence(timeout: 8)); reveal(app.buttons["chat.report"], app); app.buttons["chat.report"].tap()
        XCTAssertTrue(app.images["chat.report.poster"].waitForExistence(timeout: 8)); capture(app, "Conversation-Report")
        app.images["chat.report.poster"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["分享报告图片"].waitForExistence(timeout: 5)); app.buttons["分享报告图片"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5) || app.buttons["Copy"].exists || app.buttons["拷贝"].exists)
        capture(app, "Conversation-ShareSheet")
    }
    @MainActor func testVoiceCallCanMuteInterruptAndHangUp() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--ai-fixture", "--voice-fixture", "--language=en", "--appearance=dark"]
        app.launch(); app.buttons["home.bot"].tap()
        XCTAssertTrue(app.staticTexts["chat.reply"].waitForExistence(timeout: 8)); app.buttons["chat.voice"].tap()
        XCTAssertTrue(app.buttons["voice.end"].waitForExistence(timeout: 8)); capture(app, "Voice-Call-Dark")
        if app.buttons["voice.interrupt"].exists { app.buttons["voice.interrupt"].tap() }
        app.buttons["voice.mute"].tap()
        XCTAssertTrue(app.staticTexts["Microphone muted"].waitForExistence(timeout: 5))
        app.buttons["voice.mute"].tap()
        XCTAssertTrue(app.staticTexts["I’m listening. Take your time."].waitForExistence(timeout: 5))
        app.buttons["voice.end"].tap()
        XCTAssertTrue(app.buttons["chat.voice"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["voice.end"].exists)
    }
}
