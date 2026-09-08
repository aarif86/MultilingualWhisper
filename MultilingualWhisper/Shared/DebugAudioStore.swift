import AVFoundation

/// Optionally saves raw recordings as WAV files, purely so a real transcription
/// problem can be debugged against the actual audio instead of a typed-out
/// description of what was said. Off by default - see
/// `AppSettings.saveDebugAudio` for why this needs an explicit opt-in - and even
/// when on, only ever written to the local App Group container, never uploaded,
/// same as everything else in this app.
///
/// Lives in `Shared/` alongside `DebugLogger` on the same reasoning: the App
/// Group container is visible to both the main app and the keyboard extension,
/// where a plain Documents-directory save would only be visible to whichever
/// process wrote it.
enum DebugAudioStore {
    /// Keeps only the most recent recordings - this is a debugging aid, not a
    /// permanent recordings archive, so it shouldn't grow without bound.
    private static let maxKeptFiles = 5

    /// Deliberately not `sampleRate`: `Constants` lives in `Utils/`,
    /// which isn't part of the keyboard extension target's sources, and this
    /// file (in `Shared/`) is compiled into both targets - referencing it here
    /// would break the keyboard extension's build. Whisper's required 16kHz is
    /// effectively fixed, not something that changes independently per caller.
    private static let sampleRate: Double = 16_000

    private static var directoryURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DictationHandoff.appGroupID)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("DebugAudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// `samples` must already be 16kHz mono Float32 PCM (see `AudioService`) -
    /// the same format WhisperEngine expects, so what gets saved is exactly
    /// what the model actually heard.
    @discardableResult
    static func save(samples: [Float]) -> URL? {
        guard !samples.isEmpty,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { return nil }

        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { pointer in
            buffer.floatChannelData?[0].update(from: pointer.baseAddress!, count: samples.count)
        }

        let url = directoryURL.appendingPathComponent("debug-audio-\(Int(Date().timeIntervalSince1970)).wav")
        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]

        do {
            let file = try AVAudioFile(forWriting: url, settings: fileSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buffer)
        } catch {
            DebugLogger.shared.log("failed to save debug audio: \(error)", category: "debug-audio")
            return nil
        }

        pruneOldFiles()
        return url
    }

    /// Newest first.
    static func allFiles() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        return files.sorted { modificationDate(of: $0) > modificationDate(of: $1) }
    }

    static func latestFile() -> URL? { allFiles().first }

    static func clear() {
        for file in allFiles() { try? FileManager.default.removeItem(at: file) }
    }

    private static func pruneOldFiles() {
        let files = allFiles()
        guard files.count > maxKeptFiles else { return }
        for file in files[maxKeptFiles...] { try? FileManager.default.removeItem(at: file) }
    }

    private static func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }
}
