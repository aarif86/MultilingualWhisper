import XCTest
import SwiftData
@testable import MultilingualWhisper

/// Records the options each `transcribe` call was made with and always
/// answers with the same canned text, and (if configured) throws instead -
/// lets these tests pin down how FlowSessionEngine reacts to a real decode
/// failure (see the CPU-only-decode fix in project history: this is the
/// exact class of failure that produced the bug this file's tests guard
/// against), with no model file, no audio hardware, and no physical device.
/// Deliberately a private, file-scoped double rather than sharing one with
/// WhisperServiceRoutingTests - keeps this file fully self-contained so it
/// has no dependency on whichever other test/feature work happens to be on
/// a given branch at a given time.
private actor MockWhisperEngine: WhisperTranscribing {
    private let text: String
    private let errorToThrow: Error?
    private(set) var callCount = 0

    init(text: String, throwing errorToThrow: Error? = nil) {
        self.text = text
        self.errorToThrow = errorToThrow
    }

    func transcribe(samples: [Float], options: WhisperEngine.TranscriptionOptions) async throws -> [WhisperEngine.Segment] {
        callCount += 1
        if let errorToThrow { throw errorToThrow }
        // endTime 0.5, not 1.0: WhisperService.minSegmentDurationToProbe is 1.0 (>=), and this
        // file's callCount assertions are about FlowSessionEngine's OWN signal-handling (did it
        // transcribe once per accumulated utterance, not zero, not twice for a stray duplicate
        // signal) - not about WhisperService's separate per-segment reprocessing feature. A
        // 1.0s-or-longer segment here would make transcribeWithAutoRouting probe it a second
        // time, inflating callCount to 2 for reasons unrelated to what these tests actually
        // check, exactly as happened when this was first merged alongside that feature.
        return [WhisperEngine.Segment(text: text, startTime: 0, endTime: 0.5)]
    }

    func detectedLanguageCode() async -> String? { nil }

    func arabicLanguageProbability(samples: [Float]) async throws -> Float { 0 }
}

private struct StubModelStore: ModelStoring {
    func isDownloaded(_ model: WhisperModelType) -> Bool { true }
    func localURL(for model: WhisperModelType) -> URL? { URL(fileURLWithPath: "/dev/null/\(model.rawValue)") }
}

