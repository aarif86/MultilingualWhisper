import Foundation
import Observation

/// What `WhisperService` needs from wherever models are downloaded/stored.
/// Kept separate from `ModelDownloadService` so this file doesn't need to know
/// anything about URLSession, progress callbacks, or checksums.
protocol ModelStoring {
    func isDownloaded(_ model: WhisperModelType) -> Bool
    func localURL(for model: WhisperModelType) -> URL?
}

/// Owns the loaded whisper.cpp engines and decides which model transcribes a
/// given recording. Runs on the main actor: its own work is light bookkeeping
/// (dictionary lookups, chunk splitting) - the actual CPU-heavy decode happens
/// inside `WhisperEngine`, a plain (non-main) actor, so awaiting it here never
/// blocks the UI.
@MainActor
@Observable
final class WhisperService {

    enum ServiceError: Error, LocalizedError {
        case modelNotDownloaded(WhisperModelType)
        case noAudio

        var errorDescription: String? {
            switch self {
            case .modelNotDownloaded(let model): return "\(model.displayName) isn't downloaded yet."
            case .noAudio: return "No audio to transcribe."
            }
        }
    }

    struct TranscriptionResult {
        let text: String
        let modelUsed: WhisperModelType
        let languageTag: LanguageType
    }

    private(set) var loadedModels: Set<WhisperModelType> = []

    private let modelStore: ModelStoring
    private let classifier: LanguageClassifying
    private var engines: [WhisperModelType: WhisperEngine] = [:]
    private var loadingTasks: [WhisperModelType: Task<WhisperEngine, Error>] = [:]

    init(modelStore: ModelStoring, classifier: LanguageClassifying = RuleBasedLanguageClassifier()) {
        self.modelStore = modelStore
        self.classifier = classifier
    }

    /// Loads (or returns the already-loaded) engine for a model type. Safe to
    /// call repeatedly / concurrently - concurrent callers await the same
    /// in-flight load rather than loading the same 500MB file twice.
    @discardableResult
    func loadEngine(for model: WhisperModelType) async throws -> WhisperEngine {
        if let existing = engines[model] { return existing }
        if let inFlight = loadingTasks[model] { return try await inFlight.value }

        guard modelStore.isDownloaded(model), let path = modelStore.localURL(for: model) else {
            throw ServiceError.modelNotDownloaded(model)
        }

        let task = Task.detached(priority: .userInitiated) {
            try WhisperEngine(modelPath: path.path)
        }
        loadingTasks[model] = task

        do {
            let engine = try await task.value
            engines[model] = engine
            loadingTasks[model] = nil
            loadedModels.insert(model)
            return engine
        } catch {
            loadingTasks[model] = nil
            throw error
        }
    }

    func unloadEngine(for model: WhisperModelType) {
        engines[model] = nil
        loadedModels.remove(model)
    }

    /// Forces a specific model - used by the "Force Singlish / Arabic / English"
    /// settings modes. Still classifies the resulting text purely for history tagging.
    func transcribe(samples: [Float], using model: WhisperModelType) async throws -> TranscriptionResult {
        guard !samples.isEmpty else { throw ServiceError.noAudio }
        let engine = try await loadEngine(for: model)
        let text = try await runChunked(samples: samples, engine: engine, languageHint: model.languageHint)
        let classification = classifier.classify(text: text)
        return TranscriptionResult(text: text, modelUsed: model, languageTag: classification.languageTag)
    }

    /// Two-pass auto routing used by Settings' "Auto-Detect" mode: transcribe once
    /// with `defaultModel`, classify the resulting text, and only re-transcribe with
    /// a different model if the classifier is confident it would do meaningfully
    /// better. See `LanguageClassifier.swift` for why routing can't happen "before"
    /// a first transcription pass the way the original spec assumed.
    func transcribeWithAutoRouting(
        samples: [Float],
        defaultModel: WhisperModelType = .singlish,
        reroutingConfidenceThreshold: Float = 0.6
    ) async throws -> TranscriptionResult {
        guard !samples.isEmpty else { throw ServiceError.noAudio }

        let firstEngine = try await loadEngine(for: defaultModel)
        let draftText = try await runChunked(samples: samples, engine: firstEngine, languageHint: nil)
        let classification = classifier.classify(text: draftText)

        let shouldReroute = classification.recommendedModel != defaultModel
            && classification.confidence >= reroutingConfidenceThreshold
            && modelStore.isDownloaded(classification.recommendedModel)

        guard shouldReroute else {
            return TranscriptionResult(text: draftText, modelUsed: defaultModel, languageTag: classification.languageTag)
        }

        let betterEngine = try await loadEngine(for: classification.recommendedModel)
        let finalText = try await runChunked(
            samples: samples,
            engine: betterEngine,
            languageHint: classification.recommendedModel.languageHint
        )
        return TranscriptionResult(
            text: finalText,
            modelUsed: classification.recommendedModel,
            languageTag: classification.languageTag
        )
    }

    /// Splits long recordings into ~30s windows before decoding, per the spec's
    /// memory-optimization requirement, and stitches the text back together.
    /// whisper.cpp can decode longer clips in one call internally, but capping the
    /// window bounds peak memory on older/smaller devices.
    private func runChunked(samples: [Float], engine: WhisperEngine, languageHint: String?) async throws -> String {
        let chunkSize = Int(Constants.chunkDurationSeconds * Constants.sampleRate)
        guard samples.count > chunkSize else {
            let segments = try await engine.transcribe(samples: samples, options: .init(languageHint: languageHint))
            return joined(segments)
        }

        var pieces: [String] = []
        var start = 0
        while start < samples.count {
            let end = min(start + chunkSize, samples.count)
            let segments = try await engine.transcribe(
                samples: Array(samples[start..<end]),
                options: .init(languageHint: languageHint)
            )
            pieces.append(joined(segments))
            start = end
        }
        return pieces.joined(separator: " ")
    }

    private func joined(_ segments: [WhisperEngine.Segment]) -> String {
        segments
            .map { $0.text.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
