import XCTest
@testable import MultilingualWhisper

final class DictionaryMatcherTests: XCTestCase {
    private func matcher(_ entries: [DictionaryEntry]) -> DictionaryMatcher {
        DictionaryMatcher(entries: entries)
    }

    private func entry(_ replacement: String, _ forms: String..., wholeWord: Bool = true, matchCase: Bool = false) -> DictionaryEntry {
        DictionaryEntry(replacement: replacement, spokenForms: forms, matchWholeWord: wholeWord, matchCase: matchCase)
    }

    // MARK: - Basics

    func testEmptyMatcherReturnsTextUnchanged() {
        let m = matcher([])
        XCTAssertTrue(m.isEmpty)
        XCTAssertEqual(m.apply(to: "wallah jalan jalan cari makan lah"), "wallah jalan jalan cari makan lah")
    }

    func testWholeWordCaseInsensitiveByDefault() {
        let m = matcher([entry("Nasar", "Nassar")])
        XCTAssertEqual(m.apply(to: "call NASSAR back"), "call Nasar back")
        XCTAssertEqual(m.apply(to: "Nassar, then nassar."), "Nasar, then Nasar.")
    }

    func testOutputIsCasedExactlyAsTheReplacement() {
        let m = matcher([entry("iPhone", "iphone")])
        XCTAssertEqual(m.apply(to: "IPHONE and Iphone"), "iPhone and iPhone")
    }

    func testDoesNotMatchInsideALongerWord() {
        let m = matcher([entry("shiok!", "shiok")])
        XCTAssertEqual(m.apply(to: "shiokness levels are high"), "shiokness levels are high")
        XCTAssertEqual(m.apply(to: "so shiok"), "so shiok!")
    }

    func testWholeWordOffMatchesInsideWords() {
        let m = matcher([entry("Dog", "cat", wholeWord: false)])
        XCTAssertEqual(m.apply(to: "caterpillar"), "Dogerpillar")
    }

    func testMatchCaseOnOnlyReplacesExactCase() {
        let m = matcher([entry("Nasar", "Nassar", matchCase: true)])
        XCTAssertEqual(m.apply(to: "Nassar and nassar"), "Nasar and nassar")
    }

    func testReplacementTemplateCharactersAreLiteral() {
        let m = matcher([entry("In Sha Allah, can do $1 \\ok", "insyaAllah can one")])
        XCTAssertEqual(m.apply(to: "wah insyaAllah can one lah"), "wah In Sha Allah, can do $1 \\ok lah")
    }

    func testSpokenFormRegexCharactersAreLiteral() {
        let m = matcher([entry("(brackets)", "(brackets)"), entry("a+b", "a+b")])
        XCTAssertEqual(m.apply(to: "say (brackets) and a+b now"), "say (brackets) and a+b now")
        XCTAssertEqual(m.apply(to: "say aab"), "say aab")
    }

    // MARK: - Many-to-one and ordering

    func testEveryspokenFormMapsToTheOneReplacement() {
        let m = matcher([entry("Nasar", "Nassar", "Nasser", "Nazar")])
        XCTAssertEqual(m.apply(to: "Nassar Nasser Nazar"), "Nasar Nasar Nasar")
    }

    func testLongestSpokenFormWinsAtTheSamePosition() {
        let m = matcher([entry("VoiceInk", "voice"), entry("VoiceInk Pro", "voice ink pro")])
        XCTAssertEqual(m.apply(to: "open voice ink pro"), "open VoiceInk Pro")
    }

    func testLongestWinsRegardlessOfEntryOrder() {
        let m = matcher([entry("A", "kampung"), entry("B", "kampung boy")])
        XCTAssertEqual(m.apply(to: "kampung boy"), "B")
        let reversed = matcher([entry("B", "kampung boy"), entry("A", "kampung")])
        XCTAssertEqual(reversed.apply(to: "kampung boy"), "B")
    }

    func testSinglePassNeverReMatchesAReplacementsOutput() {
        // "a" -> "b" and "b" -> "c" must not chain into "c".
        let m = matcher([entry("b", "a"), entry("c", "b")])
        XCTAssertEqual(m.apply(to: "a b"), "b c")
    }

