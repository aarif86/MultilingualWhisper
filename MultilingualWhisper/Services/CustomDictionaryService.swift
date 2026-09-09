import Foundation
import Observation
import UIKit

/// User-editable find/replace corrections applied to every transcript after decoding.
///
/// This is the layered, deterministic alternative to `initial_prompt` decoder biasing
/// recommended in `docs/voice-dictation-research.md` Part 1 and confirmed by every
/// shipping competitor in `docs/competitor-kb/` (Superwhisper "Replacements", VoiceInk
/// "Word Replacements", MacWhisper "Find & Replace"): substitution on the final text
/// carries zero decoder risk, works with every model, and is fully predictable.
///
/// Matching semantics live in `DictionaryMatcher`; text import/export in
/// `DictionaryImporter`. This class owns persistence, editing, and the rules for
/// merging duplicates.
@MainActor
@Observable
final class CustomDictionaryService {
    struct ImportSummary: Equatable {
        /// Brand-new entries.
        var added = 0
        /// Existing entries that gained one or more new spoken forms.
        var updated = 0
        /// Rows that added nothing (already present, or every spoken form was taken).
        var skipped = 0
        /// Lines the parser could not read at all.
        var invalid = 0

        var total: Int { added + updated + skipped + invalid }
    }

    private(set) var entries: [DictionaryEntry]

    /// Rebuilt in `save()`, which every mutation goes through - kept explicit rather
    /// than as a property observer so the `@Observable` rewrite of `entries` has
    /// nothing to trip over.
    private var matcher: DictionaryMatcher
    private let defaults: UserDefaults

    /// Where the keyboard leaves corrections it noticed (see `CorrectionLearner`).
    /// nil - the default, and what tests use - means "don't drain anything".
    private let learnedStore: LearnedCorrectionsStore?
    private var foregroundObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard, learnedStore: LearnedCorrectionsStore? = nil) {
        self.defaults = defaults
        self.learnedStore = learnedStore
        let loaded = Self.load(from: defaults)
        entries = loaded
        matcher = DictionaryMatcher(entries: loaded)
        guard learnedStore != nil else { return }
        drainLearnedCorrections()
        // The keyboard can only queue corrections while the app is in the
        // background, so the moment the user comes back is exactly when to apply
        // them - before they dictate again.
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.drainLearnedCorrections() }
        }
    }

    /// Moves everything the keyboard learned into the dictionary as `.learned`
    /// entries, merging into existing written forms. Returns how many were queued.
    @discardableResult
    func drainLearnedCorrections() -> Int {
        guard let learnedStore else { return 0 }
        let learned = learnedStore.drain()
        for correction in learned {
            add(DictionaryEntry(replacement: correction.corrected, spokenForms: [correction.heard], source: .learned))
        }
        return learned.count
    }

    // MARK: - Editing

    /// v1 API, kept for callers and tests that only know one spoken form. Merges into an
    /// existing entry with the same written form rather than creating a duplicate.
    func add(original: String, replacement: String) {
        add(DictionaryEntry(original: original, replacement: replacement))
    }

    /// Adds an entry, merging its spoken forms into an existing entry with the same
    /// written form (case-sensitive: "Nasar" and "NASAR" are different corrections).
    /// Spoken forms already claimed by a *different* entry are dropped, so one thing
    /// Whisper says can only ever become one thing. Returns what was stored, or nil if
    /// nothing was left to store.
    @discardableResult
    func add(_ entry: DictionaryEntry) -> DictionaryEntry? {
        guard let normalized = entry.normalized() else { return nil }
        let free = normalized.spokenForms.filter { form in
            guard let owner = owner(ofSpokenForm: form) else { return true }
            return owner.replacement == normalized.replacement
        }
        guard !free.isEmpty else { return nil }

        if let index = entries.firstIndex(where: { $0.replacement == normalized.replacement }) {
            var existing = entries[index]
            let newForms = free.filter { !existing.hasSpokenForm($0) }
            guard !newForms.isEmpty else { return existing }
            existing.spokenForms.append(contentsOf: newForms)
            entries[index] = existing
            save()
            return existing
        }

        var fresh = normalized
        fresh.spokenForms = free
        entries.append(fresh)
        save()
        return fresh
    }

    /// Replaces the entry with the same id. Spoken forms owned by another entry are
    /// dropped; if nothing usable remains the entry is removed instead.
    func update(_ entry: DictionaryEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        guard var normalized = entry.normalized() else {
            entries.remove(at: index)
            save()
            return
        }
        normalized.spokenForms = normalized.spokenForms.filter { form in
            guard let owner = owner(ofSpokenForm: form) else { return true }
            return owner.id == entry.id
        }
        guard !normalized.spokenForms.isEmpty else {
            entries.remove(at: index)
            save()
            return
        }
        entries[index] = normalized
        save()
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func removeAll() {
        entries.removeAll()
        save()
    }

    /// The entry that already claims `form` as a spoken form, if any.
    func owner(ofSpokenForm form: String) -> DictionaryEntry? {
        entries.first { $0.hasSpokenForm(form) }
    }

    // MARK: - Import / export

    func importText(_ text: String) -> ImportSummary {
        let result = DictionaryImporter.parse(text)
        var summary = ImportSummary(invalid: result.invalidLineCount)
        for parsed in result.entries {
            let before = entries.first { $0.replacement == parsed.replacement }
            let candidate = DictionaryEntry(
                replacement: parsed.replacement,
                spokenForms: parsed.spokenForms,
                matchWholeWord: parsed.matchWholeWord ?? before?.matchWholeWord ?? true,
                matchCase: parsed.matchCase ?? before?.matchCase ?? false,
                source: .imported
            )
            guard let stored = add(candidate) else {
                summary.skipped += 1
                continue
            }
            if let before {
                summary.updated += stored.spokenForms.count > before.spokenForms.count ? 1 : 0
                summary.skipped += stored.spokenForms.count > before.spokenForms.count ? 0 : 1
            } else {
                summary.added += 1
            }
        }
        return summary
    }

    func exportCSV() -> String {
        DictionaryImporter.exportCSV(entries)
    }

    // MARK: - Application

    /// Applies every correction in one pass. See `DictionaryMatcher` for the rules.
    func apply(to text: String) -> String {
        guard !matcher.isEmpty, !text.isEmpty else { return text }
        return matcher.apply(to: text)
    }

    // MARK: - Persistence

    private func save() {
        matcher = DictionaryMatcher(entries: entries)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Keys.entries)
    }

    /// Decodes leniently: one unreadable entry must never wipe the user's whole list.
    private static func load(from defaults: UserDefaults) -> [DictionaryEntry] {
        guard let data = defaults.data(forKey: Keys.entries) else { return [] }
        if let decoded = try? JSONDecoder().decode([Lossy<DictionaryEntry>].self, from: data) {
            return decoded.compactMap(\.value)
        }
        return []
    }

    private struct Lossy<Value: Decodable>: Decodable {
        let value: Value?
        init(from decoder: Decoder) throws {
            value = try? Value(from: decoder)
        }
    }

    private enum Keys {
        static let entries = "customDictionary.entries"
    }
}
