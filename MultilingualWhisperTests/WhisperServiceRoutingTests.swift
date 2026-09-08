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
    private(set) var receivedOptions: [WhisperEngine.TranscriptionOptions] = []
    private(set) var callCount = 0

    init(text: String, detectedLanguage: String? = nil) {
        self.segments = [WhisperEngine.Segment(text: text, startTime: 0, endTime: 1)]
        self.detectedLanguage = detectedLanguage
    }

    init(segments: [WhisperEngine.Segment], detectedLanguage: String? = nil) {
        self.segments = segments
        self.detectedLanguage = detectedLanguage
    }

    func transcribe(samples: [Float], options: WhisperEngine.TranscriptionOptions) async throws -> [WhisperEngine.Segment] {
        callCount += 1
        receivedOptions.append(options)
        return segments
    }

    func detectedLanguageCode() async -> String? { detectedLanguage }
}

private struct StubModelStore: ModelStoring {
    func isDownloaded(_ model: WhisperModelType) -> Bool { true }
    func localURL(for model: WhisperModelType) -> URL? { URL(fileURLWithPath: "/dev/null/\(model.rawValue)") }
}

@MainActor
final class WhisperServiceRoutingTests: XCTestCase {
    private func makeService(returning mock: MockWhisperEngine) -> WhisperService {
        WhisperService(modelStore: StubModelStore(), customDictionary: CustomDictionaryService(), makeEngine: { _ in mock })
    }

    /// For tests that need DIFFERENT engines per model (e.g. the default
    /// model's probe detects Malay, so a separate Malay mock should be the
    /// one that actually re-decodes) - `StubModelStore.localURL` bakes the
    /// model's own `rawValue` into the fake path, which is what lets this
    /// pick the right mock without `WhisperService` needing to expose model
    /// identity to its `makeEngine` factory at all.
    private func makeService(engines: [WhisperModelType: MockWhisperEngine]) -> WhisperService {
        WhisperService(modelStore: StubModelStore(), makeEngine: { path in
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

    func testCustomDictionaryCorrectionsApplyToTheFinalTextEndToEnd() async throws {
        // Pins down the actual wiring (WhisperService -> CustomDictionaryService),
        // not just CustomDictionaryService.apply(to:) in isolation - this is exactly
        // the class of bug this repo's routing tests already exist to catch.
        let mock = MockWhisperEngine(text: "wah nassar can one lah")
        let dictionary = CustomDictionaryService(defaults: UserDefaults(suiteName: "WhisperServiceRoutingTests.\(UUID().uuidString)")!)
        dictionary.add(original: "nassar", replacement: "Nasar")
        let service = WhisperService(modelStore: StubModelStore(), customDictionary: dictionary, makeEngine: { _ in mock })

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
}
