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
        let languageComponents: [LanguageType]
    }

    private(set) var loadedModels: Set<WhisperModelType> = []

    private let modelStore: ModelStoring
    private let classifier: LanguageClassifying
    private let customDictionary: CustomDictionaryService
    private let makeEngine: @Sendable (String) throws -> WhisperTranscribing
    private var engines: [WhisperModelType: WhisperTranscribing] = [:]
    private var loadingTasks: [WhisperModelType: Task<WhisperTranscribing, Error>] = [:]

    /// `makeEngine` defaults to constructing a real whisper.cpp-backed
    /// `WhisperEngine` from a model file path. Tests override it to hand back a
    /// fake `WhisperTranscribing` instead, so the routing logic below can run
    /// with no model file, no audio, and no device - see `WhisperServiceRoutingTests`.
    /// `customDictionary` should be the same instance Settings edits, not a fresh one -
    /// see how `MultilingualWhisperApp` constructs and threads it.
    init(
        modelStore: ModelStoring,
        classifier: LanguageClassifying = RuleBasedLanguageClassifier(),
        customDictionary: CustomDictionaryService = CustomDictionaryService(),
        makeEngine: @escaping @Sendable (String) throws -> WhisperTranscribing = { try WhisperEngine(modelPath: $0) }
    ) {
        self.modelStore = modelStore
        self.classifier = classifier
        self.customDictionary = customDictionary
        self.makeEngine = makeEngine
    }

    /// Loads (or returns the already-loaded) engine for a model type. Safe to
    /// call repeatedly / concurrently - concurrent callers await the same
    /// in-flight load rather than loading the same 500MB file twice.
    @discardableResult
    func loadEngine(for model: WhisperModelType) async throws -> WhisperTranscribing {
        if let existing = engines[model] { return existing }
        if let inFlight = loadingTasks[model] { return try await inFlight.value }

        guard modelStore.isDownloaded(model), let path = modelStore.localURL(for: model) else {
            throw ServiceError.modelNotDownloaded(model)
        }

        DebugLogger.shared.log("loading engine for \(model.rawValue)", category: "whisper")
        let factory = makeEngine
        let task = Task.detached(priority: .userInitiated) {
            try factory(path.path)
        }
        loadingTasks[model] = task

        do {
            let engine = try await task.value
            engines[model] = engine
            loadingTasks[model] = nil
            loadedModels.insert(model)
            DebugLogger.shared.log("engine loaded for \(model.rawValue)", category: "whisper")
            return engine
        } catch {
            loadingTasks[model] = nil
            DebugLogger.shared.log("FAILED to load engine for \(model.rawValue): \(error)", category: "whisper")
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
        let text = try await runChunked(
            samples: samples,
            engine: engine,
            languageHint: model.languageHint,
            initialPrompt: model.initialPrompt
        )
        let classification = classifier.classify(text: text)
        return TranscriptionResult(
            text: text,
            modelUsed: model,
            languageTag: classification.languageTag,
            languageComponents: classification.components
        )
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
        // Force the same language hint the live preview already used for this
        // model (previously `nil`, i.e. let whisper.cpp auto-detect the language
        // from scratch) - nothing ever consumed that auto-detected language, and
        // auto-detect on short or code-switched audio is exactly the kind of
        // thing that can flip to an unexpected language mid-clip and decode very
        // differently from the same audio's forced-hint pass. That divergence is
        // what made the live preview show real text while the final result came
        // back empty/garbled on stop - forcing the same hint keeps both passes
        // consistent.
        let draftText = try await runChunked(
            samples: samples,
            engine: firstEngine,
            languageHint: defaultModel.languageHint,
            initialPrompt: defaultModel.initialPrompt
        )
        let classification = classifier.classify(text: draftText)

        let shouldReroute = classification.recommendedModel != defaultModel
            && classification.confidence >= reroutingConfidenceThreshold
            && modelStore.isDownloaded(classification.recommendedModel)

        DebugLogger.shared.log(
            "auto-route: draftTextLen=\(draftText.count) tag=\(classification.languageTag.rawValue) "
                + "confidence=\(classification.confidence) reroute=\(shouldReroute ? classification.recommendedModel.rawValue : "no")",
            category: "whisper"
        )

        guard shouldReroute else {
            return TranscriptionResult(
                text: draftText,
                modelUsed: defaultModel,
                languageTag: classification.languageTag,
                languageComponents: classification.components
            )
        }

        let betterEngine = try await loadEngine(for: classification.recommendedModel)
        let finalText = try await runChunked(
            samples: samples,
            engine: betterEngine,
            languageHint: classification.recommendedModel.languageHint,
            initialPrompt: classification.recommendedModel.initialPrompt
        )
        return TranscriptionResult(
            text: finalText,
            modelUsed: classification.recommendedModel,
            languageTag: classification.languageTag,
            languageComponents: classification.components
        )
    }

    /// Splits long recordings into ~30s windows before decoding, per the spec's
    /// memory-optimization requirement, and stitches the text back together.
    /// whisper.cpp can decode longer clips in one call internally, but capping the
    /// window bounds peak memory on older/smaller devices.
    private func runChunked(
        samples: [Float],
        engine: WhisperTranscribing,
        languageHint: String?,
        initialPrompt: String? = nil
    ) async throws -> String {
        // The single choke point every decode (live preview and final result,
        // every model) passes through - the most useful place to log, since a
        // silent-failure bug report ("nothing shows up") is otherwise ambiguous
        // between "audio capture produced nothing" and "whisper.cpp decoded to
        // nothing" without this.
        DebugLogger.shared.log(
            "decode start: samples=\(samples.count) hint=\(languageHint ?? "nil") promptChars=\(initialPrompt?.count ?? 0)",
            category: "whisper"
        )
        do {
            let text = try await runChunkedUninstrumented(samples: samples, engine: engine, languageHint: languageHint, initialPrompt: initialPrompt)
            DebugLogger.shared.log("decode done: textLen=\(text.count)", category: "whisper")
            return text
        } catch {
            DebugLogger.shared.log("decode THREW: \(error)", category: "whisper")
            throw error
        }
    }

    private func runChunkedUninstrumented(
        samples: [Float],
        engine: WhisperTranscribing,
        languageHint: String?,
        initialPrompt: String?
    ) async throws -> String {
        let chunkSize = Int(Constants.chunkDurationSeconds * Constants.sampleRate)
        guard samples.count > chunkSize else {
            let segments = try await engine.transcribe(
                samples: samples,
                options: .init(languageHint: languageHint, initialPrompt: initialPrompt)
            )
            return joined(segments)
        }

        var pieces: [String] = []
        var start = 0
        while start < samples.count {
            let end = min(start + chunkSize, samples.count)
            let segments = try await engine.transcribe(
                samples: Array(samples[start..<end]),
                options: .init(languageHint: languageHint, initialPrompt: initialPrompt)
            )
            pieces.append(joined(segments))
            start = end
        }
        return pieces.joined(separator: " ")
    }

    private func joined(_ segments: [WhisperEngine.Segment]) -> String {
        let text = segments
            .map { TranscriptSanitizer.stripAnnotationTags($0.text) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return customDictionary.apply(to: text)
    }
}
