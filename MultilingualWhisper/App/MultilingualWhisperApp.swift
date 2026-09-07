import SwiftData
import SwiftUI

@main
struct MultilingualWhisperApp: App {
    private let modelContainer = PersistenceService.makeModelContainer()

    @State private var audioService = AudioService()
    @State private var modelDownloadService: ModelDownloadService
    @State private var whisperService: WhisperService
    @State private var quickDictateActive = false

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
                modelDownloadService: modelDownloadService,
                quickDictateActive: $quickDictateActive
            )
            // The keyboard extension launches nasarflow://dictate (Full Access
            // required for a keyboard to open a URL at all) when its Dictate
            // button is tapped - see DictationHandoff.swift and NasarFlowKeyboard/.
            .onOpenURL { url in
                DebugLogger.shared.log("onOpenURL received: \(url)", category: "app")
                guard url.scheme == DictationHandoff.urlScheme,
                      url.host == DictationHandoff.dictateHost else { return }
                quickDictateActive = true
            }
        }
        .modelContainer(modelContainer)
    }
}
