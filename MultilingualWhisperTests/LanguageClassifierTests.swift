import XCTest
@testable import MultilingualWhisper

final class LanguageClassifierTests: XCTestCase {
    private let classifier = RuleBasedLanguageClassifier()

    func testEmptyTextIsUnknown() {
        let result = classifier.classify(text: "   ")
        XCTAssertEqual(result.languageTag, .unknown)
        XCTAssertEqual(result.confidence, 0)
    }

    func testDominantArabicScriptRoutesToArabicModel() {
        let result = classifier.classify(text: "بسم الله الرحمن الرحيم الحمد لله رب العالمين")
        XCTAssertEqual(result.recommendedModel, .arabic)
        XCTAssertEqual(result.languageTag, .arabic)
        XCTAssertGreaterThan(result.confidence, 0.6)
        XCTAssertEqual(result.components, [.arabic])
    }

    func testEmbeddedRomanizedArabicPhraseStaysOnSinglishModelAndTagsMixed() {
        // Whisper's Singlish model is hinted to decode in Latin script, so a spoken
        // "Bismillah" comes back transliterated, not as Arabic script - this is the
        // spec's own example case, and also flow.nasar.sg's landing-page demo
        // phrase (Arabic + Malay + Singlish in one sentence).
        let result = classifier.classify(text: "Bismillah, let's go makan lah")
        XCTAssertEqual(result.recommendedModel, .singlish)
        XCTAssertEqual(result.languageTag, .mixed)
        // The badge should say what's actually being spoken, not a generic
        // "Mixed" - see LanguageBadge / LanguageClassification.components.
        XCTAssertEqual(result.components, [.arabic, .malay, .singlish])
    }

    func testRomanizedArabicPhraseAloneIsTaggedArabic() {
        let result = classifier.classify(text: "Bismillah, we are ready to begin")
        XCTAssertEqual(result.recommendedModel, .singlish)
        XCTAssertEqual(result.languageTag, .arabic)
    }

    func testMalayKeywordsAreTaggedMalay() {
        let result = classifier.classify(text: "Nak pergi makan tak? Jalan sekarang.")
        XCTAssertEqual(result.recommendedModel, .singlish)
        XCTAssertEqual(result.languageTag, .malay)
    }

    func testSinglishMarkersAreTaggedSinglish() {
        let result = classifier.classify(text: "Wah this one very shiok already lah")
        XCTAssertEqual(result.recommendedModel, .singlish)
        XCTAssertEqual(result.languageTag, .singlish)
    }

    func testMixedMalayAndSinglishIsTaggedMixed() {
        let result = classifier.classify(text: "Jalan already lah, tak boleh wait")
        XCTAssertEqual(result.languageTag, .mixed)
    }

    func testFlowNasarSgDemoPhraseTwoStaysOnSinglishModel() {
        // Exact demo phrase from flow.nasar.sg's landing page (Singlish + Malay).
        let result = classifier.classify(text: "Wah shiok sia, we go makan then balik house")
        XCTAssertEqual(result.recommendedModel, .singlish)
        XCTAssertEqual(result.languageTag, .mixed)
        XCTAssertEqual(result.components, [.malay, .singlish])
    }

    func testCodeSwitchedNarrationWithTrailingArabicPhraseStaysOnSinglishModel() {
        // Mirrors a real bug report: several clauses of Singlish/Malay narration
        // with just one Arabic/Islamic interjection near the end ("wallah") must
        // not be confidently routed away to the Arabic model - that model can't
        // handle the Singlish/Malay majority of the clip at all, and doing so
        // silently threw away a mostly-good transcript for a much worse one.
        let result = classifier.classify(text: "My name is Ariff already lah, jalan jalan cari makan sometimes wallah")
        XCTAssertEqual(result.recommendedModel, .singlish)
    }

    func testPlainEnglishFallsBackToLowConfidenceEnglish() {
        let result = classifier.classify(text: "The weather today is quite pleasant")
        XCTAssertEqual(result.recommendedModel, .singlish)
        XCTAssertEqual(result.languageTag, .english)
        XCTAssertLessThan(result.confidence, 0.5)
    }
}
