import XCTest
@testable import MultilingualWhisper

final class InsertionPolicyTests: XCTestCase {
    private func plan(_ raw: String, before: String? = nil, after: String? = nil, selected: String? = nil) -> String {
        InsertionPolicy.plan(inserting: raw, before: before, after: after, selected: selected).text
    }

    // MARK: - Empty and whitespace

    func testEmptyOrWhitespaceInsertsNothing() {
        XCTAssertEqual(plan(""), "")
        XCTAssertEqual(plan("   \n"), "")
        XCTAssertEqual(plan("  hello  "), "Hello")
    }

    // MARK: - Leading space

    func testNoLeadingSpaceInAnEmptyField() {
        XCTAssertEqual(plan("hello"), "Hello")
        XCTAssertEqual(plan("hello", before: ""), "Hello")
    }

    func testLeadingSpaceAfterAWord() {
        XCTAssertEqual(plan("we go makan", before: "I think"), " we go makan")
        XCTAssertEqual(plan("can lah", before: "Sure"), " can lah")
    }

    func testNoLeadingSpaceAfterWhitespaceOrNewline() {
        XCTAssertEqual(plan("we go", before: "I think "), "we go")
        XCTAssertEqual(plan("we go", before: "Notes:\n"), "We go")
    }

    func testNoLeadingSpaceAfterOpeningBracketQuoteOrPrefixSymbol() {
        XCTAssertEqual(plan("hello", before: "He said \""), "Hello")
        XCTAssertEqual(plan("hello", before: "("), "Hello")
        XCTAssertEqual(plan("nasarflow", before: "#"), "nasarflow")
        XCTAssertEqual(plan("aarif", before: "@"), "aarif")
    }

    func testSpaceAfterAClosingQuote() {
        XCTAssertEqual(plan("we go makan", before: "Really?\""), " We go makan")
        XCTAssertEqual(plan("he said", before: "\"Okay\""), " he said")
    }

    func testNoLeadingSpaceWhenDictationStartsWithPunctuation() {
        XCTAssertEqual(plan(", and then we go", before: "First"), ", and then we go")
        XCTAssertEqual(plan("? really", before: "You sure"), "? really")
    }

    // MARK: - Trailing space

    func testTrailingSpaceBeforeAWord() {
        XCTAssertEqual(plan("quickly", before: "run ", after: "home"), "quickly ")
        XCTAssertEqual(plan("quickly", before: "run", after: "home"), " quickly ")
    }

    func testNoTrailingSpaceBeforeSpacePunctuationOrEnd() {
        XCTAssertEqual(plan("quickly", before: "run ", after: " home"), "quickly")
        XCTAssertEqual(plan("quickly", before: "run ", after: ", then"), "quickly")
        XCTAssertEqual(plan("quickly", before: "run ", after: ""), "quickly")
        XCTAssertEqual(plan("quickly", before: "run ", after: nil), "quickly")
    }

    // MARK: - Capitalisation

    func testCapitalisesAtStartOfFieldAndAfterSentenceEnd() {
        XCTAssertEqual(plan("we go makan"), "We go makan")
        XCTAssertEqual(plan("we go makan", before: "Done."), " We go makan")
        XCTAssertEqual(plan("we go makan", before: "Done! "), "We go makan")
        XCTAssertEqual(plan("we go makan", before: "Line one\n"), "We go makan")
    }

    func testDoesNotCapitaliseMidSentence() {
        XCTAssertEqual(plan("we go makan", before: "I think"), " we go makan")
        XCTAssertEqual(plan("first line\nsecond line", before: "Notes:"), " first line\nsecond line")
    }

    func testLowercasesSentenceOnlyWordsMidSentence() {
        XCTAssertEqual(plan("We go makan", before: "I think"), " we go makan")
        XCTAssertEqual(plan("The bus is late", before: "and"), " the bus is late")
        XCTAssertEqual(plan("Saya nak balik", before: "lepas tu"), " saya nak balik")
    }

    func testKeepsNamesAcronymsAndPronounIMidSentence() {
        XCTAssertEqual(plan("Nasar said yes", before: "and"), " Nasar said yes")
        XCTAssertEqual(plan("MRT is down", before: "the"), " MRT is down")
        XCTAssertEqual(plan("I think so", before: "and"), " I think so")
        XCTAssertEqual(plan("Tampines later", before: "go"), " Tampines later")
    }

    func testDoesNotTouchScriptsWithoutCase() {
        XCTAssertEqual(plan("مرحبا", before: "قال."), " مرحبا")
        XCTAssertEqual(plan("مرحبا", before: "ثم"), " مرحبا")
    }

    func testDoesNotTouchCaseWhenFirstCharacterIsNotALetter() {
        XCTAssertEqual(plan("3pm works"), "3pm works")
        XCTAssertEqual(plan("$5 only", before: "It's"), " $5 only")
    }

    // MARK: - Selection

    func testReplacingASelectionIsReportedAndSpacedForItsNeighbours() {
        let result = InsertionPolicy.plan(inserting: "tomorrow", before: "See you ", after: " then", selected: "today")
        XCTAssertEqual(result.text, "tomorrow")
        XCTAssertTrue(result.replacesSelection)
        XCTAssertFalse(InsertionPolicy.plan(inserting: "x", before: "", after: "", selected: nil).replacesSelection)
        XCTAssertFalse(InsertionPolicy.plan(inserting: "x", before: "", after: "", selected: "").replacesSelection)
    }

    // MARK: - Helpers

    func testStartsNewSentenceHelper() {
        XCTAssertTrue(InsertionPolicy.startsNewSentence(leftContext: ""))
        XCTAssertTrue(InsertionPolicy.startsNewSentence(leftContext: "Done. "))
        XCTAssertTrue(InsertionPolicy.startsNewSentence(leftContext: "Done?\" "))
        XCTAssertTrue(InsertionPolicy.startsNewSentence(leftContext: "title\n"))
        XCTAssertTrue(InsertionPolicy.startsNewSentence(leftContext: "He said \""))
        XCTAssertTrue(InsertionPolicy.startsNewSentence(leftContext: "("))
        XCTAssertFalse(InsertionPolicy.startsNewSentence(leftContext: "Done, "))
        XCTAssertFalse(InsertionPolicy.startsNewSentence(leftContext: "e.g"))
        XCTAssertFalse(InsertionPolicy.startsNewSentence(leftContext: "\"Okay\""))
    }
}
