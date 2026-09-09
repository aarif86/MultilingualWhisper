import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    let settings: AppSettings
    let modelDownloadService: ModelDownloadService

    init(modelDownloadService: ModelDownloadService, settings: AppSettings = .shared) {
        self.modelDownloadService = modelDownloadService
        self.settings = settings
    }

    var languageMode: LanguageMode {
        get { settings.languageMode }
        set { settings.languageMode = newValue }
    }

    var vadSensitivity: Float {
        get { settings.vadSensitivity }
        set { settings.vadSensitivity = newValue }
    }

    var autoStopOnSilence: Bool {
        get { settings.autoStopOnSilence }
        set { settings.autoStopOnSilence = newValue }
    }

    var autoPunctuation: Bool {
        get { settings.autoPunctuation }
        set { settings.autoPunctuation = newValue }
    }

    var cleanupLevel: CleanupLevel {
        get { settings.cleanupLevel }
        set { settings.cleanupLevel = newValue }
    }

    var maxRecordDurationSeconds: Int {
        get { settings.maxRecordDurationSeconds }
        set { settings.maxRecordDurationSeconds = newValue }
    }

    var saveDebugAudio: Bool {
        get { settings.saveDebugAudio }
        set { settings.saveDebugAudio = newValue }
    }

    var storageUsedDescription: String {
        ByteCountFormatter.string(fromByteCount: modelDownloadService.totalStorageUsedBytes, countStyle: .file)
    }

    func state(for model: WhisperModelType) -> ModelDownloadService.DownloadState {
        modelDownloadService.states[model] ?? .notDownloaded
    }

    func approxSizeDescription(for model: WhisperModelType) -> String {
        ByteCountFormatter.string(fromByteCount: model.approxSizeBytes, countStyle: .file)
    }

    func primaryAction(for model: WhisperModelType) {
        switch state(for: model) {
        case .notDownloaded, .paused, .failed:
            modelDownloadService.startDownload(model)
        case .downloading:
            modelDownloadService.pauseDownload(model)
        case .verifying, .downloaded:
            break
        }
    }

    func delete(_ model: WhisperModelType) {
        modelDownloadService.deleteModel(model)
    }
}
