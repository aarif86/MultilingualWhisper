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
    /// Which specific languages made up `lastLanguageTag` when it's `.mixed` -
    /// e.g. `[.arabic, .malay, .singlish]` - so the UI can show "Arabic + Malay
    /// + Singlish" instead of a generic "Mixed". See `LanguageClassification`.
    private(set) var lastLanguageComponents: [LanguageType] = []
    private(set) var lastDuration: TimeInterval = 0
    /// Set when the current `.error` phase is specifically an already-denied mic
    /// permission (as opposed to any other failure) - lets the view offer a direct
    /// link to Settings instead of just an "OK" button, since re-requesting can't
    /// possibly work once denied (iOS only shows that system prompt once, ever).
    private(set) var microphonePermissionDenied = false

    var isRecording: Bool { audioService.isRecording }
    var recordingLevel: Float { audioService.currentLevel }
    var recordingElapsed: TimeInterval { audioService.elapsed }
    var wordCount: Int { transcript.split(whereSeparator: \.isWhitespace).count }
    var languageModeLabel: String { settings.languageMode.rawValue }

    let audioService: AudioService
    private let whisperService: WhisperService
    private let settings: AppSettings
    private var activeModelContext: ModelContext?
    private var liveUpdateTask: Task<Void, Never>?
    private var isLiveTranscribing = false

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
        lastLanguageComponents = []
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
            // Once denied, requestPermission() just silently resolves false again
            // forever - no system UI, no way for the user to retry from inside the
            // app. Short-circuit straight to "go to Settings" instead of repeating
            // a request that's guaranteed to fail the same way.
            if audioService.isPermissionDenied {
                microphonePermissionDenied = true
                phase = .error("Microphone access is denied. Enable it in Settings to record.")
                return
            }

            let granted = await audioService.requestPermission()
            guard granted else {
                microphonePermissionDenied = audioService.isPermissionDenied
                phase = .error("Microphone access is required to record. Enable it in Settings.")
                return
            }
            microphonePermissionDenied = false
            do {
                audioService.vadEnabled = settings.autoStopOnSilence
                audioService.vadThreshold = settings.vadSensitivity
                try audioService.startRecording { [weak self] in
                    // `evaluateVAD` already runs on the main actor, but hopping through
                    // a fresh Task keeps this closure's type plain `() -> Void` with no
                    // isolation assumptions baked into it.
                    Task { @MainActor in
                        self?.stopAndTranscribe()
                    }
                }
                // A fresh recording starts from a clean slate - previously the old
                // transcript (and its language badge) stayed on screen through the
                // entire next recording until the first live update or final result
                // overwrote it, which looked like nothing was happening. It's already
                // safely in History by this point, so nothing is lost by clearing it.
                clearTranscript()
                phase = .recording
                startLiveUpdates()
                DebugLogger.shared.log("recording started", category: "viewmodel")
            } catch {
                DebugLogger.shared.log("startRecording failed: \(error)", category: "viewmodel")
                phase = .error(error.localizedDescription)
            }
        }
    }

    /// Re-transcribes whatever's been captured so far every couple of seconds
    /// while recording, so text appears as you talk instead of only at the end.
    /// This is a live *preview* only - it never throws to the user (a transient
    /// failure here just means the preview doesn't update that one time; the
    /// authoritative result still comes from the full transcription in
    /// `stopAndTranscribe` once recording actually stops) and deliberately uses a
    /// single forced model rather than the full two-pass auto-routing, since
    /// re-running that every 2 seconds on a growing buffer would get expensive.
    private func startLiveUpdates() {
        liveUpdateTask?.cancel()
        liveUpdateTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled, self.isRecording else { break }
                await self.performLiveUpdate()
            }
        }
    }

    private func performLiveUpdate() async {
        guard !isLiveTranscribing else { return }
        let snapshot = audioService.snapshotSamples()
        guard snapshot.count > Int(0.5 * Constants.sampleRate) else { return }

        isLiveTranscribing = true
        defer { isLiveTranscribing = false }

        let model = settings.languageMode.pinnedModel ?? .singlish
        do {
            let result = try await whisperService.transcribe(
                samples: snapshot,
                using: model,
                chunkDurationSeconds: TimeInterval(settings.maxRecordDurationSeconds)
            )
            guard isRecording else { return } // stopped for real while this was running
            transcript = applyPunctuationPreference(to: result.text)
        } catch {
            // Deliberately not surfaced to the user (see doc comment above) - but
            // logged, since a transient failure here that keeps happening would
            // otherwise look identical to "nothing is being captured at all".
            DebugLogger.shared.log("live update failed: \(error)", category: "viewmodel")
        }
    }

    private func stopAndTranscribe() {
        // Not `guard isRecording` - by the time an auto-stop-triggered call gets
        // here, AudioService has *already* set isRecording false (it stops itself
        // before invoking the callback that leads here), so that check would
        // discard every auto-stopped recording without ever transcribing it.
        // Guarding on phase instead only blocks genuine double-invocation.
        guard phase != .transcribing else { return }
        liveUpdateTask?.cancel()
        liveUpdateTask = nil
        let samples = audioService.stopRecording()
        let duration = recordingElapsed
        // Distinguishes "audio capture produced nothing" from "whisper decoded
        // the captured audio to nothing" - otherwise identical from the outside.
        DebugLogger.shared.log("stopAndTranscribe: samples=\(samples.count) duration=\(duration)", category: "viewmodel")
        if settings.saveDebugAudio {
            DebugAudioStore.save(samples: samples)
        }
        phase = .transcribing

        Task {
            do {
                let result: WhisperService.TranscriptionResult
                let chunkSeconds = TimeInterval(settings.maxRecordDurationSeconds)
                if let forcedModel = settings.languageMode.pinnedModel {
                    result = try await whisperService.transcribe(samples: samples, using: forcedModel, chunkDurationSeconds: chunkSeconds)
                } else {
                    result = try await whisperService.transcribeWithAutoRouting(samples: samples, chunkDurationSeconds: chunkSeconds)
                }

                let finalText = applyPunctuationPreference(to: result.text)
                // An empty final decode would otherwise silently wipe out whatever
                // the live preview already showed on screen ("like it never
                // existed") - only ever replace visible text with something new,
                // never with nothing.
                if !finalText.isEmpty {
                    transcript = finalText
                }
                lastModelUsed = result.modelUsed
                lastLanguageTag = result.languageTag
                lastLanguageComponents = result.languageComponents
                lastDuration = duration
                phase = .idle

                saveToHistory(text: finalText, model: result.modelUsed, language: result.languageTag, duration: duration)
            } catch {
                DebugLogger.shared.log("stopAndTranscribe failed: \(error)", category: "viewmodel")
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
