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
    /// How long the input must stay below threshold before auto-stop fires.
    var silenceTimeout: TimeInterval = 1.6

    private let audioEngine = AVAudioEngine()
    private var samples: [Float] = []
    private var recordingStartDate: Date?
    private var silenceStartDate: Date?
    private var onAutoStop: (() -> Void)?

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
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = audioEngine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: Self.targetFormat) else {
            throw AudioServiceError.engineSetupFailed
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let converted = Self.convert(buffer, using: converter) else { return }
            let (chunk, rms) = converted
            Task { @MainActor in
                self.ingest(chunk: chunk, rms: rms)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
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
        guard vadEnabled else { return }
        // rms on 16-bit-normalized Float32 speech is typically well under 0.1;
        // vadThreshold (0...1, from Settings) is scaled down into that range.
        let silenceCutoff = vadThreshold * 0.05
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
