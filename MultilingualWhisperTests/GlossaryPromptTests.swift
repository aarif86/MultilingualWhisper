import XCTest
@testable import MultilingualWhisper

final class GlossaryPromptTests: XCTestCase {
    private func entry(_ replacement: String, spoken: String = "x") -> DictionaryEntry {
        DictionaryEntry(original: spoken, replacement: replacement)
    }

    func testNewestEntriesFirstAsACommaList() {
        let prompt = GlossaryPrompt.build(from: [entry("Nasar"), entry("Tampines"), entry("MRT")])
        XCTAssertEqual(prompt, "MRT, Tampines, Nasar.")
    }

    func testEmptyDictionaryGivesNoPrompt() {
        XCTAssertNil(GlossaryPrompt.build(from: []))
        XCTAssertNil(GlossaryPrompt.build(from: [entry("  ")]))
    }

    func testDuplicatesAndMultilineFormsAreSkipped() {
        let prompt = GlossaryPrompt.build(from: [entry("Aly"), entry("aly"), entry("two\nlines"), entry("Aly")])
        XCTAssertEqual(prompt, "Aly.")
    }

    func testTermLimitKeepsTheNewest() {
        let entries = (1...50).map { entry("Term\($0)") }
        let prompt = GlossaryPrompt.build(from: entries, limit: 3)
        XCTAssertEqual(prompt, "Term50, Term49, Term48.")
    }

    func testCharacterBudgetStopsBeforeOverflowing() {
        let entries = (1...10).map { _ in entry(String(repeating: "x", count: 100)) }
        let prompt = GlossaryPrompt.build(from: entries.enumerated().map { entry("\($0.offset)" + $0.element.replacement) }, maxCharacters: 250)
        XCTAssertNotNil(prompt)
        XCTAssertLessThanOrEqual(prompt!.count, 250)
        XCTAssertEqual(prompt!.split(separator: ",").count, 2)
    }
}
