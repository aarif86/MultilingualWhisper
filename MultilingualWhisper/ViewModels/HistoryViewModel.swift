import Foundation
import Observation
import SwiftData

/// Holds History screen UI state (search, filter) and pure operations over the
/// `[Transcription]` array the View fetches with `@Query` - `@Query` itself is a
/// SwiftUI property wrapper and can't live on a plain `@Observable` class.
@MainActor
@Observable
final class HistoryViewModel {
    var searchText: String = ""
    var languageFilter: LanguageType?

    func filtered(_ transcriptions: [Transcription]) -> [Transcription] {
        transcriptions.filter { transcription in
            let matchesLanguage = languageFilter == nil || transcription.languageUsed == languageFilter
            let matchesSearch = searchText.isEmpty || transcription.text.localizedCaseInsensitiveContains(searchText)
            return matchesLanguage && matchesSearch
        }
    }

    /// "Today / Yesterday / <date>" sections, matching the History screen mockup.
    func grouped(_ transcriptions: [Transcription]) -> [(label: String, items: [Transcription])] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: transcriptions) { transcription -> String in
            if calendar.isDateInToday(transcription.date) { return "Today" }
            if calendar.isDateInYesterday(transcription.date) { return "Yesterday" }
            return Self.dayFormatter.string(from: transcription.date)
        }

        let pinnedOrder = ["Today", "Yesterday"]
        return buckets
            .sorted { lhs, rhs in
                let lhsPin = pinnedOrder.firstIndex(of: lhs.key)
                let rhsPin = pinnedOrder.firstIndex(of: rhs.key)
                switch (lhsPin, rhsPin) {
                case let (l?, r?): return l < r
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil):
                    return (lhs.value.first?.date ?? .distantPast) > (rhs.value.first?.date ?? .distantPast)
                }
            }
            .map { (label: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
    }

    /// Total words spoken today - the "words" half of Home's stat chip.
    /// Recomputed live from real saved transcriptions rather than a
    /// separately tracked counter, so it can never drift from History.
    func wordsToday(_ transcriptions: [Transcription]) -> Int {
        let calendar = Calendar.current
        return transcriptions
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.wordCount }
    }

    /// Consecutive days with at least one transcription, counting back from
    /// today. Still counts through today even before anything's been said
    /// yet - a streak only actually breaks once a full day passes with
    /// nothing at all, same as how Duolingo-style streaks read "so far".
    func streak(_ transcriptions: [Transcription]) -> Int {
        let calendar = Calendar.current
        let days = Set(transcriptions.map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: Date())
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    func delete(_ transcription: Transcription, context: ModelContext) {
        context.delete(transcription)
        try? context.save()
    }

    func delete(at offsets: IndexSet, from items: [Transcription], context: ModelContext) {
        for index in offsets {
            context.delete(items[index])
        }
        try? context.save()
    }

    func deleteAll(_ transcriptions: [Transcription], context: ModelContext) {
        transcriptions.forEach(context.delete)
        try? context.save()
    }

    /// Static because it's pure formatting with no dependency on this view model's
    /// search/filter state - Settings' "Export All" reuses it without needing a
    /// HistoryViewModel instance of its own.
    static func exportText(_ transcriptions: [Transcription]) -> String {
        transcriptions
            .sorted { $0.date < $1.date }
            .map { "[\(Self.exportFormatter.string(from: $0.date))] (\($0.languageUsed.rawValue))\n\($0.text)\n" }
            .joined(separator: "\n")
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter
    }()

    private static let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
