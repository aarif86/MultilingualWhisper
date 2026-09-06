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
}
