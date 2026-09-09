import XCTest
@testable import MultilingualWhisper

final class LearnedCorrectionsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: LearnedCorrectionsStore!

    override func setUp() {
        super.setUp()
        suiteName = "LearnedCorrectionsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = LearnedCorrectionsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testQueueStartsEmpty() {
        XCTAssertTrue(store.queued().isEmpty)
        XCTAssertTrue(store.drain().isEmpty)
    }

    func testEnqueueDedupesAndDrainEmpties() {
        let a = CorrectionLearner.Correction(heard: "Nassar", corrected: "Nasar")
        let b = CorrectionLearner.Correction(heard: "Tampinis", corrected: "Tampines")
        store.enqueue(a)
        store.enqueue(a)
        store.enqueue(b)
        XCTAssertEqual(store.queued(), [a, b])
        XCTAssertEqual(store.drain(), [a, b])
        XCTAssertTrue(store.queued().isEmpty)
    }

    func testQueueIsCapped() {
        for i in 0..<(LearnedCorrectionsStore.maxQueued + 5) {
            store.enqueue(.init(heard: "h\(i)", corrected: "c\(i)"))
        }
        let queue = store.queued()
        XCTAssertEqual(queue.count, LearnedCorrectionsStore.maxQueued)
        XCTAssertEqual(queue.first?.heard, "h5")
    }

    func testRecentInsertExpires() {
        let now = Date()
        store.rememberInsert("call Nassar back", at: now)
        XCTAssertEqual(store.recentInsert(now: now.addingTimeInterval(60)), "call Nassar back")
        XCTAssertNil(store.recentInsert(now: now.addingTimeInterval(LearnedCorrectionsStore.recentInsertWindow + 1)))
    }

    func testForgetInsert() {
        store.rememberInsert("x")
        store.forgetInsert()
        XCTAssertNil(store.recentInsert())
    }
}
