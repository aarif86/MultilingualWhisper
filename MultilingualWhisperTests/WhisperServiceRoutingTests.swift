import XCTest
@testable import MultilingualWhisper

/// Records the options each `transcribe` call was made with and always answers
/// with the same canned segment(s) plus a fixed "detected language" - lets
/// these tests pin down which language hint `WhisperService` sends to the
/// decoder for each pass (and, for the per-segment reprocessing tests, which
/// language it's told an audio slice detects as), with no model file, no
/// audio hardware, and no physical device involved.
private actor MockWhisperEngine: WhisperTranscribing {
    private let segments: [WhisperEngine.Segment]
    private let detectedLanguage: String?
    private let arabicProbability: Float
    private(set) var receivedOptions: [WhisperEngine.TranscriptionOptions] = []
    private(set) var callCount = 0
    private(set) var arabicLanguageProbabilityCallCount = 0

    init(text: String, detectedLanguage: String? = nil, arabicProbability: Float = 0) {
        self.segments = [WhisperEngine.Segment(text: text, startTime: 0, endTime: 1)]
        self.detectedLanguage = detectedLanguage
        self.arabicProbability = arabicProbability
    }

    init(segments: [WhisperEngine.Segment], detectedLanguage: String? = nil, arabicProbability: Float = 0) {
        self.segments = segments
        self.detectedLanguage = detectedLanguage
        self.arabicProbability = arabicProbability
    }

    func transcribe(samples: [Float], options: WhisperEngine.TranscriptionOptions) async throws -> [WhisperEngine.Segment] {
        callCount += 1
        receivedOptions.append(options)
        return segments
    }

    func detectedLanguageCode() async -> String? { detectedLanguage }

    func arabicLanguageProbability(samples: [Float]) async throws -> Float {
        arabicLanguageProbabilityCallCount += 1
        return arabicProbability
    }
}

private struct StubModelStore: ModelStoring {
    func isDownloaded(_ model: WhisperModelType) -> Bool { true }
    func localURL(for model: WhisperModelType) -> URL? { URL(fileURLWithPath: "/dev/null/\(model.rawValue)") }
}

@MainActor
final class WhisperServiceRoutingTests: XCTestCase {
    private func makeService(returning mock: MockWhisperEngine) -> WhisperService {
        WhisperService(modelStore: StubModelStore(), customDictionary: CustomDictionaryService(), cleanupLevel: { .raw }, makeEngine: { _ in mock })
    }

    // MARK: - Timings

