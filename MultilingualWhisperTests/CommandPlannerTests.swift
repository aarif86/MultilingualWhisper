import XCTest
@testable import MultilingualWhisper

final class CommandPlannerTests: XCTestCase {
    private func plan(_ command: VoiceCommand, before: String, last: String? = nil) -> [CommandPlanner.EditOp] {
        CommandPlanner.plan(command, contextBefore: before, lastInserted: last)
    }

    func testNewLineAndParagraph() {
        XCTAssertEqual(plan(.newLine, before: "hello"), [.insertRaw("\n")])
        XCTAssertEqual(plan(.newParagraph, before: "hello"), [.insertRaw("\n\n")])
    }

    // MARK: - Deleting

    func testDeleteThatRemovesTheLastInsertWhenStillAtTheCursor() {
        XCTAssertEqual(plan(.deleteThat, before: "I think we go makan", last: " we go makan"), [.deleteBackward(12)])
    }

    func testDeleteThatFallsBackToLastWordWhenTheInsertWasEdited() {
        XCTAssertEqual(plan(.deleteThat, before: "I think we go makan lah", last: " we go makan"), [.deleteBackward(4)])
        XCTAssertEqual(plan(.deleteThat, before: "hello world", last: nil), [.deleteBackward(6)])
    }

    func testDeleteWordTakesTrailingSpacesWithIt() {
        XCTAssertEqual(plan(.deleteWord, before: "hello world"), [.deleteBackward(6)])
        XCTAssertEqual(plan(.deleteWord, before: "hello world  "), [.deleteBackward(8)])
        XCTAssertEqual(plan(.deleteWord, before: "world"), [.deleteBackward(5)])
        XCTAssertEqual(plan(.deleteWord, before: ""), [])
    }

    func testDeleteWordStopsAtANewline() {
        XCTAssertEqual(plan(.deleteWord, before: "line one\nworld"), [.deleteBackward(5)])
    }

    func testDeleteLine() {
        XCTAssertEqual(plan(.deleteLine, before: "first\nsecond line"), [.deleteBackward(11)])
        XCTAssertEqual(plan(.deleteLine, before: "only"), [.deleteBackward(4)])
        XCTAssertEqual(plan(.deleteLine, before: "first\n"), [.deleteBackward(1)], "an empty line removes the newline")
        XCTAssertEqual(plan(.deleteLine, before: ""), [])
    }

    // MARK: - Punctuation

    func testPunctuationAttachesToThePreviousWord() {
        XCTAssertEqual(plan(.period, before: "we go makan"), [.insertRaw(".")])
        XCTAssertEqual(plan(.period, before: "we go makan "), [.deleteBackward(1), .insertRaw(".")])
        XCTAssertEqual(plan(.comma, before: "first  "), [.deleteBackward(2), .insertRaw(",")])
        XCTAssertEqual(plan(.questionMark, before: "really"), [.insertRaw("?")])
        XCTAssertEqual(plan(.exclamationMark, before: "wah"), [.insertRaw("!")])
    }

    // MARK: - Case

    func testCapitaliseThatOnLastInsert() {
        XCTAssertEqual(plan(.capitaliseThat, before: "go to tampines", last: "tampines"), [.deleteBackward(8), .insertRaw("Tampines")])
    }

    func testCapitaliseThatOnLastWordWhenNoInsert() {
        XCTAssertEqual(plan(.capitaliseThat, before: "go to tampines"), [.deleteBackward(8), .insertRaw("Tampines")])
    }

    func testAllCapsAndLowercase() {
        XCTAssertEqual(plan(.allCapsThat, before: "take the mrt"), [.deleteBackward(3), .insertRaw("MRT")])
        XCTAssertEqual(plan(.lowercaseThat, before: "take the MRT"), [.deleteBackward(3), .insertRaw("mrt")])
    }

    func testRecaseIsANoOpWhenNothingChanges() {
        XCTAssertEqual(plan(.capitaliseThat, before: "go to Tampines"), [])
        XCTAssertEqual(plan(.allCapsThat, before: "MRT"), [])
        XCTAssertEqual(plan(.capitaliseThat, before: ""), [])
    }

    func testRecaseLeavesArabicAlone() {
        XCTAssertEqual(plan(.capitaliseThat, before: "قال مرحبا"), [])
    }

    // MARK: - Literal

    func testLiteralGoesThroughTheDictationPath() {
        XCTAssertEqual(plan(.literal("new line"), before: "x"), [.insertDictation("new line")])
        XCTAssertEqual(plan(.literal(""), before: "x"), [])
    }
}
