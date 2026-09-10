import SwiftUI

struct ContentView: View {
    let audioService: AudioService
    let whisperService: WhisperService
    let modelDownloadService: ModelDownloadService
    let customDictionaryService: CustomDictionaryService
    let userLanguageKeywords: UserLanguageKeywords
    let flowSession: FlowSessionEngine
    @Binding var quickDictateActive: Bool
    let quickDictateSessionID: UUID
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = false

    /// Shown until finished or skipped; never re-shown afterwards.
    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )
    }

    var body: some View {
        TabView {
            HomeView(audioService: audioService, whisperService: whisperService, flowSession: flowSession)
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                CustomDictionaryView(dictionaryService: customDictionaryService, languageKeywords: userLanguageKeywords)
            }
            .tabItem { Label("Dictionary", systemImage: "textformat.abc") }

            SettingsView(modelDownloadService: modelDownloadService)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .fullScreenCover(isPresented: $quickDictateActive) {
            QuickDictateView(audioService: audioService, whisperService: whisperService)
                .id(quickDictateSessionID)
        }
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView(modelDownloadService: modelDownloadService) {
                hasCompletedOnboarding = true
            }
            .interactiveDismissDisabled()
        }
    }
}
