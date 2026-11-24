import XCTest

@MainActor final class ConnectionsProfileUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ flags: [String] = []) -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--uitesting", "--language=zh", "--appearance=light"] + flags
        app.launch(); app.buttons["tab.CONNECT"].tap()
        XCTAssertTrue(app.buttons["connections.add"].waitForExistence(timeout: 12)); return app
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication, sphere: Bool = false) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            if sphere { app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.79)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.27))) }
            else { app.swipeUp() }
        }
    }
    private func fill(_ id: String, _ value: String, _ app: XCUIApplication) {
        let field = app.textViews[id].exists ? app.textViews[id] : app.textFields[id]
        reveal(field, app); field.tap(); field.typeText(value)
        if app.buttons["person.keyboard.done"].exists { app.buttons["person.keyboard.done"].tap() }
    }
    private func shot(_ app: XCUIApplication, _ name: String) {
        let item = XCTAttachment(screenshot: app.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
    func testExpandedDemoAndColoredSphereInBothAppearances() {
        let app = launch()
        XCTAssertTrue((app.staticTexts["sphere.state"].value as? String ?? "").contains("nodes:28;"))
        shot(app, "Connect-28-Light")
        let sphere = app.otherElements["sphere.viewport"]
        sphere.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).press(forDuration: 0.05, thenDragTo: sphere.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.4)))
        shot(app, "Connect-28-Rotated")
        app.terminate(); app.launchArguments = ["--uitesting", "--language=en", "--appearance=dark"]; app.launch(); app.buttons["tab.CONNECT"].tap()
        XCTAssertTrue(app.staticTexts["sphere.state"].waitForExistence(timeout: 12)); shot(app, "Connect-28-Dark")
    }
    func testImportPreviewUncategorizedPhotosAndRepeatImport() {
        let app = launch(["--sphere-count=0", "--contacts-fixture"])
        app.buttons["connections.import"].tap(); app.buttons["contacts.choose"].tap()
        XCTAssertTrue(app.buttons["contacts.import"].waitForExistence(timeout: 8)); shot(app, "Contacts-Preview")
        app.buttons["contacts.import"].tap()
        XCTAssertTrue(app.staticTexts["contacts.result"].waitForExistence(timeout: 8))
        app.buttons["sphere.filter.未分类"].tap()
        XCTAssertTrue((app.staticTexts["sphere.state"].value as? String ?? "").contains("nodes:3;")); shot(app, "Connect-Imported-Avatars")
        app.buttons["connections.import"].tap(); app.buttons["contacts.choose"].tap()
        XCTAssertTrue(app.buttons["contacts.import"].waitForExistence(timeout: 8)); XCTAssertFalse(app.buttons["contacts.import"].isEnabled)
        app.buttons["取消"].tap()
        let person = app.buttons["connections.person.Alex Preview"]; reveal(person, app, sphere: true); person.tap()
        XCTAssertTrue(app.navigationBars["关系档案"].waitForExistence(timeout: 8)); shot(app, "Contact-Profile")
        app.buttons["person.edit"].tap()
        app.buttons["person.group"].tap(); app.buttons["家人"].tap()
        app.buttons["person.save"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["sphere.state"].waitForExistence(timeout: 8))
        XCTAssertTrue((app.staticTexts["sphere.state"].value as? String ?? "").contains("nodes:2;"))
    }
    func testAddRichProfileAndReload() {
        let app = launch(["--sphere-count=0"])
        app.buttons["connections.add"].tap(); fill("person.name", "朋友测试", app)
        let toggle = app.switches["person.hasCloseness"]; reveal(toggle, app); toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(app.sliders["person.closeness"].waitForExistence(timeout: 3))
        let slider = app.sliders["person.closeness"]; reveal(slider, app); slider.adjust(toNormalizedSliderPosition: 1)
        let birth = app.switches["person.hasBirthday"]; reveal(birth, app); birth.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        fill("person.likes", "咖啡、书店、散步", app)
        fill("person.dislikes", "很吵的餐厅", app)
        fill("person.careNotes", "约见前一天确认时间", app)
        app.buttons["person.save"].tap()
        XCTAssertTrue(app.buttons["connections.add"].waitForExistence(timeout: 8))
        let person = app.buttons["connections.person.朋友测试"]; reveal(person, app, sphere: true); person.tap()
        XCTAssertTrue(app.staticTexts["咖啡、书店、散步"].waitForExistence(timeout: 8)); shot(app, "Profile-Full")
        XCTAssertTrue(app.staticTexts["很亲密"].exists)
        app.terminate(); app.launchArguments = ["--uitesting", "--preserve-ui-data", "--language=zh", "--appearance=light"]; app.launch(); app.buttons["tab.CONNECT"].tap()
        app.buttons["sphere.filter.未分类"].tap()
        reveal(app.buttons["connections.person.朋友测试"], app, sphere: true); app.buttons["connections.person.朋友测试"].tap()
        XCTAssertTrue(app.staticTexts["咖啡、书店、散步"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["很亲密"].exists)
    }
    func testSystemContactPickerCanBeOpenedAndCancelled() {
        let app = launch(["--sphere-count=0"])
        app.buttons["connections.import"].tap(); app.buttons["contacts.choose"].tap()
        XCTAssertTrue(app.otherElements["contacts.systemPicker"].waitForExistence(timeout: 12)); shot(app, "Contacts-System-Picker")
        let cancel = app.buttons.matching(NSPredicate(format: "label == 'Cancel' OR label == '取消'")).firstMatch
        XCTAssertTrue(cancel.exists); cancel.tap()
        XCTAssertTrue(app.buttons["contacts.choose"].waitForExistence(timeout: 5))
    }
}
