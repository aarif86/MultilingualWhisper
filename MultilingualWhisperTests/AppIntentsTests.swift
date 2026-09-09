import AppIntents
import XCTest
@testable import MultilingualWhisper

@MainActor
final class AppIntentsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppIntentRouter.shared.consume()
    }

    func testRouterStartsEmpty() {
        XCTAssertNil(AppIntentRouter.shared.pending)
    }

    func testRequestIsConsumedOnce() {
        let router = AppIntentRouter.shared
        router.request(.startFlow)
        XCTAssertEqual(router.pending, .startFlow)
        XCTAssertEqual(router.consume(), .startFlow)
        XCTAssertNil(router.consume())
    }

    func testSequenceAdvancesForRepeatedIdenticalRequests() {
        let router = AppIntentRouter.shared
        let before = router.sequence
        router.request(.dictate)
        router.request(.dictate)
        XCTAssertEqual(router.sequence, before + 2)
        router.consume()
    }

    func testDictateIntentQueuesADictateRequest() async throws {
        _ = try await DictateIntent().perform()
        XCTAssertEqual(AppIntentRouter.shared.consume(), .dictate)
    }

    func testFlowIntentsQueueTheirRequests() async throws {
        _ = try await StartFlowIntent().perform()
        XCTAssertEqual(AppIntentRouter.shared.consume(), .startFlow)
        _ = try await StopFlowIntent().perform()
        XCTAssertEqual(AppIntentRouter.shared.consume(), .stopFlow)
    }

    func testIntentsOpenTheApp() {
        // iOS only lets a foreground app start the microphone, so every intent
        // must foreground the app rather than run silently.
        XCTAssertTrue(DictateIntent.openAppWhenRun)
        XCTAssertTrue(StartFlowIntent.openAppWhenRun)
        XCTAssertTrue(StopFlowIntent.openAppWhenRun)
    }

    func testThreeShortcutsAreRegistered() {
        XCTAssertEqual(NasarFlowShortcuts.appShortcuts.count, 3)
    }
}
