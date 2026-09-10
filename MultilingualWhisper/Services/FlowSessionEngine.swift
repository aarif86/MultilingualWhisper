import Accelerate
import ActivityKit
import AVFoundation
import Observation
import SwiftData
import UIKit

/// Keeps a continuously-running audio engine alive for the duration of a
/// "Flow session" so the keyboard extension can trigger individual
/// dictations via Darwin notifications without the main app needing to be
/// relaunched into the foreground for every single utterance - the whole
/// point being to match Wispr Flow's "activate once, dictate repeatedly
/// straight from the keyboard" flow instead of QuickDictateView's one
/// hand-off per utterance.
///
/// The engine has to genuinely keep running the whole session, not just sit
/// "active" between utterances: iOS's background-audio grant (UIBackgroundModes
/// = audio) only keeps an app alive while it's actually doing audio I/O, not
/// merely because AVAudioSession.setActive(true) was called once. An idle
/// session with no engine running would very likely get suspended the moment
/// the user backgrounds the app - before the keyboard ever gets a chance to
/// signal it. This is the one part of this feature that's genuinely
/// unverified until tested for real - see project memory.
///
/// Deliberately separate from AudioService/TranscriptionViewModel rather than
/// reusing them: their startRecording()/stopRecording() pair the engine's
/// lifetime 1:1 with a single recording, which is the wrong shape here (the
/// engine must outlive any individual utterance) - and AudioService has
/// already been hardened through three separate real-device bugs for that
/// different shape, so this avoids risking a regression there.
@MainActor
@Observable
final class FlowSessionEngine {

    private(set) var isActive = false
    private(set) var isRecording = false
    private(set) var lastError: String?

    private let audioEngine = AVAudioEngine()
    private let whisperService: WhisperService
    private let settings: AppSettings
    private let modelContext: ModelContext

    private var samples: [Float] = []
    private var isCapturingUtterance = false
    /// The utterance being captured was started in command mode (keyboard
    /// long-press) - it will be interpreted as a `VoiceCommand`, never inserted.
    private var isCommandUtterance = false
    private var utteranceStartDate: Date?
    /// When the input first dropped below the silence cutoff during this
    /// utterance; nil while speech is heard. See `evaluateSilence`.
    private var silenceStartDate: Date?
    /// The decode started by the silence auto-stop, awaitable by tests.
    private var autoStopTask: Task<Void, Never>?
    private var sampleStreamTask: Task<Void, Never>?
    private var sampleContinuation: AsyncStream<[Float]>.Continuation?
    private var startObserver: DarwinNotification.Observer?
    private var stopObserver: DarwinNotification.Observer?
    private var endObserver: DarwinNotification.Observer?
    /// The "Flow is on" Live Activity (FlowLiveActivity) for this session.
    private var liveActivity: Activity<FlowActivityAttributes>?
    private var idleTimer: Timer?
    /// See `checkIdle` - injectable so tests don't wait half an hour.
    private let idleTimeout: TimeInterval
    private let latencyLog: LatencyLog

