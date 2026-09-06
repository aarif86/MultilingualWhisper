import Foundation

/// A single user-taught correction the Custom Dictionary applies after transcription -
/// e.g. "Nassar" -> "Nasar" for a systematically mis-heard proper noun. Deterministic,
/// post-transcription substitution: the safe alternative to biasing the decoder itself
/// (see `WhisperModelType.initialPrompt`, currently disabled pending a regression
/// investigation - this doesn't touch the decoder at all).
struct DictionaryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var original: String
    var replacement: String

    init(id: UUID = UUID(), original: String, replacement: String) {
        self.id = id
        self.original = original
        self.replacement = replacement
    }
}
