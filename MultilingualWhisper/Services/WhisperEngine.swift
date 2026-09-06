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
    }

    struct Segment {
        let text: String
        let startTime: TimeInterval
        let endTime: TimeInterval
    }

    private let context: OpaquePointer

    init(modelPath: String, useGPU: Bool = true) throws {
        var contextParams = whisper_context_default_params()
        contextParams.use_gpu = useGPU

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

        let languageCStr = options.languageHint.map { strdup($0) } ?? nil
        let promptCStr = options.initialPrompt.map { strdup($0) } ?? nil
        defer {
            free(languageCStr)
            free(promptCStr)
        }
        params.language = UnsafePointer(languageCStr)
        params.initial_prompt = UnsafePointer(promptCStr)

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
                Segment(text: String(cString: cText), startTime: Double(t0) / 100.0, endTime: Double(t1) / 100.0)
            )
        }
        return segments
    }

    /// Language whisper.cpp itself detected on the most recent `transcribe` call.
    /// Only meaningful when that call was made with `languageHint == nil`.
    func detectedLanguageCode() -> String? {
        let id = whisper_full_lang_id(context)
        guard id >= 0, let cStr = whisper_lang_str(id) else { return nil }
        return String(cString: cStr)
    }
}
