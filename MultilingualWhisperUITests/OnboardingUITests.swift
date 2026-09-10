import XCTest

/// The three first-run screens: shown on a fresh install, walked with Continue,
/// dismissed onto Home, and not shown again on the next launch. The microphone
/// button is deliberately never tapped - that raises a system prompt the
/// Simulator cannot answer non-interactively.
final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFirstLaunchWalksThreeScreensThenLandsOnHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome to Nasar Flow"].waitForExistence(timeout: 10))
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.exists)

        next.tap()
        XCTAssertTrue(app.staticTexts["Pick your starting model"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.download.singlish"].exists)

        next.tap()
        XCTAssertTrue(app.staticTexts["Dictate in every app"].waitForExistence(timeout: 5))
        XCTAssertEqual(next.label, "Start dictating")

        next.tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Welcome to Nasar Flow"].exists)
    }

    func testSkipGoesStraightToHomeAndStaysDismissedOnRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding"]
        app.launch()

        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 10))
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Welcome to Nasar Flow"].exists)
    }
}
