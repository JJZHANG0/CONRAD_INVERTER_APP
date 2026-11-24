import XCTest

final class FirstLookUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func launch(_ language: String = "zh") -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--ai-fixture", "--firstlook", "--language=\(language)", "--appearance=light"]; app.launch(); return app
    }
    @MainActor private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<9 { if element.exists && element.isHittable { return }; app.swipeUp() }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    @MainActor func testTenAnswersReportAndShareSheet() {
        let app = launch()
        XCTAssertTrue(app.buttons["firstlook.start"].waitForExistence(timeout: 10))
        capture(app, "FirstLook-ZH-Welcome")
        reveal(app.buttons["firstlook.start"], app: app); app.buttons["firstlook.start"].tap()
        for index in 0..<10 {
            let next = app.buttons["firstlook.next"]
            XCTAssertTrue(app.buttons["firstlook.option.0"].waitForExistence(timeout: 5))
            XCTAssertFalse(next.isEnabled)
            if index == 0 { capture(app, "FirstLook-ZH-Question") }
            reveal(app.buttons["firstlook.option.\(index % 4)"], app: app); app.buttons["firstlook.option.\(index % 4)"].tap()
            reveal(next, app: app); next.tap()
        }
        XCTAssertTrue(app.images["firstlook.poster"].waitForExistence(timeout: 10))
        capture(app, "FirstLook-ZH-Report")
        app.images["firstlook.poster"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["保存报告图片"].waitForExistence(timeout: 5))
        capture(app, "FirstLook-LongPress")
        app.buttons["保存报告图片"].tap()
        XCTAssertTrue(app.alerts.staticTexts["报告图片已保存到相册。"].waitForExistence(timeout: 10))
        app.alerts.buttons["知道了"].tap()
        reveal(app.buttons["firstlook.share"], app: app); app.buttons["firstlook.share"].tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5) || app.buttons["Copy"].exists || app.buttons["拷贝"].exists)
        capture(app, "FirstLook-ShareSheet")
    }
    @MainActor func testBackgroundResumesUnfinishedAnswersWithOptionalExit() {
        let app = launch("en")
        XCTAssertTrue(app.buttons["firstlook.skip"].exists)
        reveal(app.buttons["firstlook.start"], app: app); app.buttons["firstlook.start"].tap()
        app.buttons["firstlook.option.1"].tap()
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["firstlook.option.1"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["firstlook.option.1"].isSelected)
        XCTAssertTrue(app.buttons["Save & leave"].exists)
        capture(app, "FirstLook-EN-Resumed")
    }
}
