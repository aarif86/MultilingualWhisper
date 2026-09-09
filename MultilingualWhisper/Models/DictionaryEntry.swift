import Foundation

/// A single user-taught correction the Custom Dictionary applies after transcription.
///
/// One entry maps *every way Whisper has been heard to render a word* (its
/// `spokenForms` - "Nassar", "Nasser", "Nazar") onto the one way it should be written
/// (`replacement` - "Nasar"). This is the many-to-one shape every serious dictation
/// product converged on (VoiceInk's "Voicing, Voice ink, Voiceing -> VoiceInk", Willow's
/// term replacement, Dragon's separate written-vs-spoken forms) and it's the reason the
/// old single `original` field became a list.
///
/// Matching is deterministic, post-transcription substitution - the safe alternative to
/// biasing the decoder itself (see `WhisperModelType.initialPrompt`, currently disabled
/// pending a regression investigation). See `DictionaryMatcher` for the exact semantics.
struct DictionaryEntry: Codable, Identifiable, Equatable, Hashable {
    /// Where an entry came from. Kept so a future "Auto Learning" tab (Willow) or an
    /// "imported from Wispr" badge can be shown without a migration.
    enum Source: String, Codable {
        case manual
        case imported
        case learned
    }

    let id: UUID
    /// The written form - what the transcript should say. Output exactly as typed here,
    /// including case (Superwhisper's documented rule: "cased exactly as defined").
    var replacement: String
    /// Every rendering Whisper produces that should become `replacement`. Never empty.
    var spokenForms: [String]
    /// When true (the default), "Cat" -> "Dog" leaves "Caterpillar" alone. Turn off for
    /// prefixes/suffixes or scripts where clitics attach to the word.
    var matchWholeWord: Bool
    /// When false (the default), "nassar", "Nassar" and "NASSAR" all match.
    var matchCase: Bool
    var source: Source
    var createdAt: Date

    /// The primary spoken form. Kept as the name the rest of the app and the v1 tests
    /// used, so nothing that only cares about "the one thing Whisper hears" had to change.
    var original: String { spokenForms.first ?? "" }

    init(
        id: UUID = UUID(),
        replacement: String,
        spokenForms: [String],
        matchWholeWord: Bool = true,
        matchCase: Bool = false,
        source: Source = .manual,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.replacement = replacement
        self.spokenForms = spokenForms
        self.matchWholeWord = matchWholeWord
        self.matchCase = matchCase
        self.source = source
        self.createdAt = createdAt
    }

    /// v1 convenience: one spoken form, default matching rules.
    init(id: UUID = UUID(), original: String, replacement: String) {
        self.init(id: id, replacement: replacement, spokenForms: [original])
    }

    // MARK: - Codable (tolerates the v1 on-disk shape)

    private enum CodingKeys: String, CodingKey {
        case id, replacement, spokenForms, matchWholeWord, matchCase, source, createdAt
        /// v1 only wrote `{id, original, replacement}`. Read it, never write it again.
        case original
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        replacement = try container.decode(String.self, forKey: .replacement)
        if let forms = try container.decodeIfPresent([String].self, forKey: .spokenForms), !forms.isEmpty {
            spokenForms = forms
        } else if let legacy = try container.decodeIfPresent(String.self, forKey: .original), !legacy.isEmpty {
            spokenForms = [legacy]
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .spokenForms,
                in: container,
                debugDescription: "A dictionary entry needs at least one spoken form."
            )
        }
        matchWholeWord = try container.decodeIfPresent(Bool.self, forKey: .matchWholeWord) ?? true
        matchCase = try container.decodeIfPresent(Bool.self, forKey: .matchCase) ?? false
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .manual
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(replacement, forKey: .replacement)
        try container.encode(spokenForms, forKey: .spokenForms)
        try container.encode(matchWholeWord, forKey: .matchWholeWord)
        try container.encode(matchCase, forKey: .matchCase)
        try container.encode(source, forKey: .source)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

extension DictionaryEntry {
    /// Trims every field and drops blank spoken forms. Returns nil if nothing usable is
    /// left, so callers never persist an entry that could not match anything.
    func normalized() -> DictionaryEntry? {
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<String>()
        let forms = spokenForms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
        guard !trimmedReplacement.isEmpty, !forms.isEmpty else { return nil }
        var copy = self
        copy.replacement = trimmedReplacement
        copy.spokenForms = forms
        return copy
    }

    /// True if `form` is already one of this entry's spoken forms, ignoring case.
    func hasSpokenForm(_ form: String) -> Bool {
        let needle = form.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return spokenForms.contains { $0.lowercased() == needle }
    }
}
