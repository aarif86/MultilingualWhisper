import SwiftData
import SwiftUI

@main
struct MultilingualWhisperApp: App {
    private let modelContainer = PersistenceService.makeModelContainer()

    @State private var audioService = AudioService()
    @State private var modelDownloadService: ModelDownloadService
    @State private var whisperService: WhisperService
    @State private var customDictionaryService: CustomDictionaryService
    @State private var quickDictateActive = false
    @State private var quickDictateSessionID = UUID()

    init() {
        // whisperService depends on modelDownloadService (it asks it "is X downloaded,
        // where's the file"), so it can't just be another independently-defaulted
        // @State property - it has to be built after modelDownloadService exists.
        // customDictionaryService is built once here and threaded into both
        // whisperService and Settings, so edits made in Settings actually affect
        // live transcription instead of a second, disconnected instance.
        let downloadService = ModelDownloadService()
        let dictionaryService = CustomDictionaryService()
        _modelDownloadService = State(initialValue: downloadService)
        _customDictionaryService = State(initialValue: dictionaryService)
        _whisperService = State(initialValue: WhisperService(modelStore: downloadService, customDictionary: dictionaryService))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                audioService: audioService,
                whisperService: whisperService,
                modelDownloadService: modelDownloadService,
                customDictionaryService: customDictionaryService,
                quickDictateActive: $quickDictateActive,
                quickDictateSessionID: quickDictateSessionID
            )
            // The keyboard extension launches nasarflow://dictate (Full Access
            // required for a keyboard to open a URL at all) when its Dictate
            // button is tapped - see DictationHandoff.swift and NasarFlowKeyboard/.
            .onOpenURL { url in
                DebugLogger.shared.log("onOpenURL received: \(url)", category: "app")
                guard url.scheme == DictationHandoff.urlScheme,
                      url.host == DictationHandoff.dictateHost else { return }
                // A fresh UUID forces SwiftUI to recreate QuickDictateView even
                // if the cover is already showing - e.g. the user dictated
                // again without dismissing the previous result, easy to do now
                // that leaving via the system back gesture skips "Done".
                quickDictateSessionID = UUID()
                quickDictateActive = true
            }
        }
        .modelContainer(modelContainer)
    }
}
