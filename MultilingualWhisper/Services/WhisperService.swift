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
        /// Length-weighted mean token probability of the kept segments (0…1) -
        /// what the UI shows as "low confidence" below `Constants.lowConfidence`.
        let confidence: Float
    }

    /// One decoded segment's text plus its timing relative to the FULL
    /// recording (not just whichever ~30s chunk it came from) - the timing
    /// is what lets `reprocessSegments` slice the exact matching audio back
    /// out of the original samples for a possible re-decode.
    private struct TimedSegment {
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Float
    }

    /// Confidence of the most recent public decode, length-weighted over the
    /// segments that survived the hallucination filter. 1 when nothing decoded.
    private var lastConfidence: Float = 1

    private(set) var loadedModels: Set<WhisperModelType> = []

    /// Wall-clock split of the most recent `transcribe` / `transcribeWithAutoRouting`
    /// call: everything (model load, routing, every decode pass) versus the share
    /// spent in the Custom Dictionary and `TranscriptFormatter`. Callers fold it
    /// into `LatencyLog` together with their own capture and hand-off stages.
    struct DecodeTimings: Equatable {
        var total: TimeInterval
        var format: TimeInterval
        var decode: TimeInterval { max(0, total - format) }
    }

    private(set) var lastTimings: DecodeTimings?
    private var formatSeconds: TimeInterval = 0

    /// Whether `model` can be used right now (downloaded), for UI that offers a
    /// choice of models - e.g. History's "Re-run with…" menu.
    func isModelAvailable(_ model: WhisperModelType) -> Bool {
        modelStore.isDownloaded(model)
    }

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
    /// see how `MultilingualWhisperApp` constructs and threads it. Deliberately no
    /// default value: unlike `classifier` (a plain, non-isolated struct),
    /// `CustomDictionaryService` is `@MainActor`-isolated, and a caller forgetting to
    /// pass the shared instance would silently construct a second, disconnected one -
    /// making this required forces every call site to make that choice explicitly.
    init(
        modelStore: ModelStoring,
        classifier: LanguageClassifying = RuleBasedLanguageClassifier(),
        customDictionary: CustomDictionaryService,
        cleanupLevel: @escaping () -> CleanupLevel = { AppSettings.shared.cleanupLevel },
        makeEngine: @escaping @Sendable (String) throws -> WhisperTranscribing = { try WhisperEngine(modelPath: $0) }
    ) {
        self.modelStore = modelStore
        self.classifier = classifier
        self.customDictionary = customDictionary
        self.cleanupLevel = cleanupLevel
        self.makeEngine = makeEngine
    }

    /// Read at each decode so a Settings change applies to the very next utterance.
    /// Tests pass `{ .raw }` so their exact-string expectations stay byte-for-byte.
    private let cleanupLevel: () -> CleanupLevel

    /// The `DictationStyle` for the decode in progress - `.standard` (no effect)
    /// unless a caller that knows the destination sets it, which today is only
    /// `FlowSessionEngine` for keyboard dictations: in-app recordings have no host
    /// field to style for. Set before a decode and reset after; decodes never
    /// overlap because there is one microphone.
    var activeStyle: StyleProfile = .standard

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
    ///
    /// `chunkDurationSeconds` defaults to `Constants.chunkDurationSeconds` for any
    /// caller that doesn't care (tests, forced-model paths with no Settings access) -
    /// real UI call sites pass Settings' own "Chunk length" value, previously a
    /// persisted-but-never-read setting (see `AppSettings.maxRecordDurationSeconds`).
    func transcribe(
        samples: [Float],
        using model: WhisperModelType,
        chunkDurationSeconds: TimeInterval = Constants.chunkDurationSeconds
    ) async throws -> TranscriptionResult {
        try await timed { try await transcribeUntimed(samples: samples, using: model, chunkDurationSeconds: chunkDurationSeconds) }
    }

    /// Resets the format share, runs one public decode entry point, and records
    /// `lastTimings` whether it returned or threw.
    private func timed(_ body: () async throws -> TranscriptionResult) async rethrows -> TranscriptionResult {
        formatSeconds = 0
        let started = Date()
        defer { lastTimings = DecodeTimings(total: Date().timeIntervalSince(started), format: formatSeconds) }
        return try await body()
    }

    private func transcribeUntimed(
        samples: [Float],
        using model: WhisperModelType,
        chunkDurationSeconds: TimeInterval
    ) async throws -> TranscriptionResult {
        guard !samples.isEmpty else { throw ServiceError.noAudio }
        let engine = try await loadEngine(for: model)
        let text = finalize(try await runChunked(
            samples: samples,
            engine: engine,
            languageHint: model.languageHint,
            initialPrompt: model.initialPrompt,
            chunkDurationSeconds: chunkDurationSeconds
        ))
        let classification = classifier.classify(text: text)
        return TranscriptionResult(
            text: text,
            modelUsed: model,
            languageTag: classification.languageTag,
            languageComponents: classification.components,
            confidence: lastConfidence
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
        reroutingConfidenceThreshold: Float = 0.6,
        chunkDurationSeconds: TimeInterval = Constants.chunkDurationSeconds
    ) async throws -> TranscriptionResult {
        try await timed {
            try await transcribeWithAutoRoutingUntimed(
                samples: samples,
                defaultModel: defaultModel,
                reroutingConfidenceThreshold: reroutingConfidenceThreshold,
                chunkDurationSeconds: chunkDurationSeconds
            )
        }
    }

    private func transcribeWithAutoRoutingUntimed(
        samples: [Float],
        defaultModel: WhisperModelType,
        reroutingConfidenceThreshold: Float,
        chunkDurationSeconds: TimeInterval
    ) async throws -> TranscriptionResult {
        guard !samples.isEmpty else { throw ServiceError.noAudio }

        let effectiveDefaultModel = try await resolveDefaultModel(samples: samples, fallback: defaultModel)

        let firstEngine = try await loadEngine(for: effectiveDefaultModel)
        // Force the same language hint the live preview already used for this
        // model (previously `nil`, i.e. let whisper.cpp auto-detect the language
        // from scratch) - nothing ever consumed that auto-detected language, and
        // auto-detect on short or code-switched audio is exactly the kind of
        // thing that can flip to an unexpected language mid-clip and decode very
        // differently from the same audio's forced-hint pass. That divergence is
        // what made the live preview show real text while the final result came
        // back empty/garbled on stop - forcing the same hint keeps both passes
        // consistent.
        let draftSegments = try await runChunkedWithSegments(
            samples: samples,
            engine: firstEngine,
            languageHint: effectiveDefaultModel.languageHint,
            initialPrompt: effectiveDefaultModel.initialPrompt,
            chunkDurationSeconds: chunkDurationSeconds
        )
        let draftText = draftSegments.map(\.text).joined(separator: " ")
        let classification = classifier.classify(text: draftText)

        // Whole-clip reroute: the ENTIRE recording reads as confidently a
        // different language - re-decode the whole thing with the better
        // model. Still the right call for e.g. a fully-Arabic recording,
        // where per-segment reprocessing below would just be doing the same
        // whole-clip re-decode in slower, smaller pieces. Compares against
        // effectiveDefaultModel (not the raw defaultModel parameter) since
        // that's the model the draft pass actually ran on - resolveDefaultModel's
        // native pre-check may have already swapped it to Arabic.
        let shouldRerouteWhole = classification.recommendedModel != effectiveDefaultModel
            && classification.confidence >= reroutingConfidenceThreshold
            && modelStore.isDownloaded(classification.recommendedModel)

        DebugLogger.shared.log(
            "auto-route: draftTextLen=\(draftText.count) tag=\(classification.languageTag.rawValue) "
                + "confidence=\(classification.confidence) reroute=\(shouldRerouteWhole ? classification.recommendedModel.rawValue : "no")",
            category: "whisper"
        )

        if shouldRerouteWhole {
            let betterEngine = try await loadEngine(for: classification.recommendedModel)
            let finalText = finalize(try await runChunked(
                samples: samples,
                engine: betterEngine,
                languageHint: classification.recommendedModel.languageHint,
                initialPrompt: classification.recommendedModel.initialPrompt,
                chunkDurationSeconds: chunkDurationSeconds
            ))
            return TranscriptionResult(
                text: finalText,
                modelUsed: classification.recommendedModel,
                languageTag: classification.languageTag,
                languageComponents: classification.components,
                confidence: lastConfidence
            )
        }

        // The whole clip doesn't read as dominantly a different language -
        // but a short embedded phrase in another language (code-switching is
        // the whole point of this app, not an edge case) can be completely
        // invisible to a whole-clip TEXT classifier. Real example from
        // project history: an isolated Malay word got hallucinated into
        // unrelated English text by the default model instead of even being
        // attempted, so there was no Malay keyword left in the final text to
        // catch. Probe each segment's own AUDIO directly instead of only
        // ever re-reading whatever text the default model already committed to.
        // Uses effectiveDefaultModel, same reasoning as shouldRerouteWhole above -
        // reprocessSegments looks up the already-loaded engine for this model,
        // which must match whichever engine actually produced draftSegments.
        let finalSegments = await reprocessSegments(draftSegments, fullSamples: samples, defaultModel: effectiveDefaultModel)
        // finalize once over the whole text, never per segment: a dictionary
        // phrase can span two segments, and capitalisation needs the sentence.
        // (Until 2026-09-10 this path skipped the dictionary and formatter
        // entirely - Auto-Detect, the default mode, shipped uncorrected text
        // whenever no whole-clip reroute happened. Caught by the style tests.)
        let finalText = finalize(finalSegments.map(\.text).joined(separator: " "))
        let finalClassification = classifier.classify(text: finalText)
        lastConfidence = Self.weightedConfidence(finalSegments.map { ($0.text, $0.confidence) })
        return TranscriptionResult(
            text: finalText,
            modelUsed: effectiveDefaultModel,
            languageTag: finalClassification.languageTag,
            languageComponents: finalClassification.components,
            confidence: lastConfidence
        )
    }

    /// Cheap, audio-based pre-check (see `WhisperEngine.arabicLanguageProbability`)
    /// that swaps the two-pass auto-routing's starting model from Singlish to
    /// Arabic when the audio is confidently Arabic - avoiding a full Singlish
    /// transcription pass that the text classifier below would end up discarding
    /// anyway. Only ever a latency optimization, never a correctness requirement:
    /// any failure here (engine not loadable, native call throws) just falls back
    /// to `fallback` and lets the existing draft-transcribe-then-classify routing
    /// below reach the same answer the slower way, as it already did before this
    /// existed. NOT YET VERIFIED ON A REAL DEVICE - see the doc comment on
    /// `WhisperEngine.arabicLanguageProbability`.
    private func resolveDefaultModel(samples: [Float], fallback: WhisperModelType) async throws -> WhisperModelType {
        guard fallback != .arabic, modelStore.isDownloaded(.arabic) else { return fallback }

        let prefixCount = min(samples.count, Int(3.0 * Constants.sampleRate))
        guard let checkEngine = try? await loadEngine(for: fallback),
              let probability = try? await checkEngine.arabicLanguageProbability(samples: Array(samples.prefix(prefixCount))),
              probability >= Constants.arabicPreCheckThreshold
        else {
            return fallback
        }

        DebugLogger.shared.log(
            "native LID pre-check: arabicProbability=\(probability) - starting with Arabic model instead of \(fallback.rawValue)",
            category: "whisper"
        )
        return .arabic
    }

    /// Below this, whisper.cpp's own language detection gets meaningfully
    /// less reliable (per the research behind this feature - see project
    /// memory), so a shorter segment just keeps its draft-pass text
    /// untouched rather than risking a confident-sounding wrong reroute off
    /// too little audio.
    private static let minSegmentDurationToProbe: TimeInterval = 1.0

    /// Checks each segment's own audio against the default model's language
    /// detector, and swaps in a re-decode from a better-suited model for any
    /// segment that confidently disagrees. Segments that agree, or are too
    /// short to trust, keep their original draft-pass text untouched.
    private func reprocessSegments(
        _ segments: [TimedSegment],
        fullSamples: [Float],
        defaultModel: WhisperModelType
    ) async -> [TimedSegment] {
        guard let defaultEngine = engines[defaultModel] else { return segments }

        var result: [TimedSegment] = []
        result.reserveCapacity(segments.count)
        for segment in segments {
            guard segment.endTime - segment.startTime >= Self.minSegmentDurationToProbe else {
                result.append(segment)
                continue
            }
            let startSample = max(0, Int(segment.startTime * Constants.sampleRate))
            let endSample = min(Int(segment.endTime * Constants.sampleRate), fullSamples.count)
            guard startSample < endSample else {
                result.append(segment)
                continue
            }

            let slice = Array(fullSamples[startSample..<endSample])
            if let replacement = await rerouteIfNeeded(slice: slice, defaultEngine: defaultEngine, defaultModel: defaultModel) {
                result.append(TimedSegment(text: replacement.text, startTime: segment.startTime, endTime: segment.endTime, confidence: replacement.confidence))
            } else {
                result.append(segment)
            }
        }
        return result
    }

    /// Returns replacement text for this one segment's audio slice if its
    /// own language detection confidently points at a different model this
    /// app has (Malay/Arabic) than the one already used - nil if it should
    /// keep its existing draft-pass text.
    private func rerouteIfNeeded(
        slice: [Float],
        defaultEngine: WhisperTranscribing,
        defaultModel: WhisperModelType
    ) async -> (text: String, confidence: Float)? {
        // A language-ID probe, not a real decode attempt - languageHint: nil
        // is what makes whisper.cpp actually run its own detector instead of
        // trusting a forced hint. The probe's own transcription is discarded;
        // only the language it detected matters here. (Whisper.cpp does have
        // a cheaper dedicated language-ID-only call, not currently exposed
        // through WhisperEngine - reusing the full transcribe path costs one
        // extra decode per segment, accepted for now, worth revisiting if
        // this needs to get faster.)
        guard (try? await defaultEngine.transcribe(samples: slice, options: .init(languageHint: nil))) != nil else { return nil }
        guard let detectedCode = await defaultEngine.detectedLanguageCode(),
              let recommendedModel = Self.model(forDetectedLanguageCode: detectedCode),
              recommendedModel != defaultModel,
              modelStore.isDownloaded(recommendedModel)
        else { return nil }

        guard let engine = try? await loadEngine(for: recommendedModel),
              let segments = try? await engine.transcribe(
                samples: slice,
                options: .init(languageHint: recommendedModel.languageHint, initialPrompt: recommendedModel.initialPrompt)
              )
        else { return nil }

        let kept = keptSegments(segments)
        let text = rawJoined(kept)
        return text.isEmpty ? nil : (text, Self.weightedConfidence(kept.map { ($0.text, $0.confidence) }))
    }

    /// Only Malay/Arabic have their own dedicated model in this app (see
    /// `RuleBasedLanguageClassifier`, which never recommends anything else
    /// either) - a segment detected as English, or any language this app
    /// doesn't have a model for, just stays on the default model.
    private static func model(forDetectedLanguageCode code: String) -> WhisperModelType? {
        switch code {
        case "ar": return .arabic
        case "ms": return .malay
        default: return nil
        }
    }

    /// Splits long recordings into ~30s windows before decoding, per the spec's
    /// memory-optimization requirement, and stitches the text back together.
    /// whisper.cpp can decode longer clips in one call internally, but capping the
    /// window bounds peak memory on older/smaller devices.
    private func runChunked(
        samples: [Float],
        engine: WhisperTranscribing,
        languageHint: String?,
        initialPrompt: String? = nil,
        chunkDurationSeconds: TimeInterval = Constants.chunkDurationSeconds
    ) async throws -> String {
        // The single choke point every decode (live preview and final result,
        // every model) passes through - the most useful place to log, since a
        // silent-failure bug report ("nothing shows up") is otherwise ambiguous
        // between "audio capture produced nothing" and "whisper.cpp decoded to
        // nothing" without this.
        DebugLogger.shared.log(
            "decode start: samples=\(samples.count) hint=\(languageHint ?? "nil") promptChars=\(initialPrompt?.count ?? 0) chunkSeconds=\(chunkDurationSeconds)",
            category: "whisper"
        )
        do {
            let text = try await runChunkedUninstrumented(samples: samples, engine: engine, languageHint: languageHint, initialPrompt: initialPrompt, chunkDurationSeconds: chunkDurationSeconds)
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
        initialPrompt: String?,
        chunkDurationSeconds: TimeInterval = Constants.chunkDurationSeconds
    ) async throws -> String {
        let chunkSize = Int(chunkDurationSeconds * Constants.sampleRate)
        var kept: [WhisperEngine.Segment] = []
        var start = 0
        repeat {
            let end = min(start + chunkSize, samples.count)
            let segments = try await engine.transcribe(
                samples: Array(samples[start..<end]),
                options: .init(languageHint: languageHint, initialPrompt: initialPrompt)
            )
            kept.append(contentsOf: keptSegments(segments))
            start = end
        } while start < samples.count
        lastConfidence = Self.weightedConfidence(kept.map { ($0.text, $0.confidence) })
        return rawJoined(kept)
    }

    /// Same chunking as `runChunkedUninstrumented`, but keeps each segment
    /// separate (with its timing adjusted to be relative to the FULL
    /// recording, not just its own chunk) instead of immediately flattening
    /// everything into one string - `transcribeWithAutoRouting`'s per-segment
    /// reprocessing needs the timing to slice the original audio back out;
    /// the forced-model path (`transcribe(using:)`) never reroutes anything,
    /// so it has no reason to carry this extra complexity and keeps using
    /// the simpler `runChunked` instead.
    private func runChunkedWithSegments(
        samples: [Float],
        engine: WhisperTranscribing,
        languageHint: String?,
        initialPrompt: String?,
        chunkDurationSeconds: TimeInterval = Constants.chunkDurationSeconds
    ) async throws -> [TimedSegment] {
        let chunkSize = Int(chunkDurationSeconds * Constants.sampleRate)
        guard samples.count > chunkSize else {
            let segments = try await engine.transcribe(
                samples: samples,
                options: .init(languageHint: languageHint, initialPrompt: initialPrompt)
            )
            return timedSegments(from: segments, chunkStartTime: 0)
        }

        var all: [TimedSegment] = []
        var start = 0
        while start < samples.count {
            let end = min(start + chunkSize, samples.count)
            let chunkStartTime = Double(start) / Constants.sampleRate
            let segments = try await engine.transcribe(
                samples: Array(samples[start..<end]),
                options: .init(languageHint: languageHint, initialPrompt: initialPrompt)
            )
            all.append(contentsOf: timedSegments(from: segments, chunkStartTime: chunkStartTime))
            start = end
        }
        return all
    }

    private func timedSegments(from segments: [WhisperEngine.Segment], chunkStartTime: TimeInterval) -> [TimedSegment] {
        keptSegments(segments).compactMap { segment in
            let text = TranscriptSanitizer.stripAnnotationTags(segment.text)
            guard !text.isEmpty else { return nil }
            return TimedSegment(text: text, startTime: chunkStartTime + segment.startTime, endTime: chunkStartTime + segment.endTime, confidence: segment.confidence)
        }
    }

    /// The hallucination filter: drops segments `TranscriptSanitizer` recognises
    /// as Whisper's silence phrases, using the decoder's own no-speech probability
    /// and token confidence for the borderline ones. Every drop is logged so a
    /// wrongly-dropped real phrase can be found in the debug log.
    private func keptSegments(_ segments: [WhisperEngine.Segment]) -> [WhisperEngine.Segment] {
        segments.filter { segment in
            let text = TranscriptSanitizer.stripAnnotationTags(segment.text)
            let drop = TranscriptSanitizer.isLikelyHallucination(text, noSpeechProbability: segment.noSpeechProbability, confidence: segment.confidence)
            if drop {
                DebugLogger.shared.log(
                    "dropped hallucinated segment '\(text)' noSpeech=\(segment.noSpeechProbability) confidence=\(segment.confidence)",
                    category: "whisper"
                )
            }
            return !drop
        }
    }

    /// Mean confidence weighted by text length, so one uncertain word does not
    /// outweigh a confident sentence. 1 when there is no text.
    static func weightedConfidence(_ parts: [(text: String, confidence: Float)]) -> Float {
        let weighted = parts.map { (Float($0.text.count), $0.confidence) }.filter { $0.0 > 0 }
        let total = weighted.reduce(0) { $0 + $1.0 }
        guard total > 0 else { return 1 }
        return weighted.reduce(0) { $0 + $1.0 * $1.1 } / total
    }

    /// Decoder output with whisper's annotation tags stripped and segments joined
    /// - no dictionary, no formatting. Every decode pass produces this; only the
    /// final text of a public entry point goes through `finalize`.
    private func rawJoined(_ segments: [WhisperEngine.Segment]) -> String {
        segments
            .map { TranscriptSanitizer.stripAnnotationTags($0.text) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The one place the Custom Dictionary and `TranscriptFormatter` run, on the
    /// complete text of a decode. Dictionary first (it fixes *words*), then the
    /// formatter (it fixes *text*) - so a correction like "m r t" -> "MRT" is in
    /// place before capitalisation and number rules look at the line.
    private func finalize(_ text: String) -> String {
        let started = Date()
        defer { formatSeconds += Date().timeIntervalSince(started) }
        let corrected = customDictionary.apply(to: text)
        return TranscriptFormatter.format(corrected, level: cleanupLevel(), profile: activeStyle)
    }
}
