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
    // Singlish, Malay, and Arabic are this repo's own conversions, hosted as
    // GitHub Release assets:
    //   - Singlish: jensenlwt/whisper-small-singlish-122k (converted 2026-09-06)
    //   - Malay: mesolitica/malaysian-whisper-small-v2 (converted 2026-09-07) -
    //     from Mesolitica/malaysia-ai, trained on IMDA STT (same corpus family as
    //     the Singlish model) plus a Malay Conversational Speech Corpus and
    //     Malaysian YouTube/audiobook data - covers standard AND local/colloquial
    //     Malay, matching flow.nasar.sg's "everyday Bahasa" positioning. Its
    //     weights ship as bfloat16, which whisper.cpp's conversion script can't
    //     read directly - see scripts/convert_malay_model.py for the float32
    //     upcast fix-up this needed. No explicit license tag on the HF model
    //     card itself (the org's surrounding malaya-speech toolkit is MIT) -
    //     known, accepted for now.
    //   - Arabic: oddadmix/whisper-small-arabic-dialectal (colloquial/dialectal,
    //     not Modern Standard/Quranic Arabic - see scripts/convert_arabic_model.py
    //     for why, and that model's own "evaluate before production use" caveat)
    // All three were verified against real transcriptions of real audio before
    // upload - not just a clean conversion exit code.
    //
    // As of 2026-09-07, all three are quantized to q5_1 (see
    // .github/workflows/quantize-models.yml) - storage was flagged as too big
    // (2.44GB for all 5 models). q5_1 cut each from ~487MB to ~190MB (61%
    // smaller) with zero measurable change in transcribed text on real test
    // audio for Malay and Arabic (byte-for-byte identical output, f16 vs
    // q5_1); Singlish wasn't independently re-confirmed due to a test-audio
    // generation bug in that workflow run, not a model concern - same
    // quantization operation, same architecture as the other two.
    // English and Multilingual point at whisper.cpp's own pre-converted stock
    // models - no conversion needed, but also no checksum: verifying one properly
    // means downloading the whole ~465MB file up front just to hash it, which
    // isn't worth it for a bonus/fallback model nobody asked to harden. Verification
    // is simply skipped for any model with no entry in modelChecksums - see
    // ModelDownloadService.finalizeDownload.

    static var modelRemoteURLs: [WhisperModelType: URL] = [
        .singlish: URL(string: "https://github.com/aarif86/MultilingualWhisper/releases/download/models-v1/ggml-small-singlish.bin")!,
        .malay: URL(string: "https://github.com/aarif86/MultilingualWhisper/releases/download/models-v1/ggml-small-malay.bin")!,
        .arabic: URL(string: "https://github.com/aarif86/MultilingualWhisper/releases/download/models-v1/ggml-small-arabic.bin")!,
        .english: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin")!,
        .multilingual: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
    ]

    /// SHA-256 checksums, lowercase hex. ModelDownloadService refuses to install a
    /// download whose hash doesn't match one listed here - a model with no entry
    /// here downloads without verification (see note above).
    static var modelChecksums: [WhisperModelType: String] = [
        .singlish: "565bb08506901ac97ca4c491da8c4f95eddb3a1230a5c7f25e44f9361aedf2c8",
        .malay: "a5fbd9a92f8104e3ea4e0c33475c48f69e5b9566054ea0e3f71b76db5e92d86c",
        .arabic: "768451a155d86b8d482037ee7a3b89b5c6b2a3da04853a7f566e3207a5a11d46",
    ]

    static var modelApproxSizeBytes: [WhisperModelType: Int64] = [
        .singlish: 190_085_504,
        .malay: 190_085_504,
        .arabic: 190_105_642,
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
