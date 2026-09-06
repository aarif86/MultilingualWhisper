import CryptoKit
import Foundation
import Observation

/// Downloads GGML model files, verifies them, and stores them under Application
/// Support (excluded from iCloud backup - they're large and re-downloadable).
///
/// URLSessionDownloadDelegate's requirements aren't actor-isolated, and URLSession
/// calls them from its own background queue - mixing that directly into a
/// `@MainActor` type runs into isolation conflicts with the delegate protocol.
/// So the delegate target is a small plain `NSObject` (`DownloadCoordinator`) that
/// forwards results here via closures, and this class does all the `@Observable`
/// state management on the main actor.
@MainActor
@Observable
final class ModelDownloadService {

    enum DownloadState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case paused(progress: Double)
        case verifying
        case downloaded
        case failed(String)
    }

    private(set) var states: [WhisperModelType: DownloadState] = [:]

    private let coordinator = DownloadCoordinator()
    private var session: URLSession!
    private var activeTasks: [WhisperModelType: URLSessionDownloadTask] = [:]
    private var resumeDataByModel: [WhisperModelType: Data] = [:]
    private var lastProgressByModel: [WhisperModelType: Double] = [:]

    init() {
        for model in WhisperModelType.allCases {
            states[model] = FileManager.default.fileExists(atPath: Self.localURL(for: model).path)
                ? .downloaded
                : .notDownloaded
        }

        coordinator.onProgress = { [weak self] task, progress in
            Task { @MainActor in
                guard let self, let model = self.model(for: task) else { return }
                self.lastProgressByModel[model] = progress
                self.states[model] = .downloading(progress: progress)
            }
        }
        coordinator.onFinished = { [weak self] task, stagedURL in
            Task { @MainActor in
                guard let self, let model = self.model(for: task) else { return }
                await self.finalizeDownload(of: model, stagedAt: stagedURL)
            }
        }
        coordinator.onCompleteWithError = { [weak self] task, error in
            Task { @MainActor in
                guard let self, let model = self.model(for: task) else { return }
                self.activeTasks[model] = nil
                let nsError = error as NSError
                if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    self.resumeDataByModel[model] = resumeData
                }
                if nsError.code == NSURLErrorCancelled {
                    let progress = self.lastProgressByModel[model] ?? 0
                    self.states[model] = resumeData(nsError) != nil ? .paused(progress: progress) : .notDownloaded
                } else {
                    self.states[model] = .failed(error.localizedDescription)
                }
            }
        }

        session = URLSession(configuration: .default, delegate: coordinator, delegateQueue: nil)
    }

    // MARK: - Public API

    func startDownload(_ model: WhisperModelType) {
        guard activeTasks[model] == nil else { return }
        guard let remoteURL = model.remoteURL else {
            states[model] = .failed("No download URL configured for \(model.displayName) yet - set one in Constants.swift.")
            return
        }

        let task: URLSessionDownloadTask
        if let resumeData = resumeDataByModel[model] {
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            task = session.downloadTask(with: remoteURL)
        }
        activeTasks[model] = task
        states[model] = .downloading(progress: lastProgressByModel[model] ?? 0)
        task.resume()
    }

    /// Cancels but keeps resume data, so the next `startDownload` picks up where it left off.
    ///
    /// This only captures the resume data - it deliberately does NOT touch `states`
    /// or `activeTasks` itself. Cancelling also fires the delegate's
    /// `didCompleteWithError` (via `onCompleteWithError` below) with the same resume
    /// data attached, and that's the single place that owns those state transitions.
    /// Updating them from both places would race two independent `Task { @MainActor }`
    /// hops against each other for the same event.
    func pauseDownload(_ model: WhisperModelType) {
        activeTasks[model]?.cancel(byProducingResumeData: { [weak self] data in
            guard let data else { return }
            Task { @MainActor in
                self?.resumeDataByModel[model] = data
            }
        })
    }

    func deleteModel(_ model: WhisperModelType) {
        activeTasks[model]?.cancel()
        activeTasks[model] = nil
        resumeDataByModel[model] = nil
        lastProgressByModel[model] = nil
        try? FileManager.default.removeItem(at: Self.localURL(for: model))
        states[model] = .notDownloaded
    }

    var totalStorageUsedBytes: Int64 {
        var total: Int64 = 0
        for model in WhisperModelType.allCases where isDownloaded(model) {
            let path = Self.localURL(for: model).path
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    // MARK: - File locations

    // These are `nonisolated` because they touch no instance state, and `sha256Hex`
    // below specifically needs to run inside a `Task.detached` (off the main actor) -
    // static members of a `@MainActor` type are main-actor-isolated by default, which
    // would otherwise make that detached call illegal without an `await` hop back.
    nonisolated static func modelsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Models", isDirectory: true)
    }

    nonisolated static func localURL(for model: WhisperModelType) -> URL {
        modelsDirectory().appendingPathComponent(model.localFileName)
    }

    // MARK: - Internals

    private func model(for task: URLSessionTask) -> WhisperModelType? {
        activeTasks.first(where: { $0.value === task })?.key
    }

    private func finalizeDownload(of model: WhisperModelType, stagedAt stagedURL: URL) async {
        states[model] = .verifying

        if let expected = model.expectedChecksum {
            do {
                let actual = try await Task.detached(priority: .utility) {
                    try Self.sha256Hex(of: stagedURL)
                }.value
                guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
                    try? FileManager.default.removeItem(at: stagedURL)
                    activeTasks[model] = nil
                    states[model] = .failed("Downloaded file failed checksum verification - try again.")
                    return
                }
            } catch {
                try? FileManager.default.removeItem(at: stagedURL)
                activeTasks[model] = nil
                states[model] = .failed("Couldn't verify the download: \(error.localizedDescription)")
                return
            }
        }

        do {
            let destination = Self.localURL(for: model)
            try FileManager.default.createDirectory(at: Self.modelsDirectory(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: stagedURL, to: destination)
            Self.excludeFromBackup(destination)
            resumeDataByModel[model] = nil
            lastProgressByModel[model] = nil
            activeTasks[model] = nil
            states[model] = .downloaded
        } catch {
            activeTasks[model] = nil
            states[model] = .failed("Couldn't save the model file: \(error.localizedDescription)")
        }
    }

    nonisolated private static func excludeFromBackup(_ url: URL) {
        var url = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? url.setResourceValues(resourceValues)
    }

    nonisolated private static func sha256Hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 4 * 1024 * 1024) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

