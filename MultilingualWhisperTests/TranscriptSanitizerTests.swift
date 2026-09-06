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
}
