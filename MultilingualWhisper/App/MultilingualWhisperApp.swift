import SwiftData
import SwiftUI

@main
struct MultilingualWhisperApp: App {
    private let modelContainer = PersistenceService.makeModelContainer()

    @State private var audioService = AudioService()
    @State private var modelDownloadService: ModelDownloadService
    @State private var whisperService: WhisperService
    @State private var customDictionaryService: CustomDictionaryService
    @State private var flowSession: FlowSessionEngine
    @State private var quickDictateActive = false
    @State private var quickDictateSessionID = UUID()
    @State private var showFlowActivation = false
    @State private var intentRouter = AppIntentRouter.shared

    init() {
        // whisperService depends on modelDownloadService (it asks it "is X downloaded,
        // where's the file"), so it can't just be another independently-defaulted
        // @State property - it has to be built after modelDownloadService exists.
        // customDictionaryService is built once here and threaded into both
        // whisperService and Settings, so edits made in Settings actually affect
        // live transcription instead of a second, disconnected instance. Same
        // reasoning for flowSession depending on whisperService.
        let downloadService = ModelDownloadService()
        Self.applyOnboardingLaunchRules(modelStore: downloadService)
        // learnedStore: the keyboard queues spelling corrections it noticed (see
        // CorrectionLearner); the service pulls them in here and on foreground.
        let dictionaryService = CustomDictionaryService(learnedStore: .shared)
        let whisper = WhisperService(modelStore: downloadService, customDictionary: dictionaryService)
        _modelDownloadService = State(initialValue: downloadService)
        _customDictionaryService = State(initialValue: dictionaryService)
        _whisperService = State(initialValue: whisper)
        _flowSession = State(initialValue: FlowSessionEngine(whisperService: whisper, modelContainer: modelContainer))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                audioService: audioService,
                whisperService: whisperService,
                modelDownloadService: modelDownloadService,
                customDictionaryService: customDictionaryService,
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
                    startQuickDictate()
                case DictationHandoff.startFlowHost:
                    showFlowActivation = true
                default:
                    break
                }
            }
            // App Intents (Shortcuts, Siri, Action Button, Back Tap) leave a request
            // on the router; a cold launch may have queued one before this view
            // existed, so check on appear as well as on change.
            .onAppear { handleIntentRequest() }
            .onChange(of: intentRouter.sequence) { _, _ in handleIntentRequest() }
            .sheet(isPresented: $showFlowActivation) {
                FlowActivationView(flowSession: flowSession)
            }
        }
        .modelContainer(modelContainer)
    }

    /// First launch shows `OnboardingView`; an install that already has a model
    /// downloaded (every user before this screen existed) never sees it. UI tests
    /// pass `--skip-onboarding` so the existing launch tests land on Home, or
    /// `--reset-onboarding` to exercise the screens.
    private static func applyOnboardingLaunchRules(modelStore: ModelDownloadService) {
        let defaults = UserDefaults.standard
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--reset-onboarding") {
            defaults.set(false, forKey: OnboardingView.completedKey)
            return
        }
        if arguments.contains("--skip-onboarding") {
            defaults.set(true, forKey: OnboardingView.completedKey)
            return
        }
        if !defaults.bool(forKey: OnboardingView.completedKey),
           WhisperModelType.allCases.contains(where: { modelStore.isDownloaded($0) }) {
            defaults.set(true, forKey: OnboardingView.completedKey)
        }
    }

    /// A fresh UUID forces SwiftUI to recreate QuickDictateView even if the cover
    /// is already showing - e.g. the user dictated again without dismissing the
    /// previous result, easy to do now that leaving via the system back gesture
    /// skips "Done".
    private func startQuickDictate() {
        quickDictateSessionID = UUID()
        quickDictateActive = true
    }

    private func handleIntentRequest() {
        guard let request = intentRouter.consume() else { return }
        DebugLogger.shared.log("App Intent request: \(request)", category: "app")
        switch request {
        case .dictate:
            startQuickDictate()
        case .startFlow:
            showFlowActivation = true
        case .stopFlow:
            flowSession.end()
        }
    }
}
