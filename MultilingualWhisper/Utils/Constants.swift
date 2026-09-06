import CoreGraphics
import Foundation

/// Central, single-source-of-truth configuration for the app.
///
/// Anything a fork needs to change to make this their own build (bundle ID aside,
/// which lives in project.yml) should live here.
enum Constants {

    // MARK: - App identity

    // Visible product name (home screen, in-app header). The underlying bundle ID,
    // Xcode project/target, and GitHub repo stay "MultilingualWhisper" - renaming
    // those is a bigger, riskier operation (re-registering the Apple App ID,
    // re-issuing the provisioning profile, renaming the remote) for something end
    // users never see, so it's deliberately left alone unless asked for.
    static let appName = "Nasar Flow"
    static let appVersion = "1.0.0"

    // MARK: - Model hosting
    //
    // Singlish and Arabic are this repo's own conversions, hosted as GitHub
    // Release assets (converted 2026-09-06, verified against real whisper-cli.exe
    // transcriptions before upload - not just a clean conversion exit code):
    //   - Singlish: jensenlwt/whisper-small-singlish-122k
    //   - Arabic:   oddadmix/whisper-small-arabic-dialectal (colloquial/dialectal,
    //     not Modern Standard/Quranic Arabic - see scripts/convert_arabic_model.py
    //     for why, and that model's own "evaluate before production use" caveat)
    // English and Multilingual point at whisper.cpp's own pre-converted stock
    // models - no conversion needed, but also no checksum: verifying one properly
    // means downloading the whole ~465MB file up front just to hash it, which
    // isn't worth it for a bonus/fallback model nobody asked to harden. Verification
    // is simply skipped for any model with no entry in modelChecksums - see
    // ModelDownloadService.finalizeDownload.

    static var modelRemoteURLs: [WhisperModelType: URL] = [
        .singlish: URL(string: "https://github.com/aarif86/MultilingualWhisper/releases/download/models-v1/ggml-small-singlish.bin")!,
        .arabic: URL(string: "https://github.com/aarif86/MultilingualWhisper/releases/download/models-v1/ggml-small-arabic.bin")!,
        .english: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin")!,
        .multilingual: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
    ]

    /// SHA-256 checksums, lowercase hex. ModelDownloadService refuses to install a
    /// download whose hash doesn't match one listed here - a model with no entry
    /// here downloads without verification (see note above).
    static var modelChecksums: [WhisperModelType: String] = [
        .singlish: "d509f441ce1ee5926998f34f3b95ff5dd046e050c44ccd0d8e85c945acaf6801",
        .arabic: "d4a1ffc77291ee24bc3fae9d3801b38006ef40f4ae6ce86b070e0de33bd258ba",
    ]

    static var modelApproxSizeBytes: [WhisperModelType: Int64] = [
        .singlish: 487_601_984,
        .arabic: 487_622_122,
        .english: 487_614_201,
        .multilingual: 487_601_967,
    ]

    // MARK: - Audio

    /// Whisper is trained on 16kHz mono PCM. Everything upstream of WhisperEngine
    /// must resample to this rate.
    static let sampleRate: Double = 16_000
    static let chunkDurationSeconds: TimeInterval = 30
    static let defaultVADThreshold: Float = 0.7

    // MARK: - Language detection heuristics
    //
    // v1 language routing is rule-based (Arabic Unicode block detection + keyword
    // matching), not a trained classifier. See LanguageClassifier.swift.

    static let arabicKeywords: Set<String> = [
        "بسم", "الله", "الرحمن", "الرحيم", "الحمد", "سبحان", "السلام", "عليكم",
        "ماشاء", "استغفر", "الحمدلله", "ان شاء الله", "جزاك",
    ]

    /// Whisper's Singlish model is hinted to decode in Latin script (see
    /// `WhisperModelType.languageHint`), so a spoken Arabic/Islamic phrase like
    /// "Bismillah" comes back as the Latin transliteration "Bismillah", not Arabic
    /// script. Script-range detection alone would never catch that - these are the
    /// common transliterated forms so it still gets recognized as Arabic-influenced.
    static let romanizedArabicMarkers: Set<String> = [
        "bismillah", "alhamdulillah", "alhamdulillah", "insyaallah", "inshallah",
        "inshaallah", "mashallah", "masyaallah", "subhanallah", "astaghfirullah",
        "jazakallah", "wallahi", "wallah", "assalamualaikum", "salam", "walaikumsalam",
        "akhi", "ukhti", "ameen", "amin",
    ]

    /// Seeds whisper.cpp's decoder context (`initial_prompt`) so it's primed
    /// toward the exact colloquial vocabulary flow.nasar.sg advertises the app
    /// catching, instead of "correcting" unfamiliar slang toward standard
    /// English. A short, natural-sounding sentence biases both vocabulary and
    /// speaking style more effectively than a bare word list - deliberately
    /// written in the same code-switched style as the site's own demo phrases
    /// ("Bismillah, let's go makan lah" / "Wah shiok sia, we go makan then
    /// balik house"). Tradeoff worth knowing: priming can also make the decoder
    /// lean towards inserting one of these words in genuinely ambiguous audio -
    /// this needs real on-device testing to confirm it's a net win, not just
    /// code review.
    static let singlishInitialPrompt = "Wah shiok already lah, jalan jalan cari makan then balik house. Bismillah, insyaAllah can one."

    /// Same idea as `singlishInitialPrompt`, for the dedicated Arabic model -
    /// a short colloquial (not Quranic/MSA) religious phrase to bias it toward
    /// dialectal Arabic rather than Modern Standard Arabic.
    static let arabicInitialPrompt = "بسم الله الرحمن الرحيم، ان شاء الله، ما شاء الله."

    /// Threshold for `WhisperEngine.arabicLanguageProbability`'s use in
    /// `WhisperService.resolveDefaultModel` - a fast, audio-based pre-check that
    /// starts the two-pass auto-routing directly on the Arabic model instead of
    /// wasting a full Singlish pass first on clearly-Arabic audio. An initial
    /// estimate, not yet tuned against real audio (no device available when this
    /// was written) - see docs/code-switching-research.md Part 4.
    static let arabicPreCheckThreshold: Float = 0.5

    static let malayKeywords: Set<String> = [
        "makan", "minum", "jalan", "kampung", "balik", "pergi", "datang",
        "sudah", "belum", "tolong", "terima", "kasih", "selamat", "boleh",
        "tak", "nak", "mau", "rumah",
    ]

    static let singlishMarkers: Set<String> = [
        "lah", "leh", "lor", "sia", "wor", "meh", "already", "can", "cannot",
        "shiok", "alamak", "walao", "aiyo", "steady", "sian",
    ]

    // MARK: - UI

    static let recordButtonSize: CGFloat = 88
    static let cornerRadius: CGFloat = 12
    static let standardPadding: CGFloat = 16
}
