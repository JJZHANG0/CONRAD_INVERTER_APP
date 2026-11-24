import XCTest

final class UnifiedModelUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<10 { if element.exists && element.isHittable { return }; app.swipeUp() }
    }
    @MainActor func testFirstLookFailureRetainsAnswersAndRetryGeneratesReport() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ai-fixture", "--ai-fail-once", "--firstlook", "--language=zh", "--appearance=light"]
        app.launch()
        reveal(app.buttons["firstlook.start"], app: app); app.buttons["firstlook.start"].tap()
        for _ in 0..<10 {
            let option = app.buttons["firstlook.option.0"]
            XCTAssertTrue(option.waitForExistence(timeout: 5)); reveal(option, app: app); option.tap()
            let next = app.buttons["firstlook.next"]; reveal(next, app: app); next.tap()
        }
        XCTAssertTrue(app.staticTexts["firstlook.error"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.images["firstlook.poster"].exists)
        XCTAssertTrue(app.buttons["firstlook.option.0"].isSelected)
        app.buttons["firstlook.next"].tap()
        XCTAssertTrue(app.images["firstlook.poster"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["让文字，更贴近你"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Unified-Report"; shot.lifetime = .keepAlways; add(shot)
    }
    @MainActor func testReflectionFailureKeepsInputAndRetriesSameStep() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ai-fixture", "--ai-fail-once", "--language=zh", "--appearance=light"]
        app.launch(); app.buttons["home.review"].tap()
        let editor = app.textFields["review.input"]
        XCTAssertTrue(editor.waitForExistence(timeout: 8)); editor.tap(); editor.typeText("今天我向朋友表达了一个需要。")
        let next = app.buttons["review.next"]; reveal(next, app: app); next.tap()
        XCTAssertTrue(app.alerts["暂时无法继续"].waitForExistence(timeout: 8))
        app.alerts.buttons["知道了"].tap()
        XCTAssertEqual(editor.value as? String, "今天我向朋友表达了一个需要。")
        reveal(next, app: app); next.tap()
        XCTAssertTrue(app.staticTexts["回到你刚刚提到的那个片刻，你最希望被理解的是什么？"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["本地引导"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Unified-Reflection"; shot.lifetime = .keepAlways; add(shot)
    }
}
