import XCTest
@testable import MultilingualWhisper

final class UtteranceAudioStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UtteranceAudioStore.clear()
    }

    override func tearDown() {
        UtteranceAudioStore.clear()
        super.tearDown()
    }

    private func tone(seconds: Double = 0.5) -> [Float] {
        let count = Int(Constants.sampleRate * seconds)
        return (0..<count).map { i in Float(sin(Double(i) * 2 * .pi * 440 / Constants.sampleRate)) * 0.5 }
    }

    func testSaveThenLoadRoundTripsTheSamples() throws {
        let samples = tone()
        let name = try XCTUnwrap(UtteranceAudioStore.save(samples: samples))
        XCTAssertTrue(name.hasSuffix(".wav"))
        XCTAssertTrue(UtteranceAudioStore.exists(name))

        let loaded = try XCTUnwrap(UtteranceAudioStore.load(named: name))
        XCTAssertEqual(loaded.count, samples.count)
        // 16-bit on disk, so allow quantisation noise.
        for i in stride(from: 0, to: samples.count, by: 97) {
            XCTAssertEqual(loaded[i], samples[i], accuracy: 0.001)
        }
    }

    func testEmptySamplesAreNotSaved() {
        XCTAssertNil(UtteranceAudioStore.save(samples: []))
    }

    func testMissingFile() {
        XCTAssertFalse(UtteranceAudioStore.exists("nope.wav"))
        XCTAssertFalse(UtteranceAudioStore.exists(nil))
        XCTAssertNil(UtteranceAudioStore.load(named: "nope.wav"))
    }

    func testPruneKeepsOnlyTheNewest() throws {
        var names: [String] = []
        for _ in 0..<4 {
            names.append(try XCTUnwrap(UtteranceAudioStore.save(samples: tone(seconds: 0.05), maxKept: 3)))
            // Distinct modification times so "newest" is well defined.
            Thread.sleep(forTimeInterval: 0.02)
        }
        XCTAssertFalse(UtteranceAudioStore.exists(names[0]), "the oldest should have been pruned")
        XCTAssertTrue(UtteranceAudioStore.exists(names[3]))
        XCTAssertEqual(UtteranceAudioStore.allFiles().count, 3)
    }

    func testDeleteAndClear() throws {
        let name = try XCTUnwrap(UtteranceAudioStore.save(samples: tone(seconds: 0.05)))
        UtteranceAudioStore.delete(named: name)
        XCTAssertFalse(UtteranceAudioStore.exists(name))
        _ = UtteranceAudioStore.save(samples: tone(seconds: 0.05))
        UtteranceAudioStore.clear()
        XCTAssertTrue(UtteranceAudioStore.allFiles().isEmpty)
    }

    func testTranscriptionRetryFlags() throws {
        let name = try XCTUnwrap(UtteranceAudioStore.save(samples: tone(seconds: 0.05)))
        let failed = Transcription(text: "", duration: 1, languageUsed: .english, modelUsed: .english, audioFileName: name)
        XCTAssertTrue(failed.isFailedWithAudio)
        XCTAssertTrue(failed.canRetry)
        let plain = Transcription(text: "hello", duration: 1, languageUsed: .english, modelUsed: .english)
        XCTAssertFalse(plain.isFailedWithAudio)
        XCTAssertFalse(plain.canRetry)
    }
}
