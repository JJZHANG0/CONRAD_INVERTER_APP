import XCTest

final class AppearanceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.7))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testEnglishDarkChineseAndPreferencePersistence() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--language=en", "--appearance=light"]
        app.launch()
        XCTAssertTrue(app.buttons["home.review"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Make room\nfor every part of you."].exists)
        capture(app, "EN-Light-Home")
        app.buttons["tab.CONNECT"].tap()
        XCTAssertTrue(app.buttons["person.Lin"].waitForExistence(timeout: 8))
        capture(app, "EN-Light-Connections")
        app.buttons["tab.PROFILE"].tap()
        reveal(app.buttons["profile.appearance"], app: app)
        app.buttons["profile.appearance"].tap()
        XCTAssertTrue(app.navigationBars["Appearance & language"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label == %@", "Dark")).firstMatch.tap()
        capture(app, "EN-Dark-Settings")
        app.buttons.matching(NSPredicate(format: "label == %@", "简体中文")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["外观与语言"].waitForExistence(timeout: 5))
        capture(app, "ZH-Dark-Settings")
        app.buttons["tab.HOME"].tap()
        XCTAssertTrue(app.staticTexts["慢慢理解，\n每一个自己。"].waitForExistence(timeout: 5))
        capture(app, "ZH-Dark-Home")
        app.buttons["tab.CONNECT"].tap()
        XCTAssertTrue(app.buttons["person.林予"].waitForExistence(timeout: 5))
        capture(app, "ZH-Dark-Connections")
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["慢慢理解，\n每一个自己。"].waitForExistence(timeout: 10))
        capture(app, "ZH-Dark-Relaunched")
    }
    @MainActor func testEnglishAccountValidationAndExploration() {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--language=en", "--appearance=light"]; app.launch()
        app.buttons["tab.PROFILE"].tap()
        reveal(app.buttons["profile.account"], app: app); app.buttons["profile.account"].tap()
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["account.login"].isEnabled)
        capture(app, "EN-Light-Account")
        app.buttons["tab.INNER"].tap()
        reveal(app.staticTexts["Values"], app: app); app.staticTexts["Values"].tap()
        XCTAssertTrue(app.buttons["game.start"].waitForExistence(timeout: 5))
        capture(app, "EN-Light-Exploration")
    }
}
