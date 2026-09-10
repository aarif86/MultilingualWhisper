import XCTest
@testable import MultilingualWhisper

final class ChatExportParserTests: XCTestCase {

    // MARK: - WhatsApp parsing

    func testParsesBasicMessagesWithSenderAndText() {
        let raw = """
        [1/1/24, 9:00:00 AM] Alice: hello there
        [1/1/24, 9:00:05 AM] Bob: hi back
        """
        let messages = ChatExportParser.parseWhatsApp(raw)
        XCTAssertEqual(messages, [
            .init(sender: "Alice", text: "hello there"),
            .init(sender: "Bob", text: "hi back"),
        ])
    }

    func testContinuationLinesJoinThePreviousMessage() {
        // WhatsApp wraps a multi-line message across several physical lines -
        // only a line matching the "[date, time] Sender:" prefix starts a new
        // message; anything else is a continuation of the one before it.
        let raw = """
        [1/1/24, 9:00:00 AM] Alice: first line
        second line
        third line
        """
        let messages = ChatExportParser.parseWhatsApp(raw)
        XCTAssertEqual(messages, [.init(sender: "Alice", text: "first line second line third line")])
    }

    func testSkipsMediaPlaceholdersAndSystemLines() {
        let raw = """
        [1/1/24, 9:00:00 AM] Alice: real message one
        [1/1/24, 9:00:05 AM] Alice: <Media omitted>
        [1/1/24, 9:00:10 AM] Bob: image omitted
        [1/1/24, 9:00:15 AM] Bob: This message was deleted
        [1/1/24, 9:00:20 AM] Alice: real message two
        """
        let messages = ChatExportParser.parseWhatsApp(raw)
        XCTAssertEqual(messages, [
            .init(sender: "Alice", text: "real message one"),
            .init(sender: "Alice", text: "real message two"),
        ])
    }

    func testHandlesDifferentDayAndMonthDigitCounts() {
        // WhatsApp doesn't zero-pad day/month, so "9/6/24" and "29/12/2024"
        // must both parse - a fixed-width assumption would silently drop
        // exactly the messages this feature exists to read.
        let raw = "[9/6/24, 1:58:17 PM] Alice: short date\n[29/12/2024, 11:05:00 PM] Bob: long date"
        let messages = ChatExportParser.parseWhatsApp(raw)
        XCTAssertEqual(messages.map(\.text), ["short date", "long date"])
    }

    // MARK: - Word frequency

    func testWordFrequencyCountsAndFiltersCommonEnglish() {
        let messages = [
            ChatExportParser.ParsedMessage(sender: "A", text: "dia tgh sibuk"),
            ChatExportParser.ParsedMessage(sender: "B", text: "dia tgh busy too"),
        ]
        let counts = Dictionary(uniqueKeysWithValues: ChatExportParser.wordFrequency(messages))
        XCTAssertEqual(counts["dia"], 2)
        XCTAssertEqual(counts["tgh"], 2)
        XCTAssertEqual(counts["sibuk"], 1)
        XCTAssertNil(counts["too"], "plain common English should be filtered out")
        XCTAssertNil(counts["busy"], "plain common English should be filtered out")
    }

    // MARK: - End-to-end analysis

    func testAnalyzeExcludesAlreadyKnownWordsFromCandidates() {
        let raw = "[1/1/24, 9:00:00 AM] Alice: dia tgh sibuk kejap"
        let result = ChatExportParser.analyze(
            rawWhatsAppText: raw,
            alreadyKnown: ["dia", "tgh"],
            classifier: RuleBasedLanguageClassifier()
        )
        let candidateWords = Set(result.candidates.map(\.word))
        XCTAssertFalse(candidateWords.contains("dia"), "already-known words shouldn't be suggested again")
        XCTAssertFalse(candidateWords.contains("tgh"))
        XCTAssertTrue(candidateWords.contains("sibuk"))
        XCTAssertTrue(candidateWords.contains("kejap"))
    }

    func testAnalyzeClassificationUsesTheRealClassifierNotAReimplementation() {
        // "dia tgh sibuk" only becomes recognizably Malay once the classifier
        // actually has "dia"/"tgh" in its keyword set - this proves analyze()
        // is calling the live RuleBasedLanguageClassifier (which does, as of
        // 2026-09-10), not some separate hardcoded simulation of it.
        let raw = "[1/1/24, 9:00:00 AM] Alice: dia tgh sibuk"
        let result = ChatExportParser.analyze(
            rawWhatsAppText: raw,
            alreadyKnown: [],
            classifier: RuleBasedLanguageClassifier()
        )
        XCTAssertEqual(result.totalMessages, 1)
        XCTAssertEqual(result.currentClassification[.malay], 1)
    }
}
