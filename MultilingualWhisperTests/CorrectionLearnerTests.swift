import XCTest
@testable import MultilingualWhisper

final class CorrectionLearnerTests: XCTestCase {
    private func learn(_ inserted: String, _ context: String) -> [(String, String)] {
        CorrectionLearner.corrections(inserted: inserted, context: context).map { ($0.heard, $0.corrected) }
    }

    private func assertLearned(_ inserted: String, _ context: String, _ expected: [(String, String)], file: StaticString = #filePath, line: UInt = #line) {
        let actual = learn(inserted, context)
        XCTAssertEqual(actual.count, expected.count, "\(actual)", file: file, line: line)
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a.0, e.0, file: file, line: line)
            XCTAssertEqual(a.1, e.1, file: file, line: line)
        }
    }

    // MARK: - Nothing to learn

    func testUntouchedInsertLearnsNothing() {
        assertLearned("call Nassar back", "I will call Nassar back", [])
        assertLearned("call Nassar back", "call Nassar back", [])
    }

    func testEmptyInputs() {
        assertLearned("", "anything", [])
        assertLearned("anything", "", [])
    }

    func testContentEditsAreNotCorrections() {
        assertLearned("we go now", "we come now", [])
        assertLearned("see you at five", "see you at nine", [])
    }

    func testPunctuationOnlyChangesAreIgnored() {
        assertLearned("can lah", "can lah!", [])
        assertLearned("hello world", "hello, world.", [])
    }

    func testDeletedInsertLearnsNothing() {
        assertLearned("call Nassar back", "I will", [])
    }

    // MARK: - Spelling corrections

    func testSingleWordMisspelling() {
        assertLearned("call Nassar back", "I will call Nasar back", [("Nassar", "Nasar")])
    }

    func testSingleWordInsertCorrectedInPlace() {
        assertLearned("Nassar", "Nasar", [("Nassar", "Nasar")])
        assertLearned("Nassar", "Hi Nasar", [("Nassar", "Nasar")])
    }

    func testTwoCorrectionsInOneInsert() {
        assertLearned("Nassar went to Tampinis", "Nasar went to Tampines", [("Nassar", "Nasar"), ("Tampinis", "Tampines")])
    }

    func testPhraseJoinedIntoOneWord() {
        assertLearned("insya Allah can", "insyaAllah can", [("insya Allah", "insyaAllah")])
    }

    func testWordSplitIntoPhrase() {
        assertLearned("we go alhamdulillah", "we go alhamdu lillah", [("alhamdulillah", "alhamdu lillah")])
    }

    func testCorrectionSurvivesTypingAfterwards() {
        assertLearned("call Nassar back", "please call Nasar back tomorrow", [("Nassar", "Nasar")])
    }

    func testDissimilarSwapInsideACorrectedLineIsSkipped() {
        assertLearned("call Nassar tonight", "call Nasar tomorrow", [("Nassar", "Nasar")])
    }

    // MARK: - Case

    func testCaseChangeIsLearned() {
        assertLearned("take the mrt home", "take the MRT home", [("mrt", "MRT")])
        assertLearned("my iphone died", "my iPhone died", [("iphone", "iPhone")])
    }

    func testSentenceInitialCapitalisationIsNotLearned() {
        assertLearned("we go makan", "We go makan", [])
        assertLearned("We go makan", "we go makan", [])
    }

    func testLoweringAMidSentenceCapitalIsLearned() {
        assertLearned("we go Makan", "we go makan", [("Makan", "makan")])
    }

    // MARK: - Arabic

    func testArabicSpellingCorrection() {
        assertLearned("قال انشالله", "قال إن شاء الله", [("انشالله", "إن شاء الله")])
    }

    // MARK: - Helpers

    func testSimilarityThreshold() {
        XCTAssertTrue(CorrectionLearner.isSpellingCorrection("Nassar", "Nasar"))
        XCTAssertTrue(CorrectionLearner.isSpellingCorrection("Tampinis", "Tampines"))
        XCTAssertFalse(CorrectionLearner.isSpellingCorrection("go", "come"))
        XCTAssertFalse(CorrectionLearner.isSpellingCorrection("a", "at"))
        XCTAssertFalse(CorrectionLearner.isSpellingCorrection("12", "13"))
        XCTAssertFalse(CorrectionLearner.isSpellingCorrection("same", "same"))
    }

    func testLevenshtein() {
        XCTAssertEqual(CorrectionLearner.levenshtein(Array("kitten"), Array("sitting")), 3)
        XCTAssertEqual(CorrectionLearner.levenshtein([], Array("ab")), 2)
        XCTAssertEqual(CorrectionLearner.levenshtein(Array("ab"), Array("ab")), 0)
    }

    func testWordsStripEdgePunctuationOnly() {
        XCTAssertEqual(CorrectionLearner.words("\"Hello,\" it's (me).").map(\.text), ["Hello", "it's", "me"])
    }
}
