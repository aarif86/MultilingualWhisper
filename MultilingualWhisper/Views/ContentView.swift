import SwiftUI

struct ContentView: View {
    let audioService: AudioService
    let whisperService: WhisperService
    let modelDownloadService: ModelDownloadService
    let flowSession: FlowSessionEngine
    @Binding var quickDictateActive: Bool
    let quickDictateSessionID: UUID

    var body: some View {
        TabView {
            TranscriptionView(audioService: audioService, whisperService: whisperService)
                .tabItem { Label("Transcribe", systemImage: "waveform") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }

            SettingsView(modelDownloadService: modelDownloadService, flowSession: flowSession)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .fullScreenCover(isPresented: $quickDictateActive) {
            QuickDictateView(audioService: audioService, whisperService: whisperService)
                .id(quickDictateSessionID)
        }
    }
}
