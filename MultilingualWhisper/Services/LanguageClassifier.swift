import Foundation

/// Result of classifying a piece of transcribed text.
struct LanguageClassification: Equatable {
    let recommendedModel: WhisperModelType
    let languageTag: LanguageType
    /// 0...1. Deliberately coarse — this is a heuristic, not a calibrated probability.
    let confidence: Float
    /// Which specific languages were actually detected, in a fixed display order
    /// (Arabic, Malay, Singlish, English) - e.g. `[.arabic, .malay, .singlish]` for
    /// "Bismillah, let's go makan lah". Empty only when `languageTag == .unknown`.
    /// Exists so a badge can show "Arabic + Malay + Singlish" instead of a generic
    /// "Mixed" when that's literally what's being spoken - code-switching is the
    /// whole point of this app, not an edge case to flatten into one word.
    let components: [LanguageType]
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
            return LanguageClassification(recommendedModel: .singlish, languageTag: .unknown, confidence: 0, components: [])
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
        let hasArabic = arabicScalarCount > 0 || arabicPhraseHits > 0 || romanizedArabicHits > 0

        var components: [LanguageType] = []
        if hasArabic { components.append(.arabic) }
        if malayHits > 0 { components.append(.malay) }
        if singlishHits > 0 { components.append(.singlish) }
        if components.isEmpty { components.append(.english) }

        // Audio that's dominantly Arabic script: route to the Arabic model outright.
        if arabicRatio > 0.4 {
            return LanguageClassification(
                recommendedModel: .arabic,
                languageTag: .arabic,
                confidence: min(1, 0.55 + arabicRatio),
                components: components
            )
        }

        // A short Arabic phrase embedded in otherwise Latin-script text
        // ("Bismillah, let's go makan lah") - per spec, keep the Singlish model,
        // which handles embedded Arabic loanwords fine, and tag the result Mixed.
        // Covers both actual Arabic script and its common Latin transliterations,
        // since a model hinted to decode in Latin script will render "Bismillah"
        // as exactly that, not as بسم الله.
        if hasArabic {
            let tag: LanguageType = (malayHits > 0 || singlishHits > 0) ? .mixed : .arabic
            return LanguageClassification(recommendedModel: .singlish, languageTag: tag, confidence: 0.55, components: components)
        }

        if malayHits > 0 && singlishHits > 0 {
            return LanguageClassification(
                recommendedModel: .singlish,
                languageTag: .mixed,
                confidence: min(1, 0.4 + Float(malayHits + singlishHits) * 0.1),
                components: components
            )
        }

        // Malay markers with no Singlish particles alongside them: dominant/pure
        // Malay, not code-switching - route to the dedicated Malay model instead
        // of leaving it on Singlish (which only needs to handle *embedded* Malay
        // loanwords, the case above where singlishHits > 0 too).
        //
        // Real bug this guards against: a deliberate language switch (a plain-
        // English clause with no Singlish-specific slang, plus a short Malay
        // clause) was reading as confidently "dominant Malay" from raw keyword
        // count alone, with no regard for how much of the utterance that
        // actually accounted for - and WhisperService re-decodes the ENTIRE
        // clip once confidence crosses its reroute threshold, clobbering the
        // perfectly good English portion in the process. Scaling by how much
        // of the text's own words are matched Malay keywords (not just the
        // absolute count) keeps a short embedded clause below that threshold,
        // so per-segment reprocessing gets a chance to isolate just the Malay
        // part instead - while a clip that's genuinely all/mostly Malay still
        // has a high match ratio and reaches full confidence as before.
        if malayHits > 0 {
            let dominanceRatio = Float(malayHits) / Float(words.count)
            let confidence = min(1, 0.4 + Float(malayHits) * 0.15) * min(1, dominanceRatio * 4)
            return LanguageClassification(
                recommendedModel: .malay,
                languageTag: .malay,
                confidence: confidence,
                components: components
            )
        }

        if singlishHits > 0 {
            return LanguageClassification(
                recommendedModel: .singlish,
                languageTag: .singlish,
                confidence: min(1, 0.4 + Float(singlishHits) * 0.15),
                components: components
            )
        }

        return LanguageClassification(recommendedModel: .singlish, languageTag: .english, confidence: 0.3, components: components)
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
