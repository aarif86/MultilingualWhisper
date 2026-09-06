import Foundation
import Observation

/// User-editable find/replace corrections applied to every transcript after decoding.
/// This is the layered, deterministic alternative to `initial_prompt` decoder biasing
/// recommended in `docs/voice-dictation-research.md` Part 1: whole-word substitution
/// carries zero decoder risk, unlike priming Whisper's own context.
@MainActor
@Observable
final class CustomDictionaryService {
    private(set) var entries: [DictionaryEntry]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.entries),
           let decoded = try? JSONDecoder().decode([DictionaryEntry].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }
    }

    func add(original: String, replacement: String) {
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty, !trimmedReplacement.isEmpty else { return }
        entries.append(DictionaryEntry(original: trimmedOriginal, replacement: trimmedReplacement))
        save()
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    /// Whole-word, case-insensitive substitution - deliberately not substring matching,
    /// so correcting "Nassar" -> "Nasar" doesn't also mangle an unrelated word that just
    /// happens to contain "Nassar" as a substring.
    func apply(to text: String) -> String {
        guard !entries.isEmpty, !text.isEmpty else { return text }
        var result = text
        for entry in entries {
            guard !entry.original.isEmpty else { continue }
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: entry.original))\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            let template = NSRegularExpression.escapedTemplate(for: entry.replacement)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: template)
        }
        return result
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Keys.entries)
    }

    private enum Keys {
        static let entries = "customDictionary.entries"
    }
}
