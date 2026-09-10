import Foundation

/// Cleans up literal artifacts whisper.cpp can decode as ordinary text.
///
/// The Singlish fine-tune (jensenlwt/whisper-small-singlish-122k) was trained on
/// IMDA National Speech Corpus transcripts, which mark unclear speech and
/// non-verbal sounds with literal tags (`<SPK/>`, `<NON/>`, etc. - confirmed from
/// real on-device output) baked directly into the target text, so the model
/// reproduces them as ordinary output text, not as tokenizer-level special tokens
/// whisper.cpp could filter at decode time. The pattern also tolerates a
/// non-self-closing paired form (`<NON>...</NON>`) defensively, though only the
/// self-closing form has actually been observed.
///
/// Pulled out of `WhisperService` as a pure, dependency-free function so it can be
/// unit tested directly - see `TranscriptSanitizerTests` - without needing a real
/// whisper.cpp engine, a model file, or a physical device.
enum TranscriptSanitizer {
    private static let annotationTagPattern = try! NSRegularExpression(pattern: "<\\/?[A-Za-z]+\\/?>")

    static func stripAnnotationTags(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        let stripped = annotationTagPattern.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        let collapsed = stripped.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Bag of hallucinations

    /// Phrases Whisper produces from silence, breath and room tone rather than
    /// speech - memorised from YouTube subtitle data, and enumerable (arXiv
    /// 2501.11378 built exactly this list by feeding the model non-speech audio).
    /// A whole segment equal to one of these is never a dictation: dropped
    /// regardless of confidence. English, Malay and Arabic - the Arabic subtitle
    /// credit is the single most reported Whisper hallucination in that language.
    static let hardHallucinations: Set<String> = [
        "thank you for watching", "thanks for watching", "thank you for watching!", "thanks for watching!",
        "please subscribe", "like and subscribe", "please like and subscribe", "don't forget to subscribe",
        "see you in the next video", "see you next time", "subtitles by the amara.org community",
        "subtitles by", "subtitles by amara.org", "amara.org", "subtitled by", "transcribed by",
        "copyright", "all rights reserved", "www.mooji.org", "bye bye",
        // Malay
        "terima kasih kerana menonton", "terima kasih sudah menonton", "jangan lupa subscribe",
        "jangan lupa like dan subscribe", "sampai jumpa di video seterusnya", "sarikata oleh",
        // Arabic
        "\u{062A}\u{0631}\u{062C}\u{0645}\u{0629} \u{0646}\u{0627}\u{0646}\u{0633}\u{064A} \u{0642}\u{0646}\u{0642}\u{0631}",
        "\u{0627}\u{0634}\u{062A}\u{0631}\u{0643}\u{0648}\u{0627} \u{0641}\u{064A} \u{0627}\u{0644}\u{0642}\u{0646}\u{0627}\u{0629}",
        "\u{0634}\u{0643}\u{0631}\u{0627} \u{0639}\u{0644}\u{0649} \u{0627}\u{0644}\u{0645}\u{0634}\u{0627}\u{0647}\u{062F}\u{0629}",
        "\u{0644}\u{0627} \u{062A}\u{0646}\u{0633}\u{0648}\u{0627} \u{0627}\u{0644}\u{0627}\u{0634}\u{062A}\u{0631}\u{0627}\u{0643} \u{0641}\u{064A} \u{0627}\u{0644}\u{0642}\u{0646}\u{0627}\u{0629}",
    ]

    /// Things people do say, that Whisper also says to silence. Dropped only when
    /// the decoder itself was unsure: a high no-speech probability or a low mean
    /// token probability for the segment.
    static let softHallucinations: Set<String> = [
        "thank you", "thank you.", "thanks", "you", "bye", "okay", "ok", "oh", "hmm", "mm", "uh",
        "terima kasih", "\u{0634}\u{0643}\u{0631}\u{0627}",
    ]

    static let softNoSpeechThreshold: Float = 0.5
    static let softConfidenceThreshold: Float = 0.45

    /// Whether a decoded segment should be discarded as a hallucination.
    static func isLikelyHallucination(_ text: String, noSpeechProbability: Float, confidence: Float) -> Bool {
        let key = normaliseForBag(text)
        guard !key.isEmpty else { return false }
        if hardHallucinations.contains(key) || hardHallucinations.contains(where: { key.hasPrefix($0 + " ") && $0.count >= 12 }) {
            return true
        }
        guard softHallucinations.contains(key) else { return false }
        return noSpeechProbability >= softNoSpeechThreshold || confidence < softConfidenceThreshold
    }

    /// Lowercased, trailing punctuation dropped, whitespace collapsed; keeps the
    /// inner punctuation of "amara.org" and "www.mooji.org".
    private static func normaliseForBag(_ text: String) -> String {
        var scalars = text.lowercased().unicodeScalars.map { $0 }
        while let last = scalars.last, CharacterSet.punctuationCharacters.contains(last) || CharacterSet.symbols.contains(last) || CharacterSet.whitespaces.contains(last) {
            scalars.removeLast()
        }
        var result = ""
        result.unicodeScalars.append(contentsOf: scalars)
        return result.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
