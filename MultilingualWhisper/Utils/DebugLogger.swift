import Foundation

/// A small on-device diagnostic log, entirely local - nothing here is ever sent
/// anywhere automatically, matching the app's "nothing you say ever leaves your
/// phone" promise. It exists because this app is built and tested without a Mac
/// or a physical device on hand: when something breaks silently (a recording
/// that produces no text, an error that only flashes past), a real log the user
/// can export from Settings and hand over is worth far more than a text
/// description of the symptom - see the "Share Debug Log" button in Settings.
actor DebugLogger {
    static let shared = DebugLogger()

    /// Safe to read synchronously (e.g. from a SwiftUI view) - it's fixed at
    /// init and never mutated afterwards.
    nonisolated let fileURL: URL

    /// Trimmed back to half this size once exceeded, so a long testing session
    /// can't grow the file without bound.
    private let maxBytes = 1_000_000

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = dir.appendingPathComponent("debug.log")
    }

    /// Fire-and-forget from any isolation context (main actor, the WhisperEngine
    /// actor, etc.) - hops onto this actor internally to do the actual write, so
    /// callers never need `await` just to leave a log line.
    nonisolated func log(_ message: String, category: String = "app") {
        Task { await self.append(message, category: category) }
    }

    func readAll() -> String {
        (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func append(_ message: String, category: String) {
        let line = "\(Self.formatter.string(from: Date())) [\(category)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: fileURL)
        }
        trimIfNeeded()
    }

    private func trimIfNeeded() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? Int,
              size > maxBytes,
              let contents = try? String(contentsOf: fileURL, encoding: .utf8)
        else { return }
        let trimmed = String(contents.suffix(maxBytes / 2))
        try? trimmed.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
