import XCTest

final class AppLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // A missing embedded framework (see whisper.xcframework's embed:true history
    // in project.yml) crashes the app before main() runs - no compiler/archive
    // step ever catches that, only an actual launch does. If that regresses,
    // this fails on timeout instead of TestFlight silently shipping a crash.
    func testAppLaunchesToHomeTabWithoutCrashing() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Start recording"].exists)
    }

    func testAllThreeTabsExist() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Dictionary"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
}
