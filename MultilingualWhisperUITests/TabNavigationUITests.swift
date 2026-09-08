import XCTest

final class TabNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSwitchingToHistoryTabShowsHistoryScreen() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
    }

    func testSwitchingToSettingsTabShowsSettingsScreen() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Set Up Keyboard"].exists)
    }

    func testCanNavigateBackToTranscribeTabFromSettings() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Transcribe"].tap()
        XCTAssertTrue(app.buttons["Start recording"].waitForExistence(timeout: 5))
    }
}