    // `nonisolated(unsafe)`: read-only after init, touched from `convert`
    // which deliberately runs off the main actor - see AudioService's
    // identical property for the same reasoning.
    nonisolated(unsafe) private static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: Constants.sampleRate,
        channels: 1,
        interleaved: false
    )!

    init(
        whisperService: WhisperService,
        modelContainer: ModelContainer,
        settings: AppSettings = .shared,
        idleTimeout: TimeInterval = Constants.flowSessionIdleTimeout,
        latencyLog: LatencyLog = .shared
    ) {
        self.whisperService = whisperService
        self.modelContext = ModelContext(modelContainer)
        self.settings = settings
        self.idleTimeout = idleTimeout
        self.latencyLog = latencyLog

        // Registered immediately at app launch (this is created as app-level
        // @State), not lazily on activation - so a signal arriving is never
        // racing against "has this even been set up yet".
        startObserver = DarwinNotification.observe(FlowSessionState.startUtterance) { [weak self] in
            Task { @MainActor in self?.handleStartSignal() }
        }
        stopObserver = DarwinNotification.observe(FlowSessionState.stopUtterance) { [weak self] in
            Task { @MainActor in self?.handleStopSignal() }
        }
        endObserver = DarwinNotification.observe(FlowSessionState.endSession) { [weak self] in
            Task { @MainActor in
                DebugLogger.shared.log("FlowSession end requested from the Live Activity", category: "flow")
                self?.end()
            }
        }

        // The app can be relaunched by the system independently of any
        // session the user thinks is still running (killed for memory, or
        // just force-quit) - always start from a clean "not active" state
        // rather than trusting a flag left over from a previous process.
        FlowSessionState.clear()
    }

    // MARK: - Session lifecycle (main app UI calls these)

    @discardableResult
    func activate() async -> Bool {
        guard !isActive else { return true }

        if AVAudioApplication.shared.recordPermission != .granted {
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard granted else {
                lastError = "Microphone access is required for Flow. Enable it in Settings."
                DebugLogger.shared.log("FlowSession activate: mic permission denied", category: "flow")
                return false
            }
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // Same category/mode as AudioService's proven-working
            // configuration - deliberately not introducing a second unverified
            // variable (e.g. .playAndRecord) alongside the background-survival
            // question this feature already rests on.
            try session.setCategory(.record, mode: .default, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try startEngine()
        } catch {
            lastError = error.localizedDescription
            DebugLogger.shared.log("FlowSession activate failed: \(error)", category: "flow")
            return false
        }

        isActive = true
        lastError = nil
        FlowSessionState.isActive = true
        touchIdleDeadline()
        armIdleTimer()
        startLiveActivity()
        DebugLogger.shared.log("FlowSession activated - engine running continuously", category: "flow")
        // Start capturing the very first utterance immediately, rather than
        // waiting for a separate keyboard tap on top of Start Flow + swiping
        // back - the continuous engine above is already running the mic by
        // this point (that's the whole reason it has to be continuous), so
        // making the user tap "Tap to speak" again right after was a pure
        // extra step, not a real second decision. handleStartSignal() posts
        // its own stateChanged notification, which covers isActive and
        // isRecording flipping together in one push to the keyboard.
        handleStartSignal()
        return true
    }

    func end() {
        guard isActive else { return }
        // Resets isCapturingUtterance/isRecording/samples inline rather than
        // calling finishUtterance(publish: false) - that used to be
        // synchronous, but finishUtterance is `async` now (see the comment
        // on handleStopSignal), and end() needs these true immediately, not
        // on whatever later tick a fire-and-forget Task happens to run
        // (caught by a real test: isRecording was still true right after
        // end() returned). FlowSessionState.clear() below already covers
        // every *shared* field finishUtterance(publish: false) would have
        // touched, so nothing here is actually lost by not calling it.
        isCapturingUtterance = false
        isCommandUtterance = false
        isRecording = false
        samples.removeAll(keepingCapacity: true)
        idleTimer?.invalidate()
        idleTimer = nil
        stopEngine()
        isActive = false
        endLiveActivity()
        FlowSessionState.clear()
        DarwinNotification.post(FlowSessionState.stateChanged)
        DebugLogger.shared.log("FlowSession ended", category: "flow")
    }

    // MARK: - Live Activity ("Flow is on" in the Dynamic Island / Lock Screen)

    /// Started with the session and ended with it, so the open microphone is
    /// always visible at the top of the screen with a one-tap Off. Every call is
    /// a no-op when Live Activities are unavailable (Settings, Simulator, tests).
    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let now = Date()
        let content = ActivityContent(state: FlowActivityAttributes.ContentState(isRecording: false, since: now), staleDate: nil)
        do {
            liveActivity = try Activity.request(attributes: FlowActivityAttributes(startedAt: now), content: content, pushType: nil)
        } catch {
            DebugLogger.shared.log("Live Activity request failed: \(error)", category: "flow")
        }
    }

    private func updateLiveActivity(isRecording: Bool) {
        guard let liveActivity else { return }
        let content = ActivityContent(state: FlowActivityAttributes.ContentState(isRecording: isRecording, since: Date()), staleDate: nil)
        Task { await liveActivity.update(content) }
    }

    private func endLiveActivity() {
        guard let liveActivity else { return }
        self.liveActivity = nil
        Task { await liveActivity.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: - Idle timeout

    /// The microphone stays open for the whole session, so a session nobody is
    /// using is pure battery drain (and the keyboard's own reviews for the
    /// category say users notice). Every dictation pushes the deadline out by
    /// `idleTimeout`; a timer checks it, and the keyboard reads the same deadline
    /// to warn shortly before - see `FlowSessionState.idleDeadline`.
    private func touchIdleDeadline(now: Date = Date()) {
        FlowSessionState.idleDeadline = now.addingTimeInterval(idleTimeout)
    }

    private func armIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIdle() }
        }
    }

    /// Ends the session once the deadline has passed - but never mid-dictation.
    func checkIdle(now: Date = Date()) {
        guard isActive, !isCapturingUtterance,
              let deadline = FlowSessionState.idleDeadline, now >= deadline else { return }
        DebugLogger.shared.log("FlowSession idle for \(Int(idleTimeout))s - ending", category: "flow")
        end()
        FlowSessionState.lastIdleTimeoutAt = now
        DarwinNotification.post(FlowSessionState.stateChanged)
    }

    // MARK: - Darwin notification handlers (keyboard -> app)

    private func handleStartSignal() {
        DebugLogger.shared.log("FlowSession received startUtterance, isActive=\(isActive) alreadyCapturing=\(isCapturingUtterance)", category: "flow")
        guard isActive, !isCapturingUtterance else { return }
        samples.removeAll(keepingCapacity: true)
        silenceStartDate = nil
        isCapturingUtterance = true
        isCommandUtterance = FlowSessionState.consumeRequestedCommandMode()
        FlowSessionState.utteranceIsCommand = isCommandUtterance
        utteranceStartDate = Date()
        isRecording = true
        FlowSessionState.isRecording = true
        FlowSessionState.utteranceStartedAt = utteranceStartDate
        DarwinNotification.post(FlowSessionState.stateChanged)
        updateLiveActivity(isRecording: true)
    }

    private func handleStopSignal() {
        DebugLogger.shared.log("FlowSession received stopUtterance, samples=\(samples.count)", category: "flow")
        guard isCapturingUtterance else { return }
        // Fire-and-forget from here: production has nothing that needs to
        // wait for this (the eventual stateChanged notification is how the
        // keyboard finds out) - but finishUtterance/transcribeAndPublish
        // themselves are plain `async` rather than spawning their own
        // internal Task, specifically so a test can `await` the same real
        // method directly instead of racing a detached Task with no way to
        // know when it's actually done. See the `#if DEBUG` test seams below.
        Task { await finishUtterance(publish: true) }
    }

    private func finishUtterance(publish: Bool) async {
        isCapturingUtterance = false
        isRecording = false
        let captured = samples
        let duration = utteranceStartDate.map { Date().timeIntervalSince($0) } ?? 0
        samples.removeAll(keepingCapacity: true)
        FlowSessionState.isRecording = false
        FlowSessionState.utteranceStartedAt = nil
        touchIdleDeadline()
        updateLiveActivity(isRecording: false)
        guard publish else {
            DarwinNotification.post(FlowSessionState.stateChanged)
            return
        }
        FlowSessionState.isTranscribing = true
        defer {
            FlowSessionState.isTranscribing = false
            DarwinNotification.post(FlowSessionState.stateChanged)
        }
        DarwinNotification.post(FlowSessionState.stateChanged)
        guard !captured.isEmpty else {
            // Was silently doing nothing here - the keyboard would sit on
            // "Transcribing..." for its full timeout with no way to tell this
            // apart from a slow-but-working transcription. Now it finds out
            // immediately via lastFailureAt instead.
            DebugLogger.shared.log("FlowSession stopUtterance with zero samples captured", category: "flow")
            signalFailure()
            return
        }
        if isCommandUtterance {
            isCommandUtterance = false
            FlowSessionState.utteranceIsCommand = false
            await interpretCommand(captured)
            return
        }
        // On disk *before* decoding: whatever the decode does next, the words
        // are safe and History can re-run them (UtteranceAudioStore).
        let audioFileName = settings.keepRecentAudio ? UtteranceAudioStore.save(samples: captured) : nil
        await transcribeAndPublish(captured, duration: duration, audioFileName: audioFileName)
    }

    /// Command-mode path: decode, match against `VoiceCommandParser`, and hand
    /// the keyboard a command to execute - never text to insert. An utterance
    /// that matches nothing is reported as such so the keyboard can say what it
    /// heard rather than silently doing nothing. Commands are short and never
    /// worth keeping: no History entry, no clipboard, no audio kept.
    private func interpretCommand(_ samples: [Float]) async {
        do {
            let chunkSeconds = TimeInterval(settings.maxRecordDurationSeconds)
            let result: WhisperService.TranscriptionResult
            if let forcedModel = settings.languageMode.pinnedModel {
                result = try await whisperService.transcribe(samples: samples, using: forcedModel, chunkDurationSeconds: chunkSeconds)
            } else {
                result = try await whisperService.transcribeWithAutoRouting(samples: samples, chunkDurationSeconds: chunkSeconds)
            }
            if let command = VoiceCommandParser.parse(result.text) {
                DictationHandoff.publishCommand(command.payload)
                DebugLogger.shared.log("FlowSession command: \(command.displayName)", category: "flow")
            } else {
                DictationHandoff.publishCommand(.unrecognized(result.text))
                DebugLogger.shared.log("FlowSession command not recognised: \(result.text)", category: "flow")
            }
            DarwinNotification.post(FlowSessionState.stateChanged)
        } catch {
            DebugLogger.shared.log("FlowSession command decode failed: \(error)", category: "flow")
            signalFailure()
        }
    }

    private func signalFailure() {
        FlowSessionState.lastFailureAt = Date()
        DarwinNotification.post(FlowSessionState.stateChanged)
    }

    private func transcribeAndPublish(_ samples: [Float], duration: TimeInterval, audioFileName: String?) async {
        // Style for the field the keyboard is in right now (DictationStyle):
        // resolved per utterance, so a pill tap or a change of field between two
        // dictations applies to the very next one.
        whisperService.activeStyle = FlowSessionState.resolvedStyleProfile()
        defer { whisperService.activeStyle = .standard }
        DebugLogger.shared.log(
            "FlowSession style: \(FlowSessionState.resolvedStyle.rawValue) (picked \(FlowSessionState.dictationStyle.rawValue), field \(FlowSessionState.hostFieldHint.rawValue))",
            category: "flow"
        )
        do {
            let result: WhisperService.TranscriptionResult
            let chunkSeconds = TimeInterval(settings.maxRecordDurationSeconds)
            if let forcedModel = settings.languageMode.pinnedModel {
                result = try await whisperService.transcribe(samples: samples, using: forcedModel, chunkDurationSeconds: chunkSeconds)
            } else {
                result = try await whisperService.transcribeWithAutoRouting(samples: samples, chunkDurationSeconds: chunkSeconds)
            }
            guard !result.text.isEmpty else {
                DebugLogger.shared.log("FlowSession utterance transcribed empty", category: "flow")
                saveFailedToHistory(duration: duration, audioFileName: audioFileName)
                signalFailure()
                return
            }
            DictationHandoff.publish(result.text)
            ClipboardFallback.place(result.text)
            saveToHistory(text: result.text, model: result.modelUsed, language: result.languageTag, duration: duration, audioFileName: audioFileName, confidence: result.confidence)
            DarwinNotification.post(FlowSessionState.stateChanged)
            DebugLogger.shared.log("FlowSession utterance transcribed: \(result.text.count) chars", category: "flow")
            recordLatency(capture: duration, source: "flow")
        } catch {
            DebugLogger.shared.log("FlowSession transcription failed: \(error)", category: "flow")
            saveFailedToHistory(duration: duration, audioFileName: audioFileName)
            signalFailure()
        }
    }

    /// Stage timings for this dictation plus the running p50/p95, in the debug log
    /// after every utterance - see `LatencyLog`. The keyboard adds the hand-off
    /// stage when it inserts.
    private func recordLatency(capture: TimeInterval, source: String) {
        guard let timings = whisperService.lastTimings else { return }
        let stage = StageTimings(recordedAt: Date(), source: source, capture: capture, decode: timings.decode, format: timings.format, handoff: nil)
        latencyLog.record(stage)
        DebugLogger.shared.log("\(stage.line) | \(latencyLog.summary() ?? "")", category: "latency")
    }

    private func saveToHistory(text: String, model: WhisperModelType, language: LanguageType, duration: TimeInterval, audioFileName: String?, confidence: Float) {
        let record = Transcription(text: text, duration: duration, languageUsed: language, modelUsed: model, audioFileName: audioFileName, confidence: confidence)
        modelContext.insert(record)
        try? modelContext.save()
    }

    /// A decode that produced nothing still gets a History entry when its audio
    /// was kept, so the user can re-run it instead of re-recording. Without
    /// audio there is nothing to retry, so nothing is saved.
    private func saveFailedToHistory(duration: TimeInterval, audioFileName: String?) {
        guard let audioFileName else { return }
        let record = Transcription(
            text: "",
            duration: duration,
            languageUsed: .unknown,
            modelUsed: settings.languageMode.pinnedModel ?? .singlish,
            audioFileName: audioFileName
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    // MARK: - Continuous engine (runs for the whole session, not per-utterance)

    private func startEngine() throws {
        let input = audioEngine.inputNode
        var converter: AVAudioConverter?
        let (stream, continuation) = AsyncStream<[Float]>.makeStream()
        sampleContinuation = continuation
        sampleStreamTask = Task { @MainActor [weak self] in
            for await chunk in stream {
                self?.ingest(chunk)
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
    }

    private func stopEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        sampleContinuation?.finish()
        sampleContinuation = nil
        sampleStreamTask?.cancel()
        sampleStreamTask = nil
    }

    /// Gated by `isCapturingUtterance` - the engine/tap runs continuously for
    /// the whole session (see the type doc comment for why), but only actual
    /// utterances get buffered, so an idle session doesn't grow this forever.
    private func ingest(_ chunk: [Float], now: Date = Date()) {
        guard isCapturingUtterance else { return }
        samples.append(contentsOf: chunk)
        evaluateSilence(rms: Self.rms(of: chunk), now: now)
    }

    // MARK: - Silence auto-stop

    /// The same energy rule as `AudioService.evaluateVAD` (same setting, same
    /// sensitivity, same cutoff scale) applied to a Flow utterance: after
    /// `Constants.flowSilenceTimeout` of continuous quiet, the utterance ends
    /// itself and transcribes - so "tap, talk, stop talking" is enough, and the
    /// text appears without a second tap. Off with "Auto-stop when silent".
    private func evaluateSilence(rms: Float, now: Date) {
        guard settings.autoStopOnSilence, let start = utteranceStartDate,
              now.timeIntervalSince(start) > Constants.flowSilenceGrace else { return }
        let silenceCutoff = settings.vadSensitivity * 0.015
        guard rms < silenceCutoff else {
            silenceStartDate = nil
            return
        }
        if silenceStartDate == nil { silenceStartDate = now }
        guard let since = silenceStartDate, now.timeIntervalSince(since) > Constants.flowSilenceTimeout else { return }
        DebugLogger.shared.log("FlowSession silence auto-stop after \(Int(now.timeIntervalSince(start)))s, samples=\(samples.count)", category: "flow")
        silenceStartDate = nil
        autoStopTask = Task { await finishUtterance(publish: true) }
    }

    nonisolated private static func rms(of chunk: [Float]) -> Float {
        guard !chunk.isEmpty else { return 0 }
        var value: Float = 0
        chunk.withUnsafeBufferPointer { vDSP_rmsqv($0.baseAddress!, 1, &value, vDSP_Length(chunk.count)) }
        return value
    }

    // MARK: - Format conversion (runs on the audio render thread - no `self`)
    //
    // Identical to AudioService.convert - duplicated rather than shared to
    // avoid coupling this to a file that's already been hardened through
    // three separate real-device bugs for a differently-shaped use.

    nonisolated private static func convert(
        _ buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter
    ) -> [Float]? {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else {
            return nil
        }

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
        return Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
    }
}

#if DEBUG
extension FlowSessionEngine {
    /// Test-only seams (FlowSessionEngineTests) - excluded from release
    /// builds entirely via `#if DEBUG`, never shipped. None of these touch a
    /// real AVAudioEngine/AVAudioSession, which can't run in CI (no
    /// microphone hardware, no way to grant permission non-interactively) -
    /// they exercise the Darwin-notification signal-handling state machine
    /// directly and deterministically instead, which is exactly the class
    /// of logic that produced two real bugs (see project memory) pure code
    /// review didn't catch, without the timing-dependent flakiness real
    /// notification posting or a bare sleep-and-hope would add.
    func test_markActive() {
        isActive = true
        FlowSessionState.isActive = true
    }

    func test_ingest(_ chunk: [Float], at now: Date = Date()) {
        ingest(chunk, now: now)
    }

    /// Waits for a decode the silence auto-stop started, if any.
    func test_awaitAutoStop() async {
        await autoStopTask?.value
        autoStopTask = nil
    }

    func test_handleStartSignal() {
        handleStartSignal()
    }

    /// Unlike production's fire-and-forget `handleStopSignal()`, this awaits
    /// the same real `finishUtterance` directly - production doesn't need to
    /// wait (the eventual stateChanged notification is how the keyboard
    /// finds out), but a test asserting on the outcome needs a deterministic
    /// way to know the async work actually finished first.
    func test_handleStopSignalAndWait() async {
        guard isCapturingUtterance else { return }
        await finishUtterance(publish: true)
    }

    /// Everything this engine has saved to History, oldest first.
    func test_historyRecords() -> [Transcription] {
        let descriptor = FetchDescriptor<Transcription>(sortBy: [SortDescriptor(\.date)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
#endif