extension ModelDownloadService: ModelStoring {
    func isDownloaded(_ model: WhisperModelType) -> Bool {
        if case .downloaded = states[model] { return true }
        return false
    }

    func localURL(for model: WhisperModelType) -> URL? {
        isDownloaded(model) ? Self.localURL(for: model) : nil
    }
}

/// Extracts resume data from a download error, if the OS provided any.
private func resumeData(_ error: NSError) -> Data? {
    error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
}

/// Plain, non-isolated delegate target. URLSession invokes these on its own
/// background queue; they do no state mutation themselves; they just forward to
/// `ModelDownloadService` via closures dispatched onto the main actor.
private final class DownloadCoordinator: NSObject, URLSessionDownloadDelegate {
    var onProgress: ((URLSessionDownloadTask, Double) -> Void)?
    var onFinished: ((URLSessionDownloadTask, URL) -> Void)?
    var onCompleteWithError: ((URLSessionTask, Error) -> Void)?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress?(downloadTask, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The OS deletes whatever's at `location` as soon as this method returns,
        // so the move to a stable temp location must happen synchronously, here.
        let staged = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: staged)
            onFinished?(downloadTask, staged)
        } catch {
            onCompleteWithError?(downloadTask, error)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return } // success is handled in didFinishDownloadingTo
        onCompleteWithError?(task, error)
    }
}