    func testEveryPublicDecodeRecordsItsTimings() async throws {
        let service = makeService(returning: MockWhisperEngine(text: "hello"))
        XCTAssertNil(service.lastTimings)

        _ = try await service.transcribe(samples: [0.1, 0.2], using: .singlish)
        let forced = try XCTUnwrap(service.lastTimings)
        XCTAssertGreaterThanOrEqual(forced.total, forced.format)
        XCTAssertEqual(forced.decode, forced.total - forced.format, accuracy: 0.000_001)

        _ = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2])
        let routed = try XCTUnwrap(service.lastTimings)
        XCTAssertGreaterThanOrEqual(routed.total, 0)
        XCTAssertGreaterThanOrEqual(routed.format, 0)
    }

    func testTimingsAreRecordedEvenWhenTheDecodeThrows() async {
        let service = makeService(returning: MockWhisperEngine(text: "hello"))
        _ = try? await service.transcribe(samples: [], using: .singlish)
        XCTAssertNotNil(service.lastTimings, "a thrown decode still leaves a timing, so a failure's cost is visible too")
    }

    // MARK: - Silero VAD and vocabulary hints

    private func makeService(
        returning mock: MockWhisperEngine,
        skipSilence: Bool,
        vocabularyHints: Bool,
        vadModelPath: String? = "/models/ggml-silero-v5.1.2.bin",
        dictionary: CustomDictionaryService? = nil
    ) -> WhisperService {
        WhisperService(
            modelStore: StubModelStore(),
            customDictionary: dictionary ?? CustomDictionaryService(defaults: UserDefaults(suiteName: "WhisperServiceRoutingTests-\(UUID())")!),
            cleanupLevel: { .raw },
            skipSilence: { skipSilence },
            vocabularyHints: { vocabularyHints },
            vadModelPath: vadModelPath,
            makeEngine: { _ in mock }
        )
    }

    func testSkipSilenceSendsTheVADModelToEveryDecodeExceptProbes() async throws {
        let mock = MockWhisperEngine(text: "hello", detectedLanguage: "ms")
        let service = makeService(returning: mock, skipSilence: true, vocabularyHints: false)

        _ = try await service.transcribe(samples: [0.1, 0.2], using: .singlish)
        var received = await mock.receivedOptions
        XCTAssertEqual(received.last?.vadModelPath, "/models/ggml-silero-v5.1.2.bin")
        XCTAssertEqual(received.last?.vadThreshold, 0.5)

        // A one-second-plus segment triggers the per-segment language probe on a
        // slice that is already speech: no VAD there, so an all-filtered probe can
        // never leave a stale language ID behind.
        let probing = MockWhisperEngine(segments: [WhisperEngine.Segment(text: "jalan jalan", startTime: 0, endTime: 1.5)], detectedLanguage: "ms")
        let probingService = makeService(returning: probing, skipSilence: true, vocabularyHints: false)
        _ = try await probingService.transcribeWithAutoRouting(samples: Array(repeating: 0.1, count: 32_000))
        received = await probing.receivedOptions
        XCTAssertEqual(received.first?.vadModelPath, "/models/ggml-silero-v5.1.2.bin", "the draft pass skips silence")
        XCTAssertTrue(received.dropFirst().allSatisfy { $0.vadModelPath == nil }, "probe and re-decode of a speech slice never use the VAD")
    }

    func testSkipSilenceOffOrNoModelMeansNoVAD() async throws {
        let mock = MockWhisperEngine(text: "hello")
        _ = try await makeService(returning: mock, skipSilence: false, vocabularyHints: false).transcribe(samples: [0.1], using: .singlish)
        _ = try await makeService(returning: mock, skipSilence: true, vocabularyHints: false, vadModelPath: nil).transcribe(samples: [0.1], using: .singlish)
        let received = await mock.receivedOptions
        XCTAssertEqual(received.count, 2)
        XCTAssertTrue(received.allSatisfy { $0.vadModelPath == nil })
    }

    func testVocabularyHintsPromptTheDictionaryWithCarry() async throws {
        let dictionary = CustomDictionaryService(defaults: UserDefaults(suiteName: "WhisperServiceRoutingTests-\(UUID())")!)
        dictionary.add(original: "tam pines", replacement: "Tampines")
        dictionary.add(original: "nassar", replacement: "Nasar")
        let mock = MockWhisperEngine(text: "hello")
        let service = makeService(returning: mock, skipSilence: false, vocabularyHints: true, dictionary: dictionary)

        _ = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2])

        let received = await mock.receivedOptions
        XCTAssertEqual(received.first?.initialPrompt, "Nasar, Tampines.")
        XCTAssertEqual(received.first?.carryInitialPrompt, true)
    }

    func testVocabularyHintsOffLeavesThePromptToTheModel() async throws {
        let mock = MockWhisperEngine(text: "hello")
        let service = makeService(returning: mock, skipSilence: false, vocabularyHints: false)
        _ = try await service.transcribe(samples: [0.1], using: .singlish)
        let received = await mock.receivedOptions
        XCTAssertEqual(received.first?.initialPrompt, WhisperModelType.singlish.initialPrompt)
    }

    // MARK: - Hallucination filter and confidence

    func testHallucinatedSegmentsAreDroppedFromEveryPath() async throws {
        let segments = [
            WhisperEngine.Segment(text: "Thank you for watching.", startTime: 0, endTime: 0.4, noSpeechProbability: 0.9, confidence: 0.3),
            WhisperEngine.Segment(text: "we go makan", startTime: 0.4, endTime: 0.8, noSpeechProbability: 0.05, confidence: 0.9),
            WhisperEngine.Segment(text: "you", startTime: 0.8, endTime: 0.9, noSpeechProbability: 0.7, confidence: 0.2),
        ]
        let service = makeService(returning: MockWhisperEngine(segments: segments))

        let routed = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2])
        XCTAssertEqual(routed.text, "we go makan")
        XCTAssertEqual(routed.confidence, 0.9, accuracy: 0.001)

        let forced = try await service.transcribe(samples: [0.1, 0.2], using: .singlish)
        XCTAssertEqual(forced.text, "we go makan")
        XCTAssertEqual(forced.confidence, 0.9, accuracy: 0.001)
    }

    func testConfidentThankYouIsKept() async throws {
        let segments = [
            WhisperEngine.Segment(text: "Thank you.", startTime: 0, endTime: 0.4, noSpeechProbability: 0.1, confidence: 0.95),
        ]
        let service = makeService(returning: MockWhisperEngine(segments: segments))
        let result = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2])
        XCTAssertEqual(result.text, "Thank you.")
    }

    func testConfidenceIsWeightedByTextLength() {
        let confidence = WhisperService.weightedConfidence([("a long confident sentence", 1.0), ("hm", 0.0)])
        XCTAssertEqual(confidence, 25.0 / 27.0, accuracy: 0.001)
        XCTAssertEqual(WhisperService.weightedConfidence([]), 1)
        XCTAssertEqual(WhisperService.weightedConfidence([("", 0.2)]), 1)
    }

    func testLowConfidenceResultIsFlaggedOnTheHistoryEntry() async throws {
        let segments = [
            WhisperEngine.Segment(text: "something mumbled", startTime: 0, endTime: 0.4, noSpeechProbability: 0.2, confidence: 0.3),
        ]
        let service = makeService(returning: MockWhisperEngine(segments: segments))
        let result = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2])
        XCTAssertEqual(result.confidence, 0.3, accuracy: 0.001)

        let record = Transcription(text: result.text, duration: 1, languageUsed: .singlish, modelUsed: .singlish, confidence: result.confidence)
        XCTAssertTrue(record.isLowConfidence)
        XCTAssertFalse(Transcription(text: "x", duration: 1, languageUsed: .singlish, modelUsed: .singlish).isLowConfidence, "entries saved before confidence existed are never flagged")
    }

    // MARK: - Dictionary and formatter reach every path

    /// Auto-Detect (the default) used to skip the dictionary and formatter
    /// whenever no whole-clip reroute happened - the most common outcome.
    func testAutoRoutingWithoutRerouteStillFormatsAndCorrects() async throws {
        let dictionary = CustomDictionaryService(defaults: UserDefaults(suiteName: "WhisperServiceRoutingTests-\(UUID())")!)
        dictionary.add(original: "m r t", replacement: "MRT")
        let service = WhisperService(
            modelStore: StubModelStore(),
            customDictionary: dictionary,
            cleanupLevel: { .light },
            makeEngine: { _ in MockWhisperEngine(text: "um we take the m r t") }
        )

        let result = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2])

        XCTAssertEqual(result.text, "We take the MRT")
    }

    func testForcedModelFormatsOnceOverTheWholeText() async throws {
        let service = WhisperService(
            modelStore: StubModelStore(),
            customDictionary: CustomDictionaryService(defaults: UserDefaults(suiteName: "WhisperServiceRoutingTests-\(UUID())")!),
            cleanupLevel: { .light },
            makeEngine: { _ in MockWhisperEngine(text: "um hello there") }
        )

        let result = try await service.transcribe(samples: [0.1, 0.2], using: .singlish)

        XCTAssertEqual(result.text, "Hello there")
    }

    func testActiveStyleAppliesToAutoRouting() async throws {
        let service = makeService(returning: MockWhisperEngine(text: "see you there."))
        service.activeStyle = DictationStyle.messaging.profile(hint: .general)

        let result = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2])

        XCTAssertEqual(result.text, "see you there")
    }

    /// For tests that need DIFFERENT engines per model (e.g. the default
    /// model's probe detects Malay, so a separate Malay mock should be the
    /// one that actually re-decodes) - `StubModelStore.localURL` bakes the
    /// model's own `rawValue` into the fake path, which is what lets this
    /// pick the right mock without `WhisperService` needing to expose model
    /// identity to its `makeEngine` factory at all.
    private func makeService(engines: [WhisperModelType: MockWhisperEngine]) -> WhisperService {
        WhisperService(modelStore: StubModelStore(), customDictionary: CustomDictionaryService(), cleanupLevel: { .raw }, makeEngine: { path in
            guard let match = engines.first(where: { path.contains($0.key.rawValue) })?.value else {
                XCTFail("no mock engine registered for path \(path)")
                return MockWhisperEngine(text: "")
            }
            return match
        })
    }

    func testForcedTranscribeUsesTheModelsOwnLanguageHint() async throws {
        let mock = MockWhisperEngine(text: "hello")
        let service = makeService(returning: mock)

        _ = try await service.transcribe(samples: [0.1, 0.2], using: .singlish)

        let received = await mock.receivedOptions
        XCTAssertEqual(received.first?.languageHint, "en")
        // Asserts against the model's own property rather than a hardcoded value,
        // so this stays correct whether initialPrompt priming is on or (as of
        // 2026-09-06, pending a real-device investigation) temporarily disabled -
        // what matters here is that WhisperService threads through whatever the
        // model says, not which specific prompt value that currently is.
        XCTAssertEqual(received.first?.initialPrompt, WhisperModelType.singlish.initialPrompt)
    }

    func testAutoRoutingDraftPassUsesTheSameHintAsAForcedTranscribe() async throws {
        // This is the exact bug that shipped to TestFlight: the draft pass used
        // `nil` (let whisper.cpp auto-detect the language from scratch) while the
        // live preview forced the model's own hint for the same model. On
        // code-switched or short audio, auto-detect can land on a different
        // language than the forced hint and decode the same audio completely
        // differently - which is why the live preview showed real text but the
        // final result on stop sometimes came back empty or garbled. Pin the
        // invariant down so it can't silently regress again.
        let mock = MockWhisperEngine(text: "wallah jalan jalan cari makan lah")
        let service = makeService(returning: mock)

        _ = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2])

        let received = await mock.receivedOptions
        XCTAssertEqual(received.first?.languageHint, WhisperModelType.singlish.languageHint)
        XCTAssertNotNil(received.first?.languageHint, "auto-detect (nil) is exactly the regression this guards against")
    }

    func testAutoRoutingReroutesToArabicHintWhenClassifierIsConfident() async throws {
        let mock = MockWhisperEngine(text: "بسم الله الرحمن الرحيم الحمد لله رب العالمين")
        let service = makeService(returning: mock)

        let result = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2])

        let received = await mock.receivedOptions
        XCTAssertEqual(received.count, 2, "should re-transcribe once the draft pass reads as confidently Arabic")
        XCTAssertEqual(received.last?.languageHint, "ar")
        XCTAssertEqual(result.modelUsed, .arabic)
    }

    func testAutoRoutingReroutesToMalayHintWhenClassifierIsConfident() async throws {
        let mock = MockWhisperEngine(text: "Nak pergi makan tak? Jalan sekarang.")
        let service = makeService(returning: mock)

        let result = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2])

        let received = await mock.receivedOptions
        XCTAssertEqual(received.count, 2, "should re-transcribe once the draft pass reads as confidently dominant Malay")
        XCTAssertEqual(received.last?.languageHint, "ms")
        XCTAssertEqual(result.modelUsed, .malay)
    }

    func testAnnotationTagsAreStrippedFromTheFinalText() async throws {
        let mock = MockWhisperEngine(text: "<SPK/> hello <NON/>")
        let service = makeService(returning: mock)

        let result = try await service.transcribe(samples: [0.1, 0.2], using: .singlish)

        XCTAssertEqual(result.text, "hello")
    }

    func testNativeLIDPreCheckStartsDirectlyWithArabicWhenConfident() async throws {
        let mock = MockWhisperEngine(text: "بسم الله الرحمن الرحيم", arabicProbability: 0.9)
        let service = makeService(returning: mock)

        let result = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2, 0.3])

        let received = await mock.receivedOptions
        let precheckCalls = await mock.arabicLanguageProbabilityCallCount
        XCTAssertEqual(precheckCalls, 1)
        // A confident pre-check should skip straight to Arabic - the draft
        // pass uses Arabic's own hint, not the usual Singlish-first pass.
        // A second call follows: the draft segment is exactly 1.0s (the
        // per-segment reprocessing threshold), so it still gets language-ID
        // probed like any other segment - this mock has no detectedLanguage
        // configured, so the probe finds nothing to reroute and the draft
        // text stands unchanged.
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received.first?.languageHint, WhisperModelType.arabic.languageHint)
        XCTAssertEqual(result.modelUsed, .arabic)
    }

    func testNativeLIDPreCheckLeavesSinglishFirstWhenNotConfidentlyArabic() async throws {
        // Same text/expectation as testAutoRoutingDraftPassUsesTheSameHintAsAForcedTranscribe -
        // a low pre-check probability should change nothing about existing routing.
        let mock = MockWhisperEngine(text: "wallah jalan jalan cari makan lah", arabicProbability: 0.1)
        let service = makeService(returning: mock)

        let result = try await service.transcribeWithAutoRouting(samples: [0.1, 0.2, 0.3])

        let received = await mock.receivedOptions
        let precheckCalls = await mock.arabicLanguageProbabilityCallCount
        XCTAssertEqual(precheckCalls, 1)
        // Second call is per-segment reprocessing's language-ID probe on the
        // one (1.0s) draft segment - same reasoning as the confident-Arabic
        // case above.
        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(received.first?.languageHint, WhisperModelType.singlish.languageHint)
        XCTAssertEqual(result.modelUsed, .singlish)
    }

    func testCustomDictionaryCorrectionsApplyToTheFinalTextEndToEnd() async throws {
        // Pins down the actual wiring (WhisperService -> CustomDictionaryService),
        // not just CustomDictionaryService.apply(to:) in isolation - this is exactly
        // the class of bug this repo's routing tests already exist to catch.
        let mock = MockWhisperEngine(text: "wah nassar can one lah")
        let dictionary = CustomDictionaryService(defaults: UserDefaults(suiteName: "WhisperServiceRoutingTests.\(UUID().uuidString)")!)
        dictionary.add(original: "nassar", replacement: "Nasar")
        let service = WhisperService(modelStore: StubModelStore(), customDictionary: dictionary, cleanupLevel: { .raw }, makeEngine: { _ in mock })

        let result = try await service.transcribe(samples: [0.1, 0.2], using: .singlish)

        XCTAssertEqual(result.text, "wah Nasar can one lah")
    }

    // MARK: - Per-segment code-switching reprocessing

    func testSegmentReprocessingReroutesASegmentWhoseOwnAudioDetectsADifferentLanguage() async throws {
        // Mirrors a real bug from project history: an isolated Malay word got
        // hallucinated into unrelated English text by the default model, so
        // there was no Malay *keyword* left in the final text for a
        // whole-clip classifier to catch - but the segment's own AUDIO still
        // confidently detects as Malay, which per-segment reprocessing
        // checks instead of re-reading the same already-wrong text.
        let draftSegment = WhisperEngine.Segment(text: "what my", startTime: 0, endTime: 2)
        let singlishMock = MockWhisperEngine(segments: [draftSegment], detectedLanguage: "ms")
        let malayMock = MockWhisperEngine(text: "jalan", detectedLanguage: "ms")
        let service = makeService(engines: [.singlish: singlishMock, .malay: malayMock])

        let result = try await service.transcribeWithAutoRouting(samples: Array(repeating: Float(0.1), count: 32_000))

        XCTAssertEqual(result.text, "jalan")
        XCTAssertEqual(result.modelUsed, .singlish, "primary model stays the default - only the one segment rerouted, not the whole clip")
        XCTAssertEqual(result.languageComponents, [.malay])
        let singlishCallCount = await singlishMock.callCount
        let malayCallCount = await malayMock.callCount
        XCTAssertEqual(singlishCallCount, 2, "one draft decode + one language-ID probe on the segment's own audio")
        XCTAssertEqual(malayCallCount, 1, "should re-decode the segment exactly once with the better-suited model")
    }

    func testSegmentReprocessingLeavesAgreeingSegmentsUntouched() async throws {
        let draftSegment = WhisperEngine.Segment(text: "so I have this laptop", startTime: 0, endTime: 2)
        let singlishMock = MockWhisperEngine(segments: [draftSegment], detectedLanguage: "en")
        let service = makeService(returning: singlishMock)

        let result = try await service.transcribeWithAutoRouting(samples: Array(repeating: Float(0.1), count: 32_000))

        XCTAssertEqual(result.text, "so I have this laptop", "segment's own audio agrees with the default model - no reroute")
        XCTAssertEqual(result.modelUsed, .singlish)
    }

    func testSegmentReprocessingSkipsSegmentsTooShortToTrust() async throws {
        // Under the ~1s threshold - per the research behind this feature,
        // whisper.cpp's own language detection gets meaningfully less
        // reliable below that, so a short segment keeps its draft text
        // rather than risk a confident-sounding wrong reroute off too
        // little audio - even though this mock is (deliberately) configured
        // to "detect" a different language, to prove the length guard is
        // what's skipping it, not a lack of disagreement.
        let shortSegment = WhisperEngine.Segment(text: "eh", startTime: 0, endTime: 0.4)
        let singlishMock = MockWhisperEngine(segments: [shortSegment], detectedLanguage: "ms")
        let service = makeService(returning: singlishMock)

        let result = try await service.transcribeWithAutoRouting(samples: Array(repeating: Float(0.1), count: 6_400))

        XCTAssertEqual(result.text, "eh")
        let callCount = await singlishMock.callCount
        XCTAssertEqual(callCount, 1, "should be only the draft pass - too short to spend a probe call on")
    }

    // MARK: - Chunk duration (Settings' "Chunk length" - previously persisted but never read)

    func testChunkDurationSecondsActuallyControlsChunkBoundaries() async throws {
        // 2.5s of audio. A 1s chunk window must split this into 3 decode calls
        // (0-1s, 1-2s, 2-2.5s) - if this parameter were silently ignored (the
        // exact bug being fixed here), it would fall back to the 30s default
        // and this whole clip would fit in a single call instead.
        let mock = MockWhisperEngine(text: "chunk")
        let service = makeService(returning: mock)
        let samples = Array(repeating: Float(0.1), count: 40_000) // 2.5s @ 16kHz

        _ = try await service.transcribe(samples: samples, using: .singlish, chunkDurationSeconds: 1.0)

        let callCount = await mock.callCount
        XCTAssertEqual(callCount, 3, "1s chunks over 2.5s of audio should decode in 3 pieces, not 1")
    }

    func testChunkDurationSecondsDefaultsToTheOriginalThirtySecondBehavior() async throws {
        // Same 2.5s clip as above, but with no chunkDurationSeconds argument -
        // callers that don't pass one (tests, and any future forced-model call
        // site) must keep getting the original ~30s-window behavior, not a
        // breaking change in disguise.
        let mock = MockWhisperEngine(text: "chunk")
        let service = makeService(returning: mock)
        let samples = Array(repeating: Float(0.1), count: 40_000) // 2.5s @ 16kHz - well under 30s

        _ = try await service.transcribe(samples: samples, using: .singlish)

        let callCount = await mock.callCount
        XCTAssertEqual(callCount, 1, "2.5s of audio is nowhere near the default 30s window - should be a single call")
    }
}
