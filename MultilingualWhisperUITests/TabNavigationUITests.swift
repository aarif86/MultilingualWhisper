import XCTest

final class TabNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSwitchingToDictionaryTabShowsDictionaryScreen() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Dictionary"].tap()
        XCTAssertTrue(app.navigationBars["Custom Dictionary"].waitForExistence(timeout: 5))
    }

    func testSwitchingToSettingsTabShowsSettingsScreen() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Set Up Keyboard"].exists)
    }

    func testCanNavigateBackToHomeTabFromSettings() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["Start recording"].waitForExistence(timeout: 5))
    }
}
