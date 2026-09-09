import XCTest
@testable import MultilingualWhisper

final class TranscriptFormatterTests: XCTestCase {
    private func light(_ text: String) -> String { TranscriptFormatter.format(text, level: .light) }
    private func full(_ text: String) -> String { TranscriptFormatter.format(text, level: .full) }

    // MARK: - Levels

    func testRawReturnsTextUntouched() {
        let text = "  um, we go   tampines at three pm lah . "
        XCTAssertEqual(TranscriptFormatter.format(text, level: .raw), text)
    }

    func testLightCleansButDoesNotRewriteNumbers() {
        XCTAssertEqual(light("um, we go tampines at three pm lah ."), "We go tampines at three pm lah.")
    }

    func testFullAlsoNormalisesNumbers() {
        XCTAssertEqual(full("um, we go tampines at three pm lah ."), "We go tampines at 3pm lah.")
    }

    func testEmptyInput() {
        XCTAssertEqual(full(""), "")
        XCTAssertEqual(light("   "), "")
    }

    // MARK: - Fillers

    func testRemovesEnglishFillers() {
        let out = TranscriptFormatter.removeFillers("Um, so I think uh we can, um, go hmm now", words: TranscriptFormatter.defaultFillerWords)
        XCTAssertEqual(out, "so I think we can, go now")
    }

    func testFillerAtEndOfText() {
        XCTAssertEqual(light("we can go um"), "We can go")
    }

    func testDoesNotStripWordsThatContainAFiller() {
        XCTAssertEqual(light("the umbrella and the hummus"), "The umbrella and the hummus")
    }

    func testProtectsAffirmativeAnswers() {
        XCTAssertEqual(light("uh-huh, that's right"), "Uh-huh, that's right")
    }

    func testNeverStripsSinglishParticles() {
        XCTAssertEqual(light("can lah, can leh, can lor, can meh, can hor, can ah, eh you coming"), "Can lah, can leh, can lor, can meh, can hor, can ah, eh you coming")
    }

    func testCustomFillerListIsUsed() {
        let options = TranscriptFormatter.Options(removeFillers: true, inverseTextNormalization: false, normalizePunctuation: false, capitalizeSentences: false, fillerWords: ["basically"])
        XCTAssertEqual(TranscriptFormatter.format("so basically we go", options: options), "so we go")
    }

    // MARK: - Punctuation

    func testRemovesSpaceBeforePunctuationAndAddsAfterComma() {
        XCTAssertEqual(TranscriptFormatter.normalizePunctuation("hello , world .are you ok ?yes"), "hello, world.are you ok?yes")
        XCTAssertEqual(TranscriptFormatter.normalizePunctuation("a,b,c"), "a, b, c")
    }

    func testLeavesNumbersAndDomainsAlone() {
        XCTAssertEqual(TranscriptFormatter.normalizePunctuation("1,000 and 3.5 at nasar.sg"), "1,000 and 3.5 at nasar.sg")
    }

    func testAddsSpaceAfterSentenceEndBeforeACapitalisedWord() {
        XCTAssertEqual(TranscriptFormatter.normalizePunctuation("done.Next one!Go"), "done. Next one! Go")
        XCTAssertEqual(TranscriptFormatter.normalizePunctuation("U.S.A. today"), "U.S.A. today")
    }

    func testCollapsesDoubledCommasAndSpaces() {
        XCTAssertEqual(TranscriptFormatter.normalizePunctuation("one,, two ,  , three   four"), "one, two, three four")
    }

    func testArabicPunctuationSpacing() {
        XCTAssertEqual(TranscriptFormatter.normalizePunctuation("أهلا ، كيف حالك ؟"), "أهلا، كيف حالك؟")
    }

    // MARK: - Capitalisation

    func testCapitalisesSentenceStarts() {
        XCTAssertEqual(TranscriptFormatter.capitalizeSentences("hello. how are you? fine! great"), "Hello. How are you? Fine! Great")
    }

