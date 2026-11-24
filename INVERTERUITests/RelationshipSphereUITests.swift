import XCTest

@MainActor
final class RelationshipSphereUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(count: Int = 5) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--language=zh", "--appearance=light", "--sphere-count=\(count)"]
        app.launch()
        app.buttons["tab.CONNECT"].tap()
        XCTAssertTrue(app.staticTexts["sphere.state"].waitForExistence(timeout: 15))
        return app
    }
    private func state(_ app: XCUIApplication) -> String { app.staticTexts["sphere.state"].value as? String ?? "" }
    private func settle(_ seconds: Double = 0.6) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }
    private func screenshot(_ app: XCUIApplication, _ name: String) {
        settle()
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if element.exists && element.isHittable { return }
            // Scroll outside the 3D interaction surface, whose vertical drags intentionally rotate.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.78)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.30)))
        }
    }
    func testQuaternionRotationPinchAndDoubleTapReset() {
        let app = launch()
        let sphere = app.otherElements["sphere.viewport"]
        XCTAssertTrue(sphere.exists)
        settle()
        let initial = state(app)
        let headerY = app.staticTexts["关系，让理解发生。"].frame.minY
        let core = app.buttons["sphere.core"].frame
        let left = sphere.coordinate(withNormalizedOffset: CGVector(dx: 0.20, dy: 0.50))
        let right = sphere.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.50))
        left.press(forDuration: 0.05, thenDragTo: right)
        XCTAssertNotEqual(state(app), initial)
        screenshot(app, "Sphere-rotated-horizontal")
        let afterHorizontal = state(app)
        let bottom = sphere.coordinate(withNormalizedOffset: CGVector(dx: 0.52, dy: 0.78))
        let top = sphere.coordinate(withNormalizedOffset: CGVector(dx: 0.52, dy: 0.20))
        bottom.press(forDuration: 0.05, thenDragTo: top)
        XCTAssertNotEqual(state(app), afterHorizontal)
        XCTAssertEqual(app.staticTexts["关系，让理解发生。"].frame.minY, headerY, accuracy: 2)
        XCTAssertEqual(app.buttons["sphere.core"].frame.midX, core.midX, accuracy: 1)
        XCTAssertEqual(app.buttons["sphere.core"].frame.midY, core.midY, accuracy: 1)
        sphere.pinch(withScale: 1.5, velocity: 1.5)
        XCTAssertTrue(state(app).contains("zoom:1.120"), state(app))
        screenshot(app, "Sphere-pinch")
        sphere.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.12)).doubleTap()
        settle(0.8)
        XCTAssertEqual(state(app), initial)
        screenshot(app, "Sphere-reset")
    }
    func testFilterWhileRotatingSelectionAndExistingDetail() {
        let app = launch()
        app.buttons["sphere.auto"].tap()
        let rotating = state(app)
        settle(0.25)
        XCTAssertNotEqual(state(app), rotating)
        app.buttons["sphere.filter.家人"].tap()
        settle()
        XCTAssertTrue(state(app).contains("nodes:1;"), state(app))
        XCTAssertFalse(app.buttons["person.人物01"].exists)
        app.buttons["sphere.reset"].tap()
        settle()
        XCTAssertTrue(state(app).contains("nodes:1;"))
        XCTAssertTrue(app.buttons["person.人物02"].waitForExistence(timeout: 5))
        app.buttons["sphere.auto"].tap()
        app.buttons["person.人物02"].tap()
        let detail = app.buttons["sphere.details"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        screenshot(app, "Sphere-selected-family")
        let sphere = app.otherElements["sphere.viewport"]
        sphere.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: detail)
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 3), .completed)
        app.buttons["person.人物02"].tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        reveal(detail, in: app); detail.tap()
        XCTAssertTrue(app.navigationBars["关系档案"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["人物02"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["sphere.state"].waitForExistence(timeout: 5))
        for _ in 0..<3 {
            app.buttons["tab.HOME"].tap()
            XCTAssertTrue(app.buttons["home.review"].waitForExistence(timeout: 5))
            app.buttons["tab.CONNECT"].tap()
            XCTAssertTrue(app.staticTexts["sphere.state"].waitForExistence(timeout: 5))
        }
        app.buttons["sphere.filter.全部"].tap()
        settle()
        XCTAssertTrue(state(app).contains("nodes:5;"))
    }
    func testBackgroundSuspendsAutoplay() {
        let app = launch()
        app.buttons["sphere.auto"].tap()
        settle(0.3)
        XCUIDevice.shared.press(.home)
        settle(0.5)
        app.activate()
        XCTAssertTrue(app.staticTexts["sphere.state"].waitForExistence(timeout: 8))
        settle()
        let resumed = state(app)
        settle(0.5)
        XCTAssertEqual(state(app), resumed)
        XCTAssertEqual(app.buttons["sphere.auto"].label, "开始缓慢旋转")
        screenshot(app, "Sphere-resumed")
    }
    func testDeletePersonRemovesNodeAndConnection() {
        let app = launch(count: 1)
        app.buttons["person.人物01"].tap()
        app.buttons["sphere.details"].tap()
        XCTAssertTrue(app.navigationBars["关系档案"].waitForExistence(timeout: 5))
        let remove = app.buttons["移除此人物"]
        reveal(remove, in: app); remove.tap()
        app.buttons["移除人物"].tap()
        XCTAssertTrue(app.staticTexts["sphere.state"].waitForExistence(timeout: 5))
        settle()
        XCTAssertTrue(state(app).contains("nodes:0;"), state(app))
        XCTAssertFalse(app.buttons["person.人物01"].exists)
    }
    func testEmptySingleTwentyAndFiftyPeople() {
        for count in [0, 1, 20, 50] {
            let app = launch(count: count)
            XCTAssertTrue(state(app).contains("nodes:\(count);"), state(app))
            screenshot(app, "Sphere-\(count)-people")
            if count == 0 {
                let empty = app.staticTexts["从一个重要的人开始"]
                reveal(empty, in: app); XCTAssertTrue(empty.exists)
            } else {
                let sphere = app.otherElements["sphere.viewport"]
                sphere.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.50)).press(forDuration: 0.05, thenDragTo: sphere.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.35)))
                app.buttons["sphere.reset"].tap()
                settle()
                XCTAssertTrue(state(app).contains("nodes:\(count);"))
            }
            app.terminate()
        }
    }
}
