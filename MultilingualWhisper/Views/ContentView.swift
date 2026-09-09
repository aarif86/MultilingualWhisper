import SwiftUI

struct ContentView: View {
    let audioService: AudioService
    let whisperService: WhisperService
    let modelDownloadService: ModelDownloadService
    let customDictionaryService: CustomDictionaryService
    let flowSession: FlowSessionEngine
    @Binding var quickDictateActive: Bool
    let quickDictateSessionID: UUID

    var body: some View {
        TabView {
            HomeView(audioService: audioService, whisperService: whisperService, flowSession: flowSession)
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                CustomDictionaryView(dictionaryService: customDictionaryService)
            }
            .tabItem { Label("Dictionary", systemImage: "textformat.abc") }

            SettingsView(modelDownloadService: modelDownloadService)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .fullScreenCover(isPresented: $quickDictateActive) {
            QuickDictateView(audioService: audioService, whisperService: whisperService)
                .id(quickDictateSessionID)
        }
    }
}
