import Foundation
import Observation
import SwiftData
import UIKit

/// Drives the streamlined recording flow shown when the app is launched from
/// the keyboard extension's "Dictate" button, rather than opened normally.
/// Wraps a `TranscriptionViewModel` instead of duplicating its recording
/// logic, adding only: auto-start, and publishing the result for the keyboard
/// to pick up once it finishes.
@MainActor
@Observable
final class QuickDictateViewModel {
    let transcription: TranscriptionViewModel
    private(set) var didPublish = false

    init(audioService: AudioService, whisperService: WhisperService) {
        transcription = TranscriptionViewModel(audioService: audioService, whisperService: whisperService)
    }

    func start(modelContext: ModelContext) {
        didPublish = false
        transcription.clearTranscript()
        transcription.toggleRecording(modelContext: modelContext)
    }

    /// Call whenever `transcription.phase` changes - a no-op unless recording
    /// has actually finished with real text, and only fires once per dictation.
    func publishIfFinished() {
        guard !didPublish, transcription.phase == .idle, !transcription.transcript.isEmpty else { return }
        DictationHandoff.publish(transcription.transcript)
        UIPasteboard.general.string = transcription.transcript
        didPublish = true
    }
}
