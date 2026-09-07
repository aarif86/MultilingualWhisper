import SwiftData
import SwiftUI

@main
struct MultilingualWhisperApp: App {
    private let modelContainer = PersistenceService.makeModelContainer()

    @State private var audioService = AudioService()
    @State private var modelDownloadService: ModelDownloadService
    @State private var whisperService: WhisperService
    @State private var flowSession: FlowSessionEngine
    @State private var quickDictateActive = false
    @State private var quickDictateSessionID = UUID()
    @State private var showFlowActivation = false

    init() {
        // whisperService depends on modelDownloadService (it asks it "is X downloaded,
        // where's the file"), so it can't just be another independently-defaulted
        // @State property - it has to be built after modelDownloadService exists.
        // Same reasoning for flowSession depending on whisperService.
        let downloadService = ModelDownloadService()
        let whisper = WhisperService(modelStore: downloadService)
        _modelDownloadService = State(initialValue: downloadService)
        _whisperService = State(initialValue: whisper)
        _flowSession = State(initialValue: FlowSessionEngine(whisperService: whisper, modelContainer: modelContainer))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                audioService: audioService,
                whisperService: whisperService,
                modelDownloadService: modelDownloadService,
                flowSession: flowSession,
                quickDictateActive: $quickDictateActive,
                quickDictateSessionID: quickDictateSessionID
            )
            // The keyboard extension launches one of two URLs (Full Access
            // required for a keyboard to open a URL at all) - see
            // DictationHandoff.swift and NasarFlowKeyboard/.
            .onOpenURL { url in
                DebugLogger.shared.log("onOpenURL received: \(url)", category: "app")
                guard url.scheme == DictationHandoff.urlScheme else { return }
                switch url.host {
                case DictationHandoff.dictateHost:
                    // A fresh UUID forces SwiftUI to recreate QuickDictateView
                    // even if the cover is already showing - e.g. the user
                    // dictated again without dismissing the previous result,
                    // easy to do now that leaving via the system back gesture
                    // skips "Done".
                    quickDictateSessionID = UUID()
                    quickDictateActive = true
                case DictationHandoff.startFlowHost:
                    showFlowActivation = true
                default:
                    break
                }
            }
            .sheet(isPresented: $showFlowActivation) {
                FlowActivationView(flowSession: flowSession)
            }
        }
        .modelContainer(modelContainer)
    }
}
