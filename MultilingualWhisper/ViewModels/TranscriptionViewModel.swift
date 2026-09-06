import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TranscriptionViewModel {

    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
        case error(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var transcript: String = ""
    private(set) var lastModelUsed: WhisperModelType?
    private(set) var lastLanguageTag: LanguageType?
    private(set) var lastDuration: TimeInterval = 0

    var isRecording: Bool { audioService.isRecording }
    var recordingLevel: Float { audioService.currentLevel }
    var recordingElapsed: TimeInterval { audioService.elapsed }
    var wordCount: Int { transcript.split(whereSeparator: \.isWhitespace).count }
    var languageModeLabel: String { settings.languageMode.rawValue }

    let audioService: AudioService
    private let whisperService: WhisperService
    private let settings: AppSettings
    private var activeModelContext: ModelContext?

    init(audioService: AudioService, whisperService: WhisperService, settings: AppSettings = .shared) {
        self.audioService = audioService
        self.whisperService = whisperService
        self.settings = settings
    }

    func toggleRecording(modelContext: ModelContext) {
        if isRecording {
            stopAndTranscribe()
        } else {
            startRecording(modelContext: modelContext)
        }
    }

    func cycleLanguageMode() {
        let modes = LanguageMode.allCases
        guard let index = modes.firstIndex(of: settings.languageMode) else { return }
        settings.languageMode = modes[(index + 1) % modes.count]
    }

    func clearTranscript() {
        transcript = ""
        lastModelUsed = nil
        lastLanguageTag = nil
        lastDuration = 0
        if case .error = phase { phase = .idle }
    }

    func dismissError() {
        if case .error = phase { phase = .idle }
    }

    // MARK: - Recording lifecycle

    private func startRecording(modelContext: ModelContext) {
        activeModelContext = modelContext
        Task {
            let granted = await audioService.requestPermission()
            guard granted else {
                phase = .error("Microphone access is required to record. Enable it in Settings.")
                return
            }
            do {
                audioService.vadEnabled = true
                audioService.vadThreshold = settings.vadSensitivity
                try audioService.startRecording { [weak self] in
                    // `evaluateVAD` already runs on the main actor, but hopping through
                    // a fresh Task keeps this closure's type plain `() -> Void` with no
                    // isolation assumptions baked into it.
                    Task { @MainActor in
                        self?.stopAndTranscribe()
                    }
                }
                phase = .recording
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func stopAndTranscribe() {
        guard isRecording else { return }
        let samples = audioService.stopRecording()
        let duration = recordingElapsed
        phase = .transcribing

        Task {
            do {
                let result: WhisperService.TranscriptionResult
                if let forcedModel = settings.languageMode.pinnedModel {
                    result = try await whisperService.transcribe(samples: samples, using: forcedModel)
                } else {
                    result = try await whisperService.transcribeWithAutoRouting(samples: samples)
                }

                let finalText = applyPunctuationPreference(to: result.text)
                transcript = finalText
                lastModelUsed = result.modelUsed
                lastLanguageTag = result.languageTag
                lastDuration = duration
                phase = .idle

                saveToHistory(text: finalText, model: result.modelUsed, language: result.languageTag, duration: duration)
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func saveToHistory(text: String, model: WhisperModelType, language: LanguageType, duration: TimeInterval) {
        guard !text.isEmpty, let context = activeModelContext else { return }
        let record = Transcription(text: text, duration: duration, languageUsed: language, modelUsed: model)
        context.insert(record)
        try? context.save()
    }

    /// Whisper always decodes with punctuation baked in - there's no engine-level
    /// toggle for it. When the user turns "Auto-punctuation" off in Settings, we
    /// honor that by stripping punctuation from the finished text instead, which
    /// gives the setting real, visible effect rather than a switch that does nothing.
    private func applyPunctuationPreference(to text: String) -> String {
        guard !settings.autoPunctuation else { return text }
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let scalars = text.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }
}
