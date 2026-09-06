import Foundation
import SwiftData

/// A single saved transcription, persisted via SwiftData.
@Model
final class Transcription {
    @Attribute(.unique) var id: UUID
    var text: String
    var date: Date
    var duration: TimeInterval
    var languageUsed: LanguageType
    var modelUsed: WhisperModelType
    var isFavorite: Bool
    var notes: String?

    init(
        text: String,
        duration: TimeInterval,
        languageUsed: LanguageType,
        modelUsed: WhisperModelType,
        date: Date = Date()
    ) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.duration = duration
        self.languageUsed = languageUsed
        self.modelUsed = modelUsed
        self.isFavorite = false
        self.notes = nil
    }

    var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
