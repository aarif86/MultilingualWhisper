import Foundation

/// The set of GGML models the app can load into a WhisperEngine.
///
/// Note: the spec this app was built from also had a separate top-level
/// `ModelType` enum duplicating this. They're merged into one type here —
/// two enums for "which model" was a bug waiting to happen (the settings
/// picker and the transcription engine would drift), not a feature.
enum WhisperModelType: String, CaseIterable, Codable, Identifiable {
    case singlish
    case arabic
    case english
    case multilingual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .singlish: return "Singlish Model"
        case .arabic: return "Arabic Model"
        case .english: return "English Model"
        case .multilingual: return "Multilingual Model"
        }
    }

    /// File name the app stores the downloaded GGML weights under, on-device.
    var localFileName: String {
        switch self {
        case .singlish: return "ggml-small-singlish.bin"
        case .arabic: return "ggml-small-arabic.bin"
        case .english: return "ggml-small.en.bin"
        case .multilingual: return "ggml-small.bin"
        }
    }

    /// Language hint passed to whisper_full_params.language. All four models
    /// here are fine-tunes/builds of the multilingual whisper-small checkpoint,
    /// so a hint measurably improves accuracy over "auto" — but this is only
    /// a *hint*: whisper.cpp will still emit whatever script it decodes.
    /// `nil` means "let whisper auto-detect".
    var languageHint: String? {
        switch self {
        case .singlish: return "en"
        case .arabic: return "ar"
        case .english: return "en"
        case .multilingual: return nil
        }
    }

    var remoteURL: URL? { Constants.modelRemoteURLs[self] }
    var expectedChecksum: String? { Constants.modelChecksums[self] }
    var approxSizeBytes: Int64 { Constants.modelApproxSizeBytes[self] ?? 0 }
}

/// Language tag stored on each saved Transcription, for display/filtering in History.
/// This is a *label*, distinct from WhisperModelType (which model produced the text) —
/// e.g. the Singlish model can produce a transcript that's tagged `.malay` because the
/// classifier detected Malay-dominant audio and routed accordingly.
enum LanguageType: String, Codable, CaseIterable, Identifiable {
    case singlish = "Singlish"
    case malay = "Malay"
    case arabic = "Arabic"
    case english = "English"
    case mixed = "Mixed"
    case unknown = "Unknown"

    var id: String { rawValue }
}

/// User-facing language routing mode, set in Settings.
enum LanguageMode: String, Codable, CaseIterable, Identifiable {
    case auto = "Auto-Detect (Recommended)"
    case forceSinglish = "Force Singlish"
    case forceArabic = "Force Arabic"
    case forceEnglish = "Force English"
    case multilingual = "Multilingual"

    var id: String { rawValue }

    /// The model this mode pins to, or nil when the mode is `.auto` and routing
    /// should defer to LanguageClassifier instead.
    var pinnedModel: WhisperModelType? {
        switch self {
        case .auto: return nil
        case .forceSinglish: return .singlish
        case .forceArabic: return .arabic
        case .forceEnglish: return .english
        case .multilingual: return .multilingual
        }
    }
}
