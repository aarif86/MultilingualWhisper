import XCTest
@testable import MultilingualWhisper

final class TranscriptSanitizerTests: XCTestCase {
    func testStripsSelfClosingAnnotationTags() {
        // Confirmed real output from the Singlish model on-device.
        XCTAssertEqual(TranscriptSanitizer.stripAnnotationTags("<SPK/> hello <NON/>"), "hello")
    }

    func testStripsNonSelfClosingPairedTags() {
        // Defensive: not yet observed from this model, but the same NSC
        // annotation convention allows a paired open/close form too.
        XCTAssertEqual(TranscriptSanitizer.stripAnnotationTags("<NON>silence</NON> hi"), "silence hi")
    }

    func testLeavesOrdinaryTextUntouched() {
        let text = "wallah jalan jalan cari makan lah"
        XCTAssertEqual(TranscriptSanitizer.stripAnnotationTags(text), text)
    }

    func testTagOnlySegmentBecomesEmpty() {
        XCTAssertEqual(TranscriptSanitizer.stripAnnotationTags("<NON/>"), "")
    }

    func testCollapsesWhitespaceLeftBehindByRemovedTags() {
        XCTAssertEqual(TranscriptSanitizer.stripAnnotationTags("hi <SPK/> <SPK/> there"), "hi there")
    }

    // MARK: - Bag of hallucinations

    private func drops(_ text: String, noSpeech: Float = 0, confidence: Float = 1) -> Bool {
        TranscriptSanitizer.isLikelyHallucination(text, noSpeechProbability: noSpeech, confidence: confidence)
    }

    func testHardHallucinationsAreDroppedEvenWhenConfident() {
        XCTAssertTrue(drops("Thank you for watching."))
        XCTAssertTrue(drops(" Thanks for watching! "))
        XCTAssertTrue(drops("Subtitles by the Amara.org community"))
        XCTAssertTrue(drops("Terima kasih kerana menonton."))
        XCTAssertTrue(drops("\u{062A}\u{0631}\u{062C}\u{0645}\u{0629} \u{0646}\u{0627}\u{0646}\u{0633}\u{064A} \u{0642}\u{0646}\u{0642}\u{0631}"))
        XCTAssertTrue(drops("Thanks for watching everyone, bye"), "a long credit phrase at the start is still the credit")
    }

    func testSoftHallucinationsNeedAnUnsureDecoder() {
        XCTAssertFalse(drops("Thank you."), "a confident 'thank you' is a real dictation")
        XCTAssertTrue(drops("Thank you.", noSpeech: 0.8))
        XCTAssertTrue(drops("you", confidence: 0.2))
        XCTAssertFalse(drops("Okay", noSpeech: 0.1, confidence: 0.9))
        XCTAssertTrue(drops("Terima kasih", noSpeech: 0.6))
    }

    func testOrdinaryTextIsNeverDropped() {
        XCTAssertFalse(drops("thank you for the kopi", noSpeech: 0.9, confidence: 0.1))
        XCTAssertFalse(drops("we go makan lah", noSpeech: 0.95, confidence: 0.1))
        XCTAssertFalse(drops("", noSpeech: 0.95))
        XCTAssertFalse(drops("subtitles are on", noSpeech: 0.9))
    }
}
