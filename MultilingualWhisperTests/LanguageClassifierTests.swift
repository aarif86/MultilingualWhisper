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

    func testDominantMalayWithNoSinglishMarkersRoutesToMalayModel() {
        // Pure/dominant Malay (no Singlish particles alongside it) routes to the
        // dedicated Malay model, added 2026-09-07 - distinct from the embedded-
        // loanword case below, which stays on Singlish.
        let result = classifier.classify(text: "Nak pergi makan tak? Jalan sekarang.")
        XCTAssertEqual(result.recommendedModel, .malay)
        XCTAssertEqual(result.languageTag, .malay)
        XCTAssertEqual(result.components, [.malay])
    }

    func testSinglishMarkersAreTaggedSinglish() {
        let result = classifier.classify(text: "Wah this one very shiok already lah")
        XCTAssertEqual(result.recommendedModel, .singlish)
        XCTAssertEqual(result.languageTag, .singlish)
    }

    func testMixedMalayAndSinglishStaysOnSinglishModel() {
        // Malay *embedded* in Singlish speech (Singlish particles present too)
        // is a different case from dominant/pure Malay above - the Singlish
        // model already handles embedded Malay loanwords fine, so this must NOT
        // reroute to the dedicated Malay model, which would lose the English/
        // Singlish majority of the clip.
        let result = classifier.classify(text: "Jalan already lah, tak boleh wait")
        XCTAssertEqual(result.recommendedModel, .singlish)
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

    func testDominantMalayWithNoSinglishMarkersStillReachesFullConfidence() {
        // Companion to the ratio-dampening test below - a clip that's
        // genuinely all/mostly Malay must still reach a high enough
        // confidence to actually reroute, not get dampened along with it.
        let result = classifier.classify(text: "Nak pergi makan tak? Jalan sekarang.")
        XCTAssertGreaterThanOrEqual(result.confidence, 0.6)
    }

    func testMalayClauseInAnOtherwiseLongPlainEnglishSentenceDoesNotForceAWholeClipReroute() {
        // Real bug: a deliberate language switch (a plain-English clause with
        // no Singlish-specific slang, plus a short Malay clause) read as
        // confidently "dominant Malay" from raw keyword count alone, which
        // made WhisperService re-decode the ENTIRE clip with the Malay model
        // - clobbering the perfectly good English portion instead of letting
        // per-segment reprocessing isolate just the Malay clause. A short
        // embedded clause inside a much longer non-Malay utterance must stay
        // below WhisperService's 0.6 reroute threshold.
        let result = classifier.classify(text: "I finished my work at the office today and I want to jalan jalan cari makan")
        XCTAssertLessThan(result.confidence, 0.6)
    }

    func testPlainEnglishFallsBackToLowConfidenceEnglish() {
        let result = classifier.classify(text: "The weather today is quite pleasant")
        XCTAssertEqual(result.recommendedModel, .singlish)
        XCTAssertEqual(result.languageTag, .english)
        XCTAssertLessThan(result.confidence, 0.5)
    }
}
