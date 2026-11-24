import XCTest

final class INVERTERUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ai-fixture", "--language=zh", "--appearance=light"]
        app.launch()
        return app
    }
    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        // Let the native tab crossfade settle before taking a visual QA snapshot.
        RunLoop.current.run(until: Date().addingTimeInterval(0.7))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<7 {
            if element.exists && element.isHittable { return }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.78)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.30)))
        }
    }
    @MainActor func testFourTabsAndRelationshipNode() {
        let app = launch()
        XCTAssertTrue(app.buttons["home.review"].waitForExistence(timeout: 10))
        capture(app, name: "01-Home")
        app.buttons["tab.INNER"].tap()
        XCTAssertTrue(app.staticTexts["向内，遇见自己。"].exists)
        capture(app, name: "02-Inner")
        app.buttons["tab.CONNECT"].tap()
        XCTAssertTrue(app.buttons["person.林予"].waitForExistence(timeout: 5))
        capture(app, name: "03-Connections")
        app.buttons["person.林予"].tap()
        reveal(app.buttons["sphere.details"], in: app)
        app.buttons["sphere.details"].tap()
        XCTAssertTrue(app.navigationBars["关系档案"].waitForExistence(timeout: 5))
        capture(app, name: "04-Person")
        app.buttons["tab.PROFILE"].tap()
        XCTAssertTrue(app.staticTexts["探索者"].exists)
        capture(app, name: "05-Profile")
    }
    @MainActor func testCreateReflectionAndViewSavedRecord() {
        let app = launch()
        app.buttons["home.review"].tap()
        let input = app.textViews["review.input"].exists ? app.textViews["review.input"] : app.textFields["review.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("A conversation with a friend.")
        let next = app.buttons["review.next"]
        reveal(next, in: app)
        next.tap()
        XCTAssertTrue(app.buttons["平静"].waitForExistence(timeout: 5))
        app.buttons["平静"].tap()
        reveal(next, in: app); next.tap()
        for _ in 0..<3 { reveal(next, in: app); next.tap() }
        let save = app.buttons["review.save"]
        reveal(save, in: app)
        XCTAssertTrue(save.isHittable)
        save.tap()
        XCTAssertTrue(app.staticTexts["又多理解了自己一点。"].waitForExistence(timeout: 5))
        capture(app, name: "06-SavedReflection")
        app.buttons["review.done"].tap()
        app.buttons["tab.PROFILE"].tap()
        app.buttons["profile.history"].tap()
        XCTAssertTrue(app.staticTexts["A conversation with a "].exists || app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "A conversation")).firstMatch.exists)
    }
    @MainActor func testGameCompleteAndReport() {
        let app = launch()
        app.buttons["tab.INNER"].tap()
        let game = app.buttons.containing(.staticText, identifier: "情境选择").firstMatch
        reveal(game, in: app)
        game.tap()
        let start = app.buttons["game.start"]
        reveal(start, in: app); start.tap()
        for _ in 0..<3 {
            let option = app.buttons["game.option.0"]
            XCTAssertTrue(option.waitForExistence(timeout: 5)); option.tap()
            let next = app.buttons["game.next"]
            reveal(next, in: app); next.tap()
        }
        let save = app.buttons["game.next"]
        reveal(save, in: app); save.tap()
        XCTAssertTrue(app.staticTexts["这一刻的你。"].waitForExistence(timeout: 5))
        capture(app, name: "07-GameReport")
    }
    @MainActor func testOtherExplorationsAndValueReorder() {
        for title in ["价值观排序", "情绪识别", "边界感探索", "认知偏好", "优势发现"] {
            let app = launch()
            app.buttons["tab.INNER"].tap()
            let game = app.buttons.containing(.staticText, identifier: title).firstMatch
            reveal(game, in: app); game.tap()
            let start = app.buttons["game.start"]
            reveal(start, in: app); start.tap()
            if title == "价值观排序" {
                app.buttons["上移安全感"].tap()
                let next = app.buttons["game.next"]
                reveal(next, in: app); next.tap()
            } else {
                for _ in 0..<3 {
                    let option = app.buttons["game.option.0"]
                    XCTAssertTrue(option.waitForExistence(timeout: 5)); option.tap()
                    let next = app.buttons["game.next"]
                    reveal(next, in: app); next.tap()
                }
            }
            let save = app.buttons["game.next"]
            reveal(save, in: app); save.tap()
            XCTAssertTrue(app.staticTexts["这一刻的你。"].waitForExistence(timeout: 5))
            if title == "价值观排序" { XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "安全感、自由、成就")).firstMatch.exists) }
            app.terminate()
        }
    }
    @MainActor func testAddPerson() {
        let app = launch()
        app.buttons["tab.CONNECT"].tap()
        app.buttons["connections.add"].tap()
        app.textFields["person.name"].tap()
        app.textFields["person.name"].typeText("Alex")
        app.buttons["person.save"].tap()
        XCTAssertTrue(app.buttons["person.Alex"].waitForExistence(timeout: 5))
        app.buttons["person.Alex"].tap()
        reveal(app.buttons["sphere.details"], in: app)
        app.buttons["sphere.details"].tap()
        XCTAssertTrue(app.navigationBars["关系档案"].exists)
    }
}
