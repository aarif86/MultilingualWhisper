import Foundation

/// Result of classifying a piece of transcribed text.
struct LanguageClassification: Equatable {
    let recommendedModel: WhisperModelType
    let languageTag: LanguageType
    /// 0...1. Deliberately coarse — this is a heuristic, not a calibrated probability.
    let confidence: Float
}

protocol LanguageClassifying {
    /// Classifies already-transcribed text. See note on `RuleBasedLanguageClassifier`
    /// for why this operates on text rather than raw audio.
    func classify(text: String) -> LanguageClassification
}

/// v1 language router: Arabic-script detection + curated keyword lists.
///
/// The original spec described this as running on ~1-2 seconds of raw *audio* using
/// "on-device fastText or keyword detection". That doesn't quite work as written —
/// keyword and script matching need text, and you don't have text until something has
/// already transcribed the audio. Training a real acoustic language-ID model (fastText
/// or otherwise) is a separate ML project with its own labeled data, outside what this
/// codebase can responsibly ship as a first cut.
///
/// So this classifier runs on a fast draft transcription instead, and `WhisperService`
/// does the two-pass routing: transcribe once with a default model, classify the
/// resulting text, and only re-transcribe with a different model if the classifier is
/// confident it picked wrong. See `WhisperService.transcribeWithAutoRouting`.
///
/// This type is intentionally swappable: conform something else to `LanguageClassifying`
/// (a bundled Core ML model, a real fastText binary, etc.) and hand it to `WhisperService`
/// without touching any call site.
struct RuleBasedLanguageClassifier: LanguageClassifying {

    func classify(text: String) -> LanguageClassification {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return LanguageClassification(recommendedModel: .singlish, languageTag: .unknown, confidence: 0)
        }

        let scalars = trimmed.unicodeScalars
        let arabicScalarCount = scalars.filter(Self.isArabicScalar).count
        let arabicRatio = Float(arabicScalarCount) / Float(max(scalars.count, 1))

        let words = Set(
            trimmed.lowercased()
                .split(whereSeparator: { !$0.isLetter })
                .map(String.init)
        )
        let malayHits = words.intersection(Constants.malayKeywords).count
        let singlishHits = words.intersection(Constants.singlishMarkers).count
        let arabicPhraseHits = Constants.arabicKeywords.filter { trimmed.contains($0) }.count
        let romanizedArabicHits = words.intersection(Constants.romanizedArabicMarkers).count

        // Audio that's dominantly Arabic script: route to the Arabic model outright.
        if arabicRatio > 0.4 {
            return LanguageClassification(
                recommendedModel: .arabic,
                languageTag: .arabic,
                confidence: min(1, 0.55 + arabicRatio)
            )
        }

        // A short Arabic phrase embedded in otherwise Latin-script text
        // ("Bismillah, let's go makan lah") - per spec, keep the Singlish model,
        // which handles embedded Arabic loanwords fine, and tag the result Mixed.
        // Covers both actual Arabic script and its common Latin transliterations,
        // since a model hinted to decode in Latin script will render "Bismillah"
        // as exactly that, not as بسم الله.
        if arabicScalarCount > 0 || arabicPhraseHits > 0 || romanizedArabicHits > 0 {
            let tag: LanguageType = (malayHits > 0 || singlishHits > 0) ? .mixed : .arabic
            return LanguageClassification(recommendedModel: .singlish, languageTag: tag, confidence: 0.55)
        }

        if malayHits > 0 && singlishHits > 0 {
            return LanguageClassification(recommendedModel: .singlish, languageTag: .mixed, confidence: min(1, 0.4 + Float(malayHits + singlishHits) * 0.1))
        }

        if malayHits > 0 {
            return LanguageClassification(recommendedModel: .singlish, languageTag: .malay, confidence: min(1, 0.4 + Float(malayHits) * 0.15))
        }

        if singlishHits > 0 {
            return LanguageClassification(recommendedModel: .singlish, languageTag: .singlish, confidence: min(1, 0.4 + Float(singlishHits) * 0.15))
        }

        return LanguageClassification(recommendedModel: .singlish, languageTag: .english, confidence: 0.3)
    }

    /// Arabic + Arabic Presentation Forms A/B Unicode blocks.
    private static func isArabicScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0600...0x06FF, 0x0750...0x077F, 0xFB50...0xFDFF, 0xFE70...0xFEFF:
            return true
        default:
            return false
        }
    }
}
