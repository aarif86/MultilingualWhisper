import whisper
import Foundation

/// Thin wrapper around one loaded whisper.cpp context (one GGML model file).
///
/// Modeled as a Swift `actor` because a `whisper_context` is not safe for
/// concurrent use — the actor gives us that serialization for free instead of
/// hand-rolling a lock. `init` is synchronous and does real file I/O + a large
/// mmap, so always create instances from a non-`@MainActor` async context
/// (see `WhisperService.loadModel`) so it doesn't block the UI thread.
actor WhisperEngine {

    enum EngineError: Error, LocalizedError {
        case failedToLoadModel(path: String)
        case transcriptionFailed
        case emptyAudio

        var errorDescription: String? {
            switch self {
            case .failedToLoadModel(let path): return "Couldn't load whisper model at \(path)."
            case .transcriptionFailed: return "Transcription failed."
            case .emptyAudio: return "No audio to transcribe."
            }
        }
    }

    struct TranscriptionOptions {
        /// ISO-639-1 code (e.g. "en", "ar"). `nil` lets whisper.cpp auto-detect.
        var languageHint: String?
        var translateToEnglish: Bool = false
        var threadCount: Int32 = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 1))
        /// Prepended as decoder context - handy for biasing towards expected vocabulary.
        var initialPrompt: String?
        /// Re-prepend `initialPrompt` to every 30 s decode window, not just the
        /// first, so a vocabulary glossary keeps working through a long dictation.
        var carryInitialPrompt: Bool = true

        // Hallucination guards (docs/competitor-kb/engine-best-practices.md,
        // "Hallucination & robustness controls"). Set explicitly rather than
        // inherited from whisper_full_default_params so a library upgrade can't
        // silently change them, and so they are visible here for tuning.
        /// A segment whose no-speech probability exceeds this, while its average
        /// log-probability is below `logprobThreshold`, is treated as silence.
        var noSpeechThreshold: Float = 0.6
        /// Decode is retried at a higher temperature when the segment's entropy
        /// (repetition) exceeds this - the "compression ratio" guard.
        var entropyThreshold: Float = 2.4
        var logprobThreshold: Float = -1.0
        /// Temperature step for each fallback retry; 0 disables fallback.
        var temperatureIncrement: Float = 0.2
        /// Ban whisper's non-speech tokens ("(music)", "♪", "[BLANK_AUDIO]") at
        /// decode time - a dictation never wants them.
        var suppressNonSpeechTokens: Bool = true
        /// Regex over single token strings to ban outright (token-level, so only
        /// useful for individual symbols, not phrases - see TranscriptSanitizer for
        /// the phrase-level bag of hallucinations).
        var suppressRegex: String?

        // Silero VAD (whisper.cpp's bundled implementation). With a model path set,
        // whisper_full first runs the VAD over the audio and decodes only the
        // speech segments, joined with 0.1 s of silence - the cheapest and most
        // effective hallucination guard of all is not feeding the model silence
        // (Superwhisper "Remove Silence"). Segment times are mapped back to the
        // original timeline, so per-segment reprocessing keeps working. nil = off.
        var vadModelPath: String?
        var vadThreshold: Float = 0.5
        var vadMinSpeechMs: Int32 = 250
        var vadMinSilenceMs: Int32 = 100
        var vadSpeechPadMs: Int32 = 30
    }

    struct Segment {
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        /// whisper's own estimate that this window held no speech (0…1).
        let noSpeechProbability: Float
        /// Mean probability of the text tokens (0…1); 1 when unknown.
        let confidence: Float

        init(text: String, startTime: TimeInterval, endTime: TimeInterval, noSpeechProbability: Float = 0, confidence: Float = 1) {
            self.text = text
            self.startTime = startTime
            self.endTime = endTime
            self.noSpeechProbability = noSpeechProbability
            self.confidence = confidence
        }
    }

    private let context: OpaquePointer

    init(modelPath: String) throws {
        var contextParams = whisper_context_default_params()
        // CPU only, not a performance default - confirmed via a real device
        // log that GPU decode fails instantly (whisper_full returns nonzero,
        // no crash) whenever it runs while the app is backgrounded, which
        // FlowSessionEngine's whole design requires. iOS enforces this at the
        // OS level (kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted -
        // "insufficient permission to submit GPU work from background"), not
        // something whisper.cpp or this app can opt out of. CPU compute has
        // no such restriction. These are all "small" GGML models already
        // fast enough on CPU alone (see decode timings in any debug log) -
        // not a meaningful speed trade-off for the reliability this buys.
        contextParams.use_gpu = false

        guard let ctx = modelPath.withCString({ whisper_init_from_file_with_params($0, contextParams) }) else {
            throw EngineError.failedToLoadModel(path: modelPath)
        }
        context = ctx
    }

    deinit {
        whisper_free(context)
    }

    /// `samples` must already be 16kHz mono Float32 PCM (see `AudioService`).
    func transcribe(samples: [Float], options: TranscriptionOptions = .init()) throws -> [Segment] {
        guard !samples.isEmpty else { throw EngineError.emptyAudio }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_special = false
        params.print_realtime = false
        params.print_timestamps = false
        params.translate = options.translateToEnglish
        params.n_threads = options.threadCount
        params.no_context = true
        params.detect_language = options.languageHint == nil
        params.carry_initial_prompt = options.carryInitialPrompt && options.initialPrompt != nil
        params.suppress_blank = true
        params.suppress_nst = options.suppressNonSpeechTokens
        params.no_speech_thold = options.noSpeechThreshold
        params.entropy_thold = options.entropyThreshold
        params.logprob_thold = options.logprobThreshold
        params.temperature_inc = options.temperatureIncrement

        let languageCStr = options.languageHint.map { strdup($0) } ?? nil
        let promptCStr = options.initialPrompt.map { strdup($0) } ?? nil
        let suppressCStr = options.suppressRegex.map { strdup($0) } ?? nil
        let vadPathCStr = options.vadModelPath.map { strdup($0) } ?? nil
        defer {
            free(languageCStr)
            free(promptCStr)
            free(suppressCStr)
            free(vadPathCStr)
        }
        params.language = UnsafePointer(languageCStr)
        params.initial_prompt = UnsafePointer(promptCStr)
        params.suppress_regex = UnsafePointer(suppressCStr)

        if let vadPathCStr {
            params.vad = true
            params.vad_model_path = UnsafePointer(vadPathCStr)
            var vad = whisper_vad_default_params()
            vad.threshold = options.vadThreshold
            vad.min_speech_duration_ms = options.vadMinSpeechMs
            vad.min_silence_duration_ms = options.vadMinSilenceMs
            vad.speech_pad_ms = options.vadSpeechPadMs
            params.vad_params = vad
        }

        let status = samples.withUnsafeBufferPointer { buffer in
            whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
        }
        guard status == 0 else { throw EngineError.transcriptionFailed }

        let segmentCount = whisper_full_n_segments(context)
        var segments: [Segment] = []
        segments.reserveCapacity(Int(segmentCount))
        for i in 0..<segmentCount {
            guard let cText = whisper_full_get_segment_text(context, i) else { continue }
            let t0 = whisper_full_get_segment_t0(context, i) // centiseconds
            let t1 = whisper_full_get_segment_t1(context, i)
            segments.append(
                Segment(
                    text: String(cString: cText),
                    startTime: Double(t0) / 100.0,
                    endTime: Double(t1) / 100.0,
                    noSpeechProbability: whisper_full_get_segment_no_speech_prob(context, i),
                    confidence: meanTokenProbability(segment: i)
                )
            )
        }
        return segments
    }

    /// Mean probability of the segment's text tokens (timestamp and other special
    /// tokens excluded - everything at or past `whisper_token_eot` is special).
    /// Hallucinated text tends to come with low per-token probability, which makes
    /// this the second hallucination signal after `no_speech_prob`, and what the UI
    /// shows as "low confidence".
    private func meanTokenProbability(segment: Int32) -> Float {
        let eot = whisper_token_eot(context)
        var total: Float = 0
        var count = 0
        for j in 0..<whisper_full_n_tokens(context, segment) {
            guard whisper_full_get_token_id(context, segment, j) < eot else { continue }
            total += whisper_full_get_token_p(context, segment, j)
            count += 1
        }
        return count == 0 ? 1 : total / Float(count)
    }

    /// Language whisper.cpp itself detected on the most recent `transcribe` call.
    /// Only meaningful when that call was made with `languageHint == nil`.
    func detectedLanguageCode() -> String? {
        let id = whisper_full_lang_id(context)
        guard id >= 0, let cStr = whisper_lang_str(id) else { return nil }
        return String(cString: cStr)
    }

    /// Runs whisper.cpp's own audio-based language detection - just the encoder
    /// plus a cheap classification head (`whisper_pcm_to_mel` + `whisper_lang_auto_detect`),
    /// not a full decode - to answer one narrow question: how likely is this audio
    /// to be Arabic? Whisper's own language IDs have no concept of "Singlish" vs.
    /// standard English, so this can only meaningfully help the Arabic/non-Arabic
    /// routing decision, not the finer classification `RuleBasedLanguageClassifier`
    /// already does from text - see docs/code-switching-research.md Part 4, where
    /// `whisper_lang_auto_detect`'s exact signature was confirmed directly against
    /// this app's pinned whisper.cpp submodule commit.
    ///
    /// NOT YET VERIFIED ON A REAL DEVICE - written and reasoned through without a
    /// Mac in this session. Compiles and is exercised by
    /// `WhisperServiceRoutingTests` against a fake engine, but the actual native
    /// call sequence (`whisper_pcm_to_mel` then `whisper_lang_auto_detect` against
    /// a real loaded context) has not run once for real. Confirm it behaves before
    /// this reaches TestFlight.
    func arabicLanguageProbability(samples: [Float]) throws -> Float {
        guard !samples.isEmpty else { throw EngineError.emptyAudio }

        let threadCount = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 1))
        let melStatus = samples.withUnsafeBufferPointer { buffer in
            whisper_pcm_to_mel(context, buffer.baseAddress, Int32(buffer.count), threadCount)
        }
        guard melStatus == 0 else { throw EngineError.transcriptionFailed }

        let arabicId = whisper_lang_id("ar")
        guard arabicId >= 0 else { return 0 }

        let maxId = whisper_lang_max_id()
        guard maxId >= 0 else { return 0 }

        var probabilities = [Float](repeating: 0, count: Int(maxId) + 1)
        let bestId = probabilities.withUnsafeMutableBufferPointer { buffer in
            whisper_lang_auto_detect(context, 0, threadCount, buffer.baseAddress)
        }
        guard bestId >= 0, Int(arabicId) < probabilities.count else { return 0 }
        return probabilities[Int(arabicId)]
    }
}

/// What `WhisperService` actually needs from a loaded model. `WhisperEngine`
/// conforms for real use; tests substitute a fake that returns canned text
/// instead of running the real whisper.cpp decoder, so the *routing/plumbing*
/// logic in `WhisperService` (which language hint each pass uses, how results
/// get combined) can be verified in milliseconds - no model file, no audio
/// hardware, no physical device required. Genuine transcription *accuracy*
/// still needs a real device; this only covers the code paths around it.
/// See `WhisperServiceRoutingTests`.
protocol WhisperTranscribing: Sendable {
    func transcribe(samples: [Float], options: WhisperEngine.TranscriptionOptions) async throws -> [WhisperEngine.Segment]
    func arabicLanguageProbability(samples: [Float]) async throws -> Float
    /// See `WhisperEngine.detectedLanguageCode()`. Part of the protocol (not
    /// just a `WhisperEngine`-only method) so `WhisperService`'s per-segment
    /// code-switching reprocessing can call it without downcasting away from
    /// this protocol - which would make that logic untestable with a fake.
    func detectedLanguageCode() async -> String?
}

extension WhisperEngine: WhisperTranscribing {}
