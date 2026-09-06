import SwiftData
import SwiftUI

@main
struct MultilingualWhisperApp: App {
    private let modelContainer = PersistenceService.makeModelContainer()

    @State private var audioService = AudioService()
    @State private var modelDownloadService: ModelDownloadService
    @State private var whisperService: WhisperService

    init() {
        // whisperService depends on modelDownloadService (it asks it "is X downloaded,
        // where's the file"), so it can't just be another independently-defaulted
        // @State property - it has to be built after modelDownloadService exists.
        let downloadService = ModelDownloadService()
        _modelDownloadService = State(initialValue: downloadService)
        _whisperService = State(initialValue: WhisperService(modelStore: downloadService))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                audioService: audioService,
                whisperService: whisperService,
                modelDownloadService: modelDownloadService
            )
        }
        .modelContainer(modelContainer)
    }
}
