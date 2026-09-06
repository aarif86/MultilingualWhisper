import XCTest
@testable import MultilingualWhisper

/// Records the options each `transcribe` call was made with and always answers
/// with the same canned text - lets these tests pin down which language hint
/// `WhisperService` sends to the decoder for each pass, with no model file, no
/// audio hardware, and no physical device involved.
private actor MockWhisperEngine: WhisperTranscribing {
    private let text: String
    private(set) var receivedOptions: [WhisperEngine.TranscriptionOptions] = []

    init(text: String) {
        self.text = text
    }

    func transcribe(samples: [Float], options: WhisperEngine.TranscriptionOptions) async throws -> [WhisperEngine.Segment] {
        receivedOptions.append(options)
        return [WhisperEngine.Segment(text: text, startTime: 0, endTime: 1)]
    }
}

private struct StubModelStore: ModelStoring {
    func isDownloaded(_ model: WhisperModelType) -> Bool { true }
    func localURL(for model: WhisperModelType) -> URL? { URL(fileURLWithPath: "/dev/null/\(model.rawValue)") }
}

@MainActor
final class WhisperServiceRoutingTests: XCTestCase {
    private func makeService(returning mock: MockWhisperEngine) -> WhisperService {
        WhisperService(modelStore: StubModelStore(), makeEngine: { _ in mock })
    }

    func testForcedTranscribeUsesTheModelsOwnLanguageHint() async throws {
        let mock = MockWhisperEngine(text: "hello")
        let service = makeService(returning: mock)

        _ = try await service.transcribe(samples: [0.1, 0.2], using: .singlish)

        let received = await mock.receivedOptions
        XCTAssertEqual(received.first?.languageHint, "en")
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

    func testAnnotationTagsAreStrippedFromTheFinalText() async throws {
        let mock = MockWhisperEngine(text: "<SPK/> hello <NON/>")
        let service = makeService(returning: mock)

        let result = try await service.transcribe(samples: [0.1, 0.2], using: .singlish)

        XCTAssertEqual(result.text, "hello")
    }
}