    func testCapitalisesAfterClosingQuote() {
        XCTAssertEqual(TranscriptFormatter.capitalizeSentences("he said \"go.\" then left"), "He said \"go.\" Then left")
    }

    func testCapitalisesLonePronounI() {
        XCTAssertEqual(TranscriptFormatter.capitalizeSentences("i think i can, i'm sure"), "I think I can, I'm sure")
        XCTAssertEqual(TranscriptFormatter.capitalizeSentences("hi, ini dia"), "Hi, ini dia")
    }

    func testLeavesArabicAlone() {
        let text = "مرحبا. كيف حالك؟ بخير"
        XCTAssertEqual(TranscriptFormatter.capitalizeSentences(text), text)
    }

    func testDoesNotLowercaseAnything() {
        XCTAssertEqual(TranscriptFormatter.capitalizeSentences("MRT is Fast"), "MRT is Fast")
    }

    // MARK: - Inverse text normalisation: numbers

    func testSmallSingleNumbersStayAsWords() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("I have two cats and one dog"), "I have two cats and one dog")
    }

    func testTenAndAboveBecomeDigits() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("I have ten cats and ninety hats"), "I have 10 cats and 90 hats")
    }

    func testCompoundNumbersBecomeDigits() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("twenty five people, three hundred and five chairs"), "25 people, 305 chairs")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("one thousand two hundred"), "1200")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("twenty-five"), "25")
    }

    func testArticleBeforeScaleWord() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("about a hundred people came"), "about 100 people came")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("a thousand thanks"), "1000 thanks")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("a one"), "a one")
    }

    func testSmallNumberBeforeAUnitBecomesDigits() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("wait two minutes for five kg"), "wait 2 minutes for 5 kg")
    }

    func testPunctuationEndsARun() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("twenty. five"), "20. five")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("(twenty five)"), "(25)")
    }

    func testPercent() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("fifty percent off, two percent more, 3 per cent"), "50% off, 2% more, 3%")
    }

    func testCurrency() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("five dollars"), "$5")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("twenty sing dollars and fifty singapore dollars"), "S$20 and S$50")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("ten us dollars, five bucks"), "$10, $5")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("dua puluh lima ringgit"), "RM25")
    }

    func testTimes() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("at three pm"), "at 3pm")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("at three thirty pm"), "at 3:30pm")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("at 3 p.m. and 10.15 AM"), "at 3pm and 10:15am")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("25 pm is not a time"), "25 pm is not a time")
    }

    func testDecimals() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("three point five kilos"), "3.5 kilos")
    }

    func testPhoneNumbers() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("call nine one two three four five six seven"), "call 91234567")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("flat 1 2 3"), "flat 1 2 3")
    }

    func testWebAddressesAndEmails() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("go to nasar dot sg"), "go to nasar.sg")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("www dot flow dot nasar dot sg"), "www.flow.nasar.sg")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("email aarif at gmail dot com now"), "email aarif@gmail.com now")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("see you at home"), "see you at home")
    }

    func testHashtags() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("post it hashtag nasarflow"), "post it #nasarflow")
    }

    func testMalayNumbers() {
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("lima belas peratus"), "15%")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("tiga ribu lima ratus orang"), "3500 orang")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("satu hari satu kali"), "satu hari satu kali")
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers("dalam dua minit"), "dalam 2 minit")
    }

    func testArabicTextPassesThroughNumberPass() {
        let text = "سأصل في الساعة الثالثة"
        XCTAssertEqual(TranscriptFormatter.normalizeNumbers(text), text)
    }

    // MARK: - End to end

    func testFullPipelineOnACodeSwitchedLine() {
        XCTAssertEqual(
            full("um so i will pay twenty five ringgit , then go makan at seven pm lah"),
            "So I will pay RM25, then go makan at 7pm lah"
        )
    }

    func testFillerSurroundedByCommasLeavesOneComma() {
        XCTAssertEqual(light("nasar said , uh , we go"), "Nasar said, we go")
    }
}
