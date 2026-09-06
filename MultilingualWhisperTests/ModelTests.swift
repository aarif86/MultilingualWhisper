import XCTest
@testable import MultilingualWhisper

final class TranscriptionTests: XCTestCase {
    func testWordCountSplitsOnWhitespace() {
        let transcription = Transcription(
            text: "Bismillah, let's go makan lah",
            duration: 4.2,
            languageUsed: .mixed,
            modelUsed: .singlish
        )
        XCTAssertEqual(transcription.wordCount, 5)
    }

    func testWordCountOfEmptyTextIsZero() {
        let transcription = Transcription(text: "", duration: 0, languageUsed: .unknown, modelUsed: .singlish)
        XCTAssertEqual(transcription.wordCount, 0)
    }
}

final class WhisperModelTypeTests: XCTestCase {
    func testLanguageHintsMatchIntendedOrthography() {
        XCTAssertEqual(WhisperModelType.singlish.languageHint, "en")
        XCTAssertEqual(WhisperModelType.arabic.languageHint, "ar")
        XCTAssertEqual(WhisperModelType.english.languageHint, "en")
        XCTAssertNil(WhisperModelType.multilingual.languageHint)
    }

    func testLanguageModePinning() {
        XCTAssertNil(LanguageMode.auto.pinnedModel)
        XCTAssertEqual(LanguageMode.forceSinglish.pinnedModel, .singlish)
        XCTAssertEqual(LanguageMode.forceArabic.pinnedModel, .arabic)
        XCTAssertEqual(LanguageMode.forceEnglish.pinnedModel, .english)
        XCTAssertEqual(LanguageMode.multilingual.pinnedModel, .multilingual)
    }
}

final class AppSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultsMatchConstants() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.languageMode, .auto)
        XCTAssertEqual(settings.vadSensitivity, Constants.defaultVADThreshold)
        XCTAssertTrue(settings.autoPunctuation)
        XCTAssertTrue(settings.autoStopOnSilence)
    }

    func testChangesPersistAcrossInstances() {
        let first = AppSettings(defaults: defaults)
        first.languageMode = .forceArabic
        first.autoPunctuation = false
        first.vadSensitivity = 0.25

        let second = AppSettings(defaults: defaults)
        XCTAssertEqual(second.languageMode, .forceArabic)
        XCTAssertFalse(second.autoPunctuation)
        XCTAssertEqual(second.vadSensitivity, 0.25)
    }
}
