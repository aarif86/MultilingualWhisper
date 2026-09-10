import Foundation
import Observation

/// User-approved additions to the built-in Malay/Singlish keyword lists that
/// `RuleBasedLanguageClassifier` uses for its routing decisions - the
/// vocabulary-import counterpart to `CustomDictionaryService`. Deliberately a
/// separate store rather than folding into the dictionary: a dictionary entry
/// corrects *how a word is spelled* after decoding, this decides *whether a
/// word is evidence a language is being spoken at all*, before decoding even
/// finishes. Different data shape (a bare word, no "spoken forms"/replacement
/// pair), different consumer.
///
/// Populated by `ChatImportReviewView` after the user approves candidates
/// from an imported WhatsApp/Telegram export - see `ChatExportParser`.
///
/// Known simplification: `WhisperService` reads this once, at app launch, to
/// build the classifier it uses for every transcription afterward - approving
/// new words takes effect on the next launch, not mid-session. Good enough
/// for something a user does occasionally (import a chat once), not per
/// dictation; revisit only if that turns out to actually bother anyone.
@MainActor
@Observable
final class UserLanguageKeywords {
    private(set) var malay: Set<String>
    private(set) var singlish: Set<String>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        malay = Self.load(from: defaults, key: Keys.malay)
        singlish = Self.load(from: defaults, key: Keys.singlish)
    }

    func addMalay<S: Sequence<String>>(_ words: S) {
        malay.formUnion(words.map { $0.lowercased() })
        save(malay, key: Keys.malay)
    }

    func addSinglish<S: Sequence<String>>(_ words: S) {
        singlish.formUnion(words.map { $0.lowercased() })
        save(singlish, key: Keys.singlish)
    }

    /// A word might have been suggested under one label and turn out to
    /// belong under the other (or turn out to be nothing at all) - remove
    /// from both rather than requiring the caller to know which list it's
    /// actually in.
    func remove(_ word: String) {
        let lowered = word.lowercased()
        malay.remove(lowered)
        singlish.remove(lowered)
        save(malay, key: Keys.malay)
        save(singlish, key: Keys.singlish)
    }

    func removeAll() {
        malay.removeAll()
        singlish.removeAll()
        save(malay, key: Keys.malay)
        save(singlish, key: Keys.singlish)
    }

    private func save(_ words: Set<String>, key: String) {
        guard let data = try? JSONEncoder().encode(words) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load(from defaults: UserDefaults, key: String) -> Set<String> {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data)
        else { return [] }
        return decoded
    }

    private enum Keys {
        static let malay = "userLanguageKeywords.malay"
        static let singlish = "userLanguageKeywords.singlish"
    }
}
