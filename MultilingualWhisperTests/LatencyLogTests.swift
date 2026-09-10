import XCTest
@testable import MultilingualWhisper

final class LatencyLogTests: XCTestCase {
    private var log: LatencyLog!

    override func setUp() {
        super.setUp()
        log = LatencyLog(defaults: UserDefaults(suiteName: "LatencyLogTests-\(UUID())")!)
    }

    private func timings(source: String = "flow", capture: TimeInterval = 3, decode: TimeInterval = 0.7, format: TimeInterval = 0.003, at: Date = Date()) -> StageTimings {
        StageTimings(recordedAt: at, source: source, capture: capture, decode: decode, format: format, handoff: nil)
    }

    // MARK: - Percentiles

    func testNearestRankPercentile() {
        let values: [TimeInterval] = [5, 1, 4, 2, 3]
        XCTAssertEqual(LatencyLog.percentile(values, 0.5), 3)
        XCTAssertEqual(LatencyLog.percentile(values, 0.95), 5)
        XCTAssertEqual(LatencyLog.percentile(values, 0), 1)
        XCTAssertEqual(LatencyLog.percentile([7], 0.5), 7)
        XCTAssertNil(LatencyLog.percentile([], 0.5))
    }

    func testFormatting() {
        XCTAssertEqual(LatencyLog.format(0.003), "3ms")
        XCTAssertEqual(LatencyLog.format(0.0996), "100ms")
        XCTAssertEqual(LatencyLog.format(0.74), "0.74s")
        XCTAssertEqual(LatencyLog.format(12), "12.00s")
    }

    // MARK: - Recording

    func testRecordKeepsTheNewestFiftyOnly() {
        for i in 0..<(LatencyLog.maxEntries + 5) {
            log.record(timings(capture: TimeInterval(i)))
        }
        let all = log.entries()
        XCTAssertEqual(all.count, LatencyLog.maxEntries)
        XCTAssertEqual(all.first?.capture, 5)
        XCTAssertEqual(all.last?.capture, TimeInterval(LatencyLog.maxEntries + 4))
    }

    func testHandoffAttachesToTheNewestKeyboardDictationWithoutOne() {
        log.record(timings(source: "app", capture: 1))
        log.record(timings(source: "flow", capture: 2))
        log.record(timings(source: "flow", capture: 3))

        log.recordHandoff(0.25)
        var all = log.entries()
        XCTAssertEqual(all[2].handoff, 0.25)
        XCTAssertNil(all[1].handoff)

        log.recordHandoff(0.5)
        all = log.entries()
        XCTAssertEqual(all[1].handoff, 0.5, "the next report goes to the older entry still missing one")
        XCTAssertNil(all[0].handoff, "in-app recordings never get a hand-off")
    }

    func testHandoffIgnoredWhenNothingRecentIsWaiting() {
        log.recordHandoff(0.2)
        XCTAssertTrue(log.entries().isEmpty)

        log.record(timings(at: Date(timeIntervalSinceNow: -LatencyLog.maxHandoffAge - 60)))
        log.recordHandoff(0.2)
        XCTAssertNil(log.entries()[0].handoff, "a stale entry is not the one being inserted now")
    }

    func testNegativeHandoffIsClampedToZero() {
        log.record(timings())
        log.recordHandoff(-0.1)
        XCTAssertEqual(log.entries()[0].handoff, 0)
    }

    // MARK: - Summary

    func testSummaryIsNilUntilSomethingIsRecorded() {
        XCTAssertNil(log.summary())
    }

    func testSummaryListsEveryStageWithMedianAndP95() {
        log.record(timings(capture: 2, decode: 0.5, format: 0.002))
        log.record(timings(capture: 4, decode: 1.5, format: 0.004))
        log.recordHandoff(0.2)
        let summary = log.summary()!
        XCTAssertTrue(summary.hasPrefix("2 dictations"), summary)
        XCTAssertTrue(summary.contains("capture p50 2.00s p95 4.00s"), summary)
        XCTAssertTrue(summary.contains("decode p50 0.50s p95 1.50s"), summary)
        XCTAssertTrue(summary.contains("format p50 2ms p95 4ms"), summary)
        XCTAssertTrue(summary.contains("handoff p50 0.20s p95 0.20s"), summary)
    }

    func testSummaryOmitsHandoffWhenNoneReported() {
        log.record(timings(source: "app"))
        XCTAssertFalse(log.summary()!.contains("handoff"))
        XCTAssertTrue(log.summary()!.hasPrefix("1 dictation "))
    }

    func testLineAndClear() {
        var stage = timings(capture: 3.2, decode: 0.74, format: 0.003)
        XCTAssertEqual(stage.line, "capture 3.20s \u{00B7} decode 0.74s \u{00B7} format 3ms")
        stage.handoff = 0.21
        XCTAssertTrue(stage.line.hasSuffix("handoff 0.21s"))

        log.record(stage)
        log.clear()
        XCTAssertTrue(log.entries().isEmpty)
    }
}
