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
    /// File name in `UtteranceAudioStore`, when the audio was kept - lets this
    /// entry be re-run with another model, or retried after a failed decode.
    /// Optional so SwiftData migrates existing stores in place.
    var audioFileName: String?

    init(
        text: String,
        duration: TimeInterval,
        languageUsed: LanguageType,
        modelUsed: WhisperModelType,
        date: Date = Date(),
        audioFileName: String? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.duration = duration
        self.languageUsed = languageUsed
        self.modelUsed = modelUsed
        self.isFavorite = false
        self.notes = nil
        self.audioFileName = audioFileName
    }

    var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    /// A decode that failed but whose audio survived - shown as retryable.
    var isFailedWithAudio: Bool {
        text.isEmpty && audioFileName != nil
    }

    var canRetry: Bool {
        UtteranceAudioStore.exists(audioFileName)
    }
}
