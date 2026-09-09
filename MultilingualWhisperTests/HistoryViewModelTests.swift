import XCTest
@testable import MultilingualWhisper

@MainActor
final class HistoryViewModelTests: XCTestCase {
    private let viewModel = HistoryViewModel()

    private func transcription(daysAgo: Int, text: String = "hello world") -> Transcription {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return Transcription(text: text, duration: 1, languageUsed: .english, modelUsed: .singlish, date: date)
    }

    func testWordsTodayOnlyCountsTodaysTranscriptions() {
        let transcriptions = [
            transcription(daysAgo: 0, text: "three words here"),
            transcription(daysAgo: 0, text: "two more"),
            transcription(daysAgo: 1, text: "yesterday doesn't count"),
        ]

        XCTAssertEqual(viewModel.wordsToday(transcriptions), 5)
    }

    func testWordsTodayIsZeroWithNoTranscriptionsToday() {
        XCTAssertEqual(viewModel.wordsToday([transcription(daysAgo: 2)]), 0)
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        let transcriptions = [transcription(daysAgo: 0), transcription(daysAgo: 1), transcription(daysAgo: 2)]
        XCTAssertEqual(viewModel.streak(transcriptions), 3)
    }

    func testStreakStillCountsThroughTodayBeforeAnythingSaidYet() {
        // Nothing dictated today yet, but yesterday and the day before were
        // both active - the streak shouldn't reset to zero just because
        // today hasn't happened yet.
        let transcriptions = [transcription(daysAgo: 1), transcription(daysAgo: 2)]
        XCTAssertEqual(viewModel.streak(transcriptions), 2)
    }

    func testStreakBreaksOnAGapDay() {
        let transcriptions = [transcription(daysAgo: 0), transcription(daysAgo: 2)]
        XCTAssertEqual(viewModel.streak(transcriptions), 1)
    }

    func testStreakIsZeroWithNoTranscriptions() {
        XCTAssertEqual(viewModel.streak([]), 0)
    }
}
