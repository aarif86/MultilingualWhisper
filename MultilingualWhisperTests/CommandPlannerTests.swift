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

    // MARK: - Change X to Y

    func testReplaceRewritesTheLastOccurrenceAndRetypesTheTail() {
        XCTAssertEqual(
            plan(.replace(target: "tea", replacement: "tee"), before: "I had tea and then tea again"),
            [.deleteBackward(9), .insertRaw("tee again")]
        )
        XCTAssertEqual(plan(.replace(target: "tea", replacement: "tee"), before: "some tea"), [.deleteBackward(3), .insertRaw("tee")])
    }

    func testReplaceMatchesWholeWordsOnly() {
        XCTAssertEqual(plan(.replace(target: "tea", replacement: "tee"), before: "teacher"), [])
        XCTAssertEqual(plan(.replace(target: "tea", replacement: "tee"), before: "steam tea."), [.deleteBackward(4), .insertRaw("tee.")])
    }

    func testReplaceCopiesTheTargetsCase() {
        XCTAssertEqual(plan(.replace(target: "tampines", replacement: "tampines"), before: "go to Tampines now"), [.deleteBackward(12), .insertRaw("Tampines now")])
        XCTAssertEqual(plan(.replace(target: "ali", replacement: "aly"), before: "Ali said"), [.deleteBackward(8), .insertRaw("Aly said")])
        XCTAssertEqual(plan(.replace(target: "mrt", replacement: "lrt"), before: "take the MRT"), [.deleteBackward(3), .insertRaw("LRT")])
        XCTAssertEqual(plan(.replace(target: "lrt", replacement: "MRT"), before: "take the lrt"), [.deleteBackward(3), .insertRaw("MRT")])
    }

    func testReplaceMultiWordTargetAndNotFound() {
        XCTAssertEqual(plan(.replace(target: "we go", replacement: "we went"), before: "yesterday we go makan"), [.deleteBackward(11), .insertRaw("we went makan")])
        XCTAssertEqual(plan(.replace(target: "kopi", replacement: "teh"), before: "we go makan"), [])
        XCTAssertEqual(plan(.replace(target: "kopi", replacement: "teh"), before: ""), [])
    }

    func testReplaceIsCaseAndDiacriticInsensitiveOnTheTarget() {
        XCTAssertEqual(plan(.replace(target: "Tea", replacement: "tee"), before: "a TEA"), [.deleteBackward(3), .insertRaw("TEE")])
        XCTAssertEqual(plan(.replace(target: "cafe", replacement: "kopitiam"), before: "the caf\u{00E9}"), [.deleteBackward(4), .insertRaw("kopitiam")])
    }

    func testSpellGoesThroughTheDictationPath() {
        XCTAssertEqual(plan(.spell("Aly"), before: "hi"), [.insertDictation("Aly")])
    }

    // MARK: - Literal

    func testLiteralGoesThroughTheDictationPath() {
        XCTAssertEqual(plan(.literal("new line"), before: "x"), [.insertDictation("new line")])
        XCTAssertEqual(plan(.literal(""), before: "x"), [])
    }
}
