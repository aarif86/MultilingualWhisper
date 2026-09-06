import CoreGraphics
import Foundation

/// Central, single-source-of-truth configuration for the app.
///
/// Anything a fork needs to change to make this their own build (bundle ID aside,
/// which lives in project.yml) should live here.
enum Constants {

    // MARK: - App identity

    static let appName = "Multilingual Whisper"
    static let appVersion = "1.0.0"

    // MARK: - Model hosting
    //
    // These are NOT real, working URLs. Whisper GGML models are 250MB-1GB+ each,
    // far too large to bundle in the app or commit to git. Host the converted
    // .bin files yourself (GitHub Releases works well and is free up to 2GB/file)
    // and replace these placeholders before shipping. See scripts/ and README.md
    // for the conversion + hosting steps.

    static let modelDownloadBaseURL = "https://github.com/REPLACE_ME/MultilingualWhisper/releases/download/models-v1"

    static var modelRemoteURLs: [WhisperModelType: URL] = [
        .singlish: URL(string: "\(modelDownloadBaseURL)/ggml-small-singlish.bin")!,
        .arabic: URL(string: "\(modelDownloadBaseURL)/ggml-small-arabic.bin")!,
        .english: URL(string: "\(modelDownloadBaseURL)/ggml-small.en.bin")!,
        .multilingual: URL(string: "\(modelDownloadBaseURL)/ggml-small.bin")!,
    ]

    /// SHA-256 checksums for the files above. Fill these in once you've hosted
    /// your own converted models — ModelDownloadService refuses to install a
    /// download that doesn't match (when a checksum is present here).
    static var modelChecksums: [WhisperModelType: String] = [:]

    static var modelApproxSizeBytes: [WhisperModelType: Int64] = [
        .singlish: 500_000_000,
        .arabic: 500_000_000,
        .english: 500_000_000,
        .multilingual: 500_000_000,
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