/// Exercises FlowSessionEngine's Darwin-notification signal-handling state
/// machine directly, via the `#if DEBUG` test seams on FlowSessionEngine -
/// no real AVAudioEngine/AVAudioSession involved (that part can't run in
/// CI: no microphone hardware, no way to grant permission
/// non-interactively). This is exactly the class of logic that produced two
/// real bugs found only via a real device (see project memory: the silent
/// "Transcribing..." hang, and the GPU-decode-fails-in-background issue) -
/// worth covering the same way WhisperServiceRoutingTests already covers
/// WhisperService's routing logic.
@MainActor
final class FlowSessionEngineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Never trust state a previous test (or a previous real session on
        // this machine) might have left behind - same reasoning as
        // FlowSessionEngine's own init().
        FlowSessionState.clear()
        DictationHandoff.clearPending()
        // Style is a preference that survives clear() - reset it explicitly so a
        // test that picks one can't leak into the next.
        FlowSessionState.dictationStyle = .auto
        FlowSessionState.hostFieldHint = .general
    }

    private func makeEngine(
        returning mock: MockWhisperEngine,
        keepRecentAudio: Bool = true,
        autoStopOnSilence: Bool = true,
        idleTimeout: TimeInterval = Constants.flowSessionIdleTimeout,
        latencyLog: LatencyLog = LatencyLog(defaults: UserDefaults(suiteName: "FlowSessionEngineTests-latency-\(UUID())")!)
    ) -> FlowSessionEngine {
        let whisperService = WhisperService(modelStore: StubModelStore(), customDictionary: CustomDictionaryService(), cleanupLevel: { .raw }, makeEngine: { _ in mock })
        let schema = Schema([Transcription.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        // A dedicated UserDefaults suite per engine, not AppSettings.shared -
        // .shared is backed by UserDefaults.standard, which these tests
        // don't own and shouldn't depend on being clean. This is what makes
        // `settings.languageMode` reliably `.auto` (so transcribeAndPublish
        // takes the transcribeWithAutoRouting path every mock here assumes)
        // regardless of anything else running in this process.
        let isolatedSettings = AppSettings(defaults: UserDefaults(suiteName: "FlowSessionEngineTests-\(UUID())")!)
        isolatedSettings.keepRecentAudio = keepRecentAudio
        isolatedSettings.autoStopOnSilence = autoStopOnSilence
        return FlowSessionEngine(whisperService: whisperService, modelContainer: container, settings: isolatedSettings, idleTimeout: idleTimeout, latencyLog: latencyLog)
    }

    // MARK: - Silence auto-stop

    private func loud(_ count: Int = 1_600) -> [Float] { Array(repeating: 0.1, count: count) }
    private func quiet(_ count: Int = 1_600) -> [Float] { Array(repeating: 0, count: count) }

    func testSilenceEndsTheUtteranceAndTranscribesIt() async {
        let mock = MockWhisperEngine(text: "hands free")
        let engine = makeEngine(returning: mock)
        engine.test_markActive()
        let t0 = Date()
        engine.test_handleStartSignal()

        engine.test_ingest(loud(), at: t0.addingTimeInterval(0.5))
        engine.test_ingest(quiet(), at: t0.addingTimeInterval(2.0))   // silence starts (past the grace period)
        engine.test_ingest(quiet(), at: t0.addingTimeInterval(3.0))   // 1.0 s quiet - not yet
        XCTAssertTrue(engine.isRecording)
        engine.test_ingest(quiet(), at: t0.addingTimeInterval(4.6))   // 2.6 s quiet - stop

        await engine.test_awaitAutoStop()

        XCTAssertFalse(engine.isRecording)
        XCTAssertEqual(DictationHandoff.pending()?.text, "hands free")
        XCTAssertFalse(FlowSessionState.isTranscribing)
        let callCount = await mock.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testSpeechResetsTheSilenceClock() async {
        let engine = makeEngine(returning: MockWhisperEngine(text: "still going"))
        engine.test_markActive()
        let t0 = Date()
        engine.test_handleStartSignal()

        engine.test_ingest(quiet(), at: t0.addingTimeInterval(1.5))
        engine.test_ingest(quiet(), at: t0.addingTimeInterval(3.5))   // 2.0 s quiet
        engine.test_ingest(loud(), at: t0.addingTimeInterval(3.6))    // speech again
        engine.test_ingest(quiet(), at: t0.addingTimeInterval(5.0))   // clock restarted at 5.0
        engine.test_ingest(quiet(), at: t0.addingTimeInterval(7.0))   // 2.0 s quiet - not yet

        await engine.test_awaitAutoStop()

        XCTAssertTrue(engine.isRecording, "a pause under the timeout never ends the utterance")
        XCTAssertNil(DictationHandoff.pending())
    }

    func testSilenceInsideTheGracePeriodIsIgnored() async {
        let engine = makeEngine(returning: MockWhisperEngine(text: "x"))
        engine.test_markActive()
        let t0 = Date()
        engine.test_handleStartSignal()

        engine.test_ingest(quiet(), at: t0.addingTimeInterval(0.2))
        engine.test_ingest(quiet(), at: t0.addingTimeInterval(1.0))
        engine.test_ingest(quiet(), at: t0.addingTimeInterval(1.1))

        await engine.test_awaitAutoStop()

        XCTAssertTrue(engine.isRecording)
    }

    func testAutoStopIsOffWhenTheSettingIsOff() async {
        let engine = makeEngine(returning: MockWhisperEngine(text: "x"), autoStopOnSilence: false)
        engine.test_markActive()
        let t0 = Date()
        engine.test_handleStartSignal()

        engine.test_ingest(loud(), at: t0.addingTimeInterval(0.5))
        engine.test_ingest(quiet(), at: t0.addingTimeInterval(2.0))
        engine.test_ingest(quiet(), at: t0.addingTimeInterval(10.0))

        await engine.test_awaitAutoStop()

        XCTAssertTrue(engine.isRecording)
    }

    func testKeyboardCanSeeTranscribingForAnUtteranceItDidNotStop() async {
        let engine = makeEngine(returning: MockWhisperEngine(text: "hello"))
        engine.test_markActive()
        engine.test_handleStartSignal()
        engine.test_ingest(loud())
        XCTAssertFalse(FlowSessionState.isTranscribing)

        await engine.test_handleStopSignalAndWait()

        XCTAssertFalse(FlowSessionState.isTranscribing, "cleared once the text is published")
        XCTAssertEqual(DictationHandoff.pending()?.text, "hello")
    }

    // MARK: - Latency

    func testSuccessfulUtteranceRecordsItsStageTimings() async {
        let log = LatencyLog(defaults: UserDefaults(suiteName: "FlowSessionEngineTests-latency-\(UUID())")!)
        let engine = makeEngine(returning: MockWhisperEngine(text: "hello"), latencyLog: log)
        engine.test_markActive()
        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))

        await engine.test_handleStopSignalAndWait()

        let entries = log.entries()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.source, "flow")
        XCTAssertGreaterThanOrEqual(entries.first?.capture ?? -1, 0)
        XCTAssertGreaterThanOrEqual(entries.first?.decode ?? -1, 0)
        XCTAssertGreaterThanOrEqual(entries.first?.format ?? -1, 0)
        XCTAssertNil(entries.first?.handoff, "the keyboard reports the hand-off, not the app")

        log.recordHandoff(0.3)
        XCTAssertEqual(log.entries().first?.handoff, 0.3)
    }

    func testFailedUtteranceRecordsNoTimings() async {
        let log = LatencyLog(defaults: UserDefaults(suiteName: "FlowSessionEngineTests-latency-\(UUID())")!)
        let engine = makeEngine(returning: MockWhisperEngine(text: ""), latencyLog: log)
        engine.test_markActive()
        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))

        await engine.test_handleStopSignalAndWait()

        XCTAssertTrue(log.entries().isEmpty)
    }

    // MARK: - Start signal

    func testStartSignalIgnoredWhenSessionNotActive() {
        let engine = makeEngine(returning: MockWhisperEngine(text: "hello"))
        // Deliberately not calling test_markActive() - no session was ever activated.

        engine.test_handleStartSignal()

        XCTAssertFalse(engine.isRecording, "a stray signal after a session ended shouldn't start capturing")
    }

    func testStartSignalBeginsCapturingWhenActive() {
        let engine = makeEngine(returning: MockWhisperEngine(text: "hello"))
        engine.test_markActive()

        engine.test_handleStartSignal()

        XCTAssertTrue(engine.isRecording)
    }

    func testSecondStartSignalWhileAlreadyCapturingDoesNotResetTheBuffer() async {
        // Guards against a double-tap (or a stray repeated Darwin
        // notification) restarting the utterance mid-recording and losing
        // whatever was already captured.
        let mock = MockWhisperEngine(text: "captured")
        let engine = makeEngine(returning: mock)
        engine.test_markActive()

        engine.test_handleStartSignal()
        engine.test_ingest([0.1, 0.2, 0.3])
        engine.test_handleStartSignal() // stray second signal - should be a no-op
        engine.test_ingest([0.4])
        await engine.test_handleStopSignalAndWait()

        let callCount = await mock.callCount
        XCTAssertEqual(callCount, 1, "should still transcribe the one accumulated utterance, not restart or duplicate it")
    }

    // MARK: - Stop signal

    func testStopSignalIgnoredWhenNotCapturing() async {
        let mock = MockWhisperEngine(text: "hello")
        let engine = makeEngine(returning: mock)
        engine.test_markActive()
        // Never started an utterance.

        await engine.test_handleStopSignalAndWait()

        let callCount = await mock.callCount
        XCTAssertEqual(callCount, 0, "nothing was ever captured, so nothing should be transcribed")
    }

    func testStopSignalTranscribesAndPublishesTheCapturedAudio() async {
        let mock = MockWhisperEngine(text: "hello world")
        let engine = makeEngine(returning: mock)
        engine.test_markActive()
        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))

        await engine.test_handleStopSignalAndWait()

        let callCount = await mock.callCount
        XCTAssertEqual(callCount, 1)
        XCTAssertFalse(engine.isRecording, "should be back to idle after finishing")
        XCTAssertEqual(DictationHandoff.pending()?.text, "hello world")
    }

    func testStopSignalWithNoAudioCapturedSignalsFailureWithoutTranscribing() async {
        let mock = MockWhisperEngine(text: "should never be used")
        let engine = makeEngine(returning: mock)
        engine.test_markActive()
        engine.test_handleStartSignal()
        // No ingest() call at all - zero samples captured (e.g. tapped stop
        // instantly after start).

        await engine.test_handleStopSignalAndWait()

        let callCount = await mock.callCount
        XCTAssertEqual(callCount, 0, "shouldn't even attempt to transcribe zero captured samples")
        XCTAssertNotNil(FlowSessionState.lastFailureAt, "should signal failure immediately rather than letting the keyboard time out")
    }

    func testStopSignalWhenTranscriptionThrowsSignalsFailure() async {
        // The actual real-world bug this whole feature hit: whisper.cpp's
        // decode threw (GPU work rejected while backgrounded) and nothing
        // told the keyboard, which sat on "Transcribing..." for a full
        // timeout. Pin down that a thrown error is ALWAYS signaled
        // immediately, regardless of what specifically caused it.
        struct DecodeError: Error {}
        let mock = MockWhisperEngine(text: "unused", throwing: DecodeError())
        let engine = makeEngine(returning: mock)
        engine.test_markActive()
        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))

        await engine.test_handleStopSignalAndWait()

        XCTAssertNotNil(FlowSessionState.lastFailureAt)
        XCTAssertNil(DictationHandoff.pending(), "a failed decode shouldn't publish anything")
    }

    // MARK: - Ending a session

    func testEndWhileCapturingStopsImmediately() {
        let engine = makeEngine(returning: MockWhisperEngine(text: "unused"))
        engine.test_markActive()
        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))

        engine.end()

        XCTAssertFalse(engine.isActive)
        XCTAssertFalse(engine.isRecording, "end() should stop capturing immediately and synchronously, not wait on anything")
    }

    // MARK: - Never lose a dictation

    func testSuccessfulUtteranceKeepsItsAudioOnTheHistoryEntry() async throws {
        UtteranceAudioStore.clear()
        defer { UtteranceAudioStore.clear() }
        let engine = makeEngine(returning: MockWhisperEngine(text: "kept"))
        engine.test_markActive()
        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))

        await engine.test_handleStopSignalAndWait()

        let records = engine.test_historyRecords()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.text, "kept")
        let audio = try XCTUnwrap(records.first?.audioFileName)
        XCTAssertTrue(UtteranceAudioStore.exists(audio), "audio should be on disk before/after the decode")
        XCTAssertEqual(UtteranceAudioStore.load(named: audio)?.count, 16_000)
    }

    func testFailedDecodeStillSavesARetryableHistoryEntry() async throws {
        UtteranceAudioStore.clear()
        defer { UtteranceAudioStore.clear() }
        struct DecodeError: Error {}
        let engine = makeEngine(returning: MockWhisperEngine(text: "unused", throwing: DecodeError()))
        engine.test_markActive()
        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))

        await engine.test_handleStopSignalAndWait()

        let records = engine.test_historyRecords()
        XCTAssertEqual(records.count, 1, "the failure must leave something to retry")
        XCTAssertTrue(records.first?.isFailedWithAudio ?? false)
        XCTAssertTrue(records.first?.canRetry ?? false)
        XCTAssertNotNil(FlowSessionState.lastFailureAt)
    }

    func testAudioIsNotKeptWhenTheSettingIsOff() async {
        UtteranceAudioStore.clear()
        defer { UtteranceAudioStore.clear() }
        let engine = makeEngine(returning: MockWhisperEngine(text: "no audio"), keepRecentAudio: false)
        engine.test_markActive()
        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))

        await engine.test_handleStopSignalAndWait()

        XCTAssertEqual(engine.test_historyRecords().first?.text, "no audio")
        XCTAssertNil(engine.test_historyRecords().first?.audioFileName)
        XCTAssertTrue(UtteranceAudioStore.allFiles().isEmpty)
    }

    // MARK: - Idle timeout

    func testUtteranceExtendsTheIdleDeadline() async {
        let engine = makeEngine(returning: MockWhisperEngine(text: "hi"), idleTimeout: 600)
        engine.test_markActive()
        FlowSessionState.idleDeadline = Date(timeIntervalSinceNow: 5)

        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))
        await engine.test_handleStopSignalAndWait()

        let deadline = FlowSessionState.idleDeadline ?? .distantPast
        XCTAssertGreaterThan(deadline.timeIntervalSinceNow, 500, "a dictation should push the deadline out by the full timeout")
    }

    func testCheckIdleEndsTheSessionPastTheDeadline() {
        let engine = makeEngine(returning: MockWhisperEngine(text: "unused"), idleTimeout: 600)
        engine.test_markActive()
        FlowSessionState.idleDeadline = Date(timeIntervalSinceNow: -1)

        engine.checkIdle(now: Date())

        XCTAssertFalse(engine.isActive)
        XCTAssertFalse(FlowSessionState.isActive)
        XCTAssertNotNil(FlowSessionState.lastIdleTimeoutAt)
        XCTAssertNil(FlowSessionState.idleDeadline)
    }

    func testCheckIdleLeavesAnActiveDictationAlone() {
        let engine = makeEngine(returning: MockWhisperEngine(text: "unused"), idleTimeout: 600)
        engine.test_markActive()
        engine.test_handleStartSignal()
        FlowSessionState.idleDeadline = Date(timeIntervalSinceNow: -1)

        engine.checkIdle(now: Date())

        XCTAssertTrue(engine.isActive, "never cut off someone mid-sentence")
        XCTAssertTrue(engine.isRecording)
    }

    func testCheckIdleBeforeTheDeadlineDoesNothing() {
        let engine = makeEngine(returning: MockWhisperEngine(text: "unused"), idleTimeout: 600)
        engine.test_markActive()
        FlowSessionState.idleDeadline = Date(timeIntervalSinceNow: 300)

        engine.checkIdle(now: Date())

        XCTAssertTrue(engine.isActive)
    }

    // MARK: - Command mode

    func testCommandModeUtterancePublishesACommandNotText() async {
        DictationHandoff.clearPendingCommand()
        let engine = makeEngine(returning: MockWhisperEngine(text: "New line."))
        engine.test_markActive()
        FlowSessionState.requestedCommandMode = true

        engine.test_handleStartSignal()
        XCTAssertTrue(FlowSessionState.utteranceIsCommand)
        XCTAssertFalse(FlowSessionState.requestedCommandMode, "the request is consumed, never re-used")
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))
        await engine.test_handleStopSignalAndWait()

        XCTAssertEqual(DictationHandoff.pendingCommand().flatMap(VoiceCommand.init(payload:)), .newLine)
        XCTAssertNil(DictationHandoff.pending(), "a command is never inserted as text")
        XCTAssertTrue(engine.test_historyRecords().isEmpty, "commands are not worth keeping")
        XCTAssertFalse(FlowSessionState.utteranceIsCommand)
        DictationHandoff.clearPendingCommand()
    }

    func testUnrecognisedCommandIsReportedNotDropped() async {
        DictationHandoff.clearPendingCommand()
        let engine = makeEngine(returning: MockWhisperEngine(text: "we go makan"))
        engine.test_markActive()
        FlowSessionState.requestedCommandMode = true
        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))

        await engine.test_handleStopSignalAndWait()

        let payload = DictationHandoff.pendingCommand()
        XCTAssertTrue(payload?.isUnrecognized ?? false)
        XCTAssertEqual(payload?.argument, "we go makan")
        XCTAssertNil(DictationHandoff.pending())
        DictationHandoff.clearPendingCommand()
    }

    // MARK: - Styles

    func testChatStyleIsAppliedToTheNextUtteranceOnly() async {
        let engine = makeEngine(returning: MockWhisperEngine(text: "see you there."))
        engine.test_markActive()
        FlowSessionState.dictationStyle = .auto
        FlowSessionState.hostFieldHint = .messaging

        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))
        await engine.test_handleStopSignalAndWait()

        XCTAssertEqual(DictationHandoff.pending()?.text, "see you there", "Auto in a Send-key field is Chat: the lone trailing full stop goes")
        DictationHandoff.clearPending()

        // Field changed underneath the session - the next utterance follows it.
        FlowSessionState.hostFieldHint = .general
        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))
        await engine.test_handleStopSignalAndWait()

        XCTAssertEqual(DictationHandoff.pending()?.text, "see you there.")
    }

    func testExplicitEmailStyleWinsOverTheField() async {
        let engine = makeEngine(returning: MockWhisperEngine(text: "see you at three pm"))
        engine.test_markActive()
        FlowSessionState.dictationStyle = .email
        FlowSessionState.hostFieldHint = .messaging

        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))
        await engine.test_handleStopSignalAndWait()

        XCTAssertEqual(DictationHandoff.pending()?.text, "See you at 3pm.")
    }

    func testCommandsAreNeverStyled() async {
        DictationHandoff.clearPendingCommand()
        let engine = makeEngine(returning: MockWhisperEngine(text: "Full stop."))
        engine.test_markActive()
        FlowSessionState.dictationStyle = .exact
        FlowSessionState.requestedCommandMode = true

        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))
        await engine.test_handleStopSignalAndWait()

        XCTAssertEqual(DictationHandoff.pendingCommand().flatMap(VoiceCommand.init(payload:)), .period)
        DictationHandoff.clearPendingCommand()
    }

    func testOrdinaryDictationIsNeverTreatedAsACommand() async {
        DictationHandoff.clearPendingCommand()
        let engine = makeEngine(returning: MockWhisperEngine(text: "new line"))
        engine.test_markActive()
        // No command mode requested: "new line" is just words.
        engine.test_handleStartSignal()
        engine.test_ingest(Array(repeating: Float(0.1), count: 16_000))

        await engine.test_handleStopSignalAndWait()

        XCTAssertNil(DictationHandoff.pendingCommand())
        XCTAssertEqual(DictationHandoff.pending()?.text, "new line")
    }
}