    func testTiesKeepUserOrder() {
        let m = matcher([entry("First", "same"), entry("Second", "same")])
        XCTAssertEqual(m.apply(to: "same"), "First")
    }

    func testMultipleOccurrencesAllReplaced() {
        let m = matcher([entry("MRT", "m r t")])
        XCTAssertEqual(m.apply(to: "take m r t to the m r t station"), "take MRT to the MRT station")
    }

    // MARK: - Whitespace and punctuation

    func testInternalWhitespaceIsFlexible() {
        let m = matcher([entry("insyaAllah", "insya Allah")])
        XCTAssertEqual(m.apply(to: "insya  Allah and insya\nAllah"), "insyaAllah and insyaAllah")
    }

    func testEntriesStartingOrEndingWithPunctuationStillMatchWholeWord() {
        let m = matcher([entry(".com", "dot com"), entry("@", "at sign")])
        XCTAssertEqual(m.apply(to: "nasar dot com at sign"), "nasar .com @")
    }

    func testWholeWordBoundaryRespectsDigitsAndUnderscore() {
        let m = matcher([entry("Ali", "ali")])
        XCTAssertEqual(m.apply(to: "ali1 ali_x ali"), "ali1 ali_x Ali")
    }

    func testAdjacentPunctuationIsNotPartOfTheWord() {
        let m = matcher([entry("lah", "la")])
        XCTAssertEqual(m.apply(to: "can la, can la!"), "can lah, can lah!")
    }

    // MARK: - Arabic

    func testArabicWholeWordMatchesWithPunctuation() {
        let m = matcher([entry("إن شاء الله", "انشالله")])
        XCTAssertEqual(m.apply(to: "انشالله، نراك غدا"), "إن شاء الله، نراك غدا")
    }

    func testArabicDiacriticsInTheTranscriptAreTolerated() {
        // Transcript carries fatha/damma; the entry does not.
        let m = matcher([entry("الحمد لله", "الحمدلله")])
        XCTAssertEqual(m.apply(to: "قال الْحَمْدُلِلَّهِ ثم ذهب"), "قال الحمد لله ثم ذهب")
    }

    func testArabicDiacriticsInTheEntryAreIgnoredForMatching() {
        let m = matcher([entry("محمد", "مُحَمَّد")])
        XCTAssertEqual(m.apply(to: "اسمه محمد"), "اسمه محمد")
        XCTAssertEqual(m.apply(to: "اسمه مُحَمَّد"), "اسمه محمد")
    }

    func testAlefVariantsAreTreatedAsOneLetter() {
        let m = matcher([entry("أحمد", "احمد")])
        XCTAssertEqual(m.apply(to: "جاء احمد و أحمد و إحمد"), "جاء أحمد و أحمد و أحمد")
    }

    func testAlefMaqsuraAndYaAreTreatedAsOneLetter() {
        let m = matcher([entry("علي", "على")])
        XCTAssertEqual(m.apply(to: "ذهب على وعلي"), "ذهب علي وعلي")
    }

    func testArabicWholeWordDoesNotMatchInsideAttachedClitic() {
        // "والله" is و + الله; whole-word (the default) must leave it alone.
        let m = matcher([entry("Allah", "الله")])
        XCTAssertEqual(m.apply(to: "والله"), "والله")
        XCTAssertEqual(m.apply(to: "و الله"), "و Allah")
    }

    func testArabicWholeWordOffMatchesInsideAttachedClitic() {
        let m = matcher([entry("Allah", "الله", wholeWord: false)])
        XCTAssertEqual(m.apply(to: "والله"), "وAllah")
    }

    // MARK: - Mixed script

    func testCodeSwitchedLineWithLatinAndArabicEntries() {
        let m = matcher([entry("Nasar", "Nassar"), entry("الحمد لله", "الحمدلله")])
        XCTAssertEqual(m.apply(to: "Nassar said الحمدلله lah"), "Nasar said الحمد لله lah")
    }

    // MARK: - Scale

    func testHundredsOfEntriesStillApplyInOnePass() {
        var entries: [DictionaryEntry] = []
        for i in 0..<500 {
            entries.append(entry("Word\(i)", "word\(i)"))
        }
        let m = matcher(entries)
        XCTAssertEqual(m.apply(to: "word0 word250 word499 word500"), "Word0 Word250 Word499 word500")
    }
}
