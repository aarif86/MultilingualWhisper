import AVFoundation
import Foundation

/// Keeps the audio of the last few dictations on-device so a transcript can be
/// re-run with a different model, and so a decode that fails still leaves the
/// user with something to retry instead of nothing.
///
/// "Lost dictations" is the top mobile complaint for every app in
/// `docs/competitor-kb/user-voice.md`; the fix is to have the audio on disk
/// *before* decoding starts. Everything stays inside the app's own sandbox
/// (Application Support, file-protected, excluded from backup), never the
/// clipboard, never the network. `AppSettings.keepRecentAudio` turns it off.
///
/// Not the same thing as `DebugAudioStore`: that is an opt-in debugging aid in
/// the App Group; this is a product feature keyed to History entries by file name.
enum UtteranceAudioStore {
    private static let sampleRate = Constants.sampleRate

    static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("RecentUtterances", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutable = dir
            try? mutable.setResourceValues(values)
        }
        return dir
    }

    static func url(for fileName: String) -> URL {
        directoryURL.appendingPathComponent(fileName)
    }

    static func exists(_ fileName: String?) -> Bool {
        guard let fileName else { return false }
        return FileManager.default.fileExists(atPath: url(for: fileName).path)
    }

    /// Writes 16kHz mono Float32 samples as a 16-bit WAV and returns the file
    /// name to store on the History entry. Prunes to `Constants.maxRecentUtterances`.
    @discardableResult
    static func save(samples: [Float], maxKept: Int = Constants.maxRecentUtterances) -> String? {
        guard !samples.isEmpty,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        else { return nil }

        buffer.frameLength = buffer.frameCapacity
        samples.withUnsafeBufferPointer { pointer in
            buffer.floatChannelData?[0].update(from: pointer.baseAddress!, count: samples.count)
        }

        let fileName = "utterance-\(UUID().uuidString).wav"
        let target = url(for: fileName)
        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ]
        do {
            let file = try AVAudioFile(forWriting: target, settings: fileSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buffer)
        } catch {
            DebugLogger.shared.log("failed to keep utterance audio: \(error)", category: "audio-store")
            return nil
        }
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: target.path)
        prune(keeping: maxKept)
        return fileName
    }

    /// Reads a file written by `save` back into the exact sample format the
    /// engine expects.
    static func load(named fileName: String) -> [Float]? {
        let source = url(for: fileName)
        guard let file = try? AVAudioFile(forReading: source) else { return nil }
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else { return nil }
        do {
            try file.read(into: buffer)
        } catch {
            return nil
        }
        guard let channels = buffer.floatChannelData else { return nil }
        return Array(UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength)))
    }

    static func delete(named fileName: String?) {
        guard let fileName else { return }
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    /// Newest first.
    static func allFiles() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        return files.sorted { modificationDate(of: $0) > modificationDate(of: $1) }
    }

    static func clear() {
        for file in allFiles() { try? FileManager.default.removeItem(at: file) }
    }

    static func prune(keeping maxKept: Int) {
        let files = allFiles()
        guard files.count > maxKept else { return }
        for file in files[maxKept...] { try? FileManager.default.removeItem(at: file) }
    }

    private static func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }
}
