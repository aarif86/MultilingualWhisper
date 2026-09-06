import AVFoundation
import Accelerate
import Observation

/// Records microphone audio and exposes it as 16kHz mono Float32 samples — the
/// exact format `WhisperEngine` / whisper.cpp expects, so nothing downstream
/// needs to know or care what the hardware's native format was.
@MainActor
@Observable
final class AudioService {

    enum AudioServiceError: Error, LocalizedError {
        case permissionDenied
        case alreadyRecording
        case engineSetupFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Microphone access was denied. Enable it in Settings to record."
            case .alreadyRecording: return "Already recording."
            case .engineSetupFailed: return "Couldn't set up the audio engine."
            }
        }
    }

    /// 0...1 smoothed input level, for a level meter / waveform UI.
    private(set) var currentLevel: Float = 0
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0

    /// When true, a sustained quiet period auto-stops the recording (`onAutoStop`).
    /// When false, recording only stops when `stopRecording()` is called explicitly.
    var vadEnabled = true
    var vadThreshold: Float = Constants.defaultVADThreshold
    /// How long the input must stay below threshold before auto-stop fires. 1.6s
    /// was too aggressive in practice - the natural pause between tapping record
    /// and actually starting to speak was often longer than that on its own,
    /// auto-stopping before the user said anything.
    var silenceTimeout: TimeInterval = 2.5
    /// VAD doesn't evaluate at all until this much time has passed, so the normal
    /// "tap record, take a breath, start talking" beat never gets misread as
    /// trailing silence from a previous (nonexistent) utterance.
    private let vadGracePeriod: TimeInterval = 1.2

    private let audioEngine = AVAudioEngine()
    private var samples: [Float] = []
    private var recordingStartDate: Date?
    private var silenceStartDate: Date?
    private var onAutoStop: (() -> Void)?
    private var sampleStreamTask: Task<Void, Never>?
    private var sampleContinuation: AsyncStream<(samples: [Float], rms: Float)>.Continuation?

    // `nonisolated(unsafe)`: read-only after init, and accessed from `convert` below,
    // which deliberately runs off the main actor (on the audio render thread) - a
    // plain `static let` here would inherit this class's `@MainActor` isolation and
    // make it illegal to touch from that nonisolated context.
    nonisolated(unsafe) private static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Constants.sampleRate,
        channels: 1,
        interleaved: false
    )!

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording(onAutoStop: (() -> Void)? = nil) throws {
        guard !isRecording else { throw AudioServiceError.alreadyRecording }
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw AudioServiceError.permissionDenied
        }

        self.onAutoStop = onAutoStop
        samples.removeAll(keepingCapacity: true)
        silenceStartDate = nil
        currentLevel = 0
        elapsed = 0

        let session = AVAudioSession.sharedInstance()
        // .measurement disables the system's automatic gain control, which produced
        // real speech quiet enough to misread as silence on-device. .default keeps
        // normal AGC, giving levels much closer to what the VAD threshold assumes -
        // Whisper is trained on a huge range of real-world (including AGC'd) audio,
        // so this doesn't meaningfully cost transcription quality.
        try session.setCategory(.record, mode: .default, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = audioEngine.inputNode

        // Querying inputNode.outputFormat(forBus:) before the engine has ever been
        // prepared/started can report a stale format on some devices, silently
        // producing a converter built for the wrong sample rate. Passing `format:
        // nil` here makes the tap use the bus's actual current format instead of a
        // predicted one, and the converter below is built from that same delivered
        // buffer - so it can never mismatch what's really being captured.
        var converter: AVAudioConverter?

        // Audio taps fire roughly every 80-100ms on a dedicated real-time thread.
        // Spawning an independent `Task { @MainActor in ... }` per callback (the
        // previous approach) does NOT guarantee those tasks run in the order they
        // were created once several are in flight - which, for something that
        // appends sequential audio chunks to a growing buffer, can silently
        // reorder samples into something that no longer sounds like speech at all
        // to Whisper (it doesn't crash; it just transcribes to nothing, or garbage).
        // AsyncStream guarantees delivery in yield order, which a scattered `Task {}`
        // per callback does not - so every chunk funnels through one continuation
        // into one single long-lived consuming task instead.
        let (stream, continuation) = AsyncStream<(samples: [Float], rms: Float)>.makeStream()
        sampleContinuation?.finish()
        sampleContinuation = continuation
        sampleStreamTask?.cancel()
        sampleStreamTask = Task { @MainActor [weak self] in
            for await (chunk, rms) in stream {
                self?.ingest(chunk: chunk, rms: rms)
            }
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, _ in
            if converter == nil {
                converter = AVAudioConverter(from: buffer.format, to: Self.targetFormat)
            }
            guard let converter, let converted = Self.convert(buffer, using: converter) else { return }
            continuation.yield(converted)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            continuation.finish()
            sampleContinuation = nil
            throw error
        }

        isRecording = true
        recordingStartDate = Date()
    }

    @discardableResult
    func stopRecording() -> [Float] {
        guard isRecording else { return samples }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        // Ends the stream so the consuming Task in startRecording finishes on its
        // own rather than being left running: everything already yielded is still
        // delivered in order first, .finish() just stops new values afterwards.
        sampleContinuation?.finish()
        sampleContinuation = nil
        isRecording = false
        recordingStartDate = nil
        onAutoStop = nil
        return samples
    }

    // MARK: - Main-actor state updates (called from the tap's Task hop)

    private func ingest(chunk: [Float], rms: Float) {
        guard isRecording else { return }
        samples.append(contentsOf: chunk)
        currentLevel = min(1, rms * 6)
        if let start = recordingStartDate {
            elapsed = Date().timeIntervalSince(start)
        }
        evaluateVAD(rms: rms)
    }

    private func evaluateVAD(rms: Float) {
        guard vadEnabled, elapsed > vadGracePeriod else { return }
        // rms on 16-bit-normalized Float32 speech is typically well under 0.1;
        // vadThreshold (0...1, from Settings) is scaled down into that range. This
        // multiplier was too high in practice (0.05, i.e. cutoff 0.035 at the
        // default threshold) - real speech was measured quiet enough to read as
        // "silence" continuously. Lowered so only near-total silence counts.
        let silenceCutoff = vadThreshold * 0.015
        if rms < silenceCutoff {
            if silenceStartDate == nil { silenceStartDate = Date() }
            if let start = silenceStartDate,
               Date().timeIntervalSince(start) > silenceTimeout,
               elapsed > 0.5 {
                let callback = onAutoStop
                stopRecording()
                callback?()
            }
        } else {
            silenceStartDate = nil
        }
    }

    // MARK: - Format conversion (runs on the audio render thread - no `self`, no isolation)

    /// Converts one input buffer to 16kHz mono Float32 and computes its RMS.
    /// Returns an owned `[Float]` copy (never the buffer's own backing pointer,
    /// which is not guaranteed to outlive this call) so it's safe to hand across
    /// the actor hop into `ingest`.
    nonisolated private static func convert(
        _ buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter
    ) -> (samples: [Float], rms: Float)? {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else {
            return nil
        }

        // AVAudioConverter may pull from this block more than once per `convert`
        // call; only hand it real data the first time, or it will loop forever
        // re-consuming the same buffer.
        var inputConsumed = false
        var conversionError: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: outBuffer, error: &conversionError, withInputFrom: inputBlock)
        guard conversionError == nil, let channelData = outBuffer.floatChannelData else { return nil }

        let frameCount = Int(outBuffer.frameLength)
        guard frameCount > 0 else { return nil }
        let pointer = UnsafeBufferPointer(start: channelData[0], count: frameCount)

        var rms: Float = 0
        vDSP_rmsqv(pointer.baseAddress!, 1, &rms, vDSP_Length(frameCount))

        return (Array(pointer), rms)
    }
}
