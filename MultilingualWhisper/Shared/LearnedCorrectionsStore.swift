import Foundation

/// App Group queue between the keyboard, which notices corrections, and the app,
/// which owns the Custom Dictionary.
///
/// The keyboard extension cannot touch the app's `UserDefaults.standard`, where
/// `CustomDictionaryService` keeps its entries, so it leaves learned corrections
/// here and the app drains them on launch and on every return to the foreground.
/// The same store remembers the last inserted text, because iOS routinely
/// re-creates the keyboard extension when the user switches keyboards to make a
/// correction - a fresh instance still needs to know what it inserted a moment ago.
struct LearnedCorrectionsStore {
    static let shared = LearnedCorrectionsStore(
        defaults: UserDefaults(suiteName: DictationHandoff.appGroupID) ?? .standard
    )

    static let maxQueued = 50
    /// How long after an insert a correction can still be attributed to it.
    static let recentInsertWindow: TimeInterval = 15 * 60

    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - Queue

    func enqueue(_ correction: CorrectionLearner.Correction) {
        var queue = queued()
        guard !queue.contains(correction) else { return }
        queue.append(correction)
        if queue.count > Self.maxQueued { queue.removeFirst(queue.count - Self.maxQueued) }
        save(queue)
    }

    func queued() -> [CorrectionLearner.Correction] {
        guard let data = defaults.data(forKey: Keys.queue),
              let decoded = try? JSONDecoder().decode([CorrectionLearner.Correction].self, from: data) else { return [] }
        return decoded
    }

    /// Returns everything queued and empties the queue.
    func drain() -> [CorrectionLearner.Correction] {
        let queue = queued()
        defaults.removeObject(forKey: Keys.queue)
        return queue
    }

    // MARK: - Last insert

    func rememberInsert(_ text: String, at date: Date = Date()) {
        defaults.set(text, forKey: Keys.insertText)
        defaults.set(date, forKey: Keys.insertDate)
    }

    func recentInsert(now: Date = Date()) -> String? {
        guard let text = defaults.string(forKey: Keys.insertText), !text.isEmpty,
              let date = defaults.object(forKey: Keys.insertDate) as? Date,
              now.timeIntervalSince(date) <= Self.recentInsertWindow else { return nil }
        return text
    }

    func forgetInsert() {
        defaults.removeObject(forKey: Keys.insertText)
        defaults.removeObject(forKey: Keys.insertDate)
    }

    private func save(_ queue: [CorrectionLearner.Correction]) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        defaults.set(data, forKey: Keys.queue)
    }

    private enum Keys {
        static let queue = "dictionary.learnedQueue"
        static let insertText = "dictation.lastInsertedText"
        static let insertDate = "dictation.lastInsertedDate"
    }
}
