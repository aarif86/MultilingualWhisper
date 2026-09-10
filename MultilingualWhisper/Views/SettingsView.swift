import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transcriptions: [Transcription]
    @State private var viewModel: SettingsViewModel
    @State private var showClearAllConfirmation = false
    @State private var showKeyboardSetup = false
    @State private var showShortcutsGuide = false
    @AppStorage(OnboardingView.completedKey) private var hasCompletedOnboarding = false
    // Toggled after clearing the debug log/audio, and on every appearance of
    // this screen, to force hasDebugLog/latestDebugAudioURL to re-evaluate -
    // SwiftUI has no other reason to know a file written from the Home tab
    // (a different screen entirely) has appeared on disk.
    @State private var debugRefreshTrigger = false

    private var hasDebugLog: Bool {
        _ = debugRefreshTrigger
        return FileManager.default.fileExists(atPath: DebugLogger.shared.fileURL.path)
    }

    private var latestDebugAudioURL: URL? {
        _ = debugRefreshTrigger
        return DebugAudioStore.latestFile()
    }

    private var latencySummary: String? {
        _ = debugRefreshTrigger
        return LatencyLog.shared.summary()
    }

    init(modelDownloadService: ModelDownloadService) {
        _viewModel = State(initialValue: SettingsViewModel(modelDownloadService: modelDownloadService))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Language Settings") {
                    Picker("Language Mode", selection: $viewModel.languageMode) {
                        ForEach(LanguageMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }

                Section {
                    Button {
                        showKeyboardSetup = true
                    } label: {
                        Label("Set Up Keyboard", systemImage: "keyboard")
                    }
                    Button {
                        showShortcutsGuide = true
                    } label: {
                        Label("Action Button, Back Tap & Siri", systemImage: "button.horizontal.top.press")
                    }
                    Button {
                        hasCompletedOnboarding = false
                    } label: {
                        Label("Show the Welcome Screens Again", systemImage: "sparkles")
                    }
                } footer: {
                    Text("Dictate into any app - Messages, Notes, anywhere you type - using the Nasar Flow keyboard, without switching apps yourself. Or start dictating from a physical button or Siri.")
                }

                Section {
                    ForEach(WhisperModelType.allCases) { model in
                        ModelStatusRow(
                            model: model,
                            state: viewModel.state(for: model),
                            approxSize: viewModel.approxSizeDescription(for: model),
                            primaryAction: { viewModel.primaryAction(for: model) },
                            deleteAction: { viewModel.delete(model) }
                        )
                    }
                } header: {
                    Text("Model Management")
                } footer: {
                    Text("Models are downloaded once and used fully offline afterwards.")
                }

                Section {
                    Toggle("Auto-stop when silent", isOn: $viewModel.autoStopOnSilence)

                    VStack(alignment: .leading) {
                        Text("Auto-stop sensitivity")
                        Slider(value: $viewModel.vadSensitivity, in: 0...1)
                    }
                    .disabled(!viewModel.autoStopOnSilence)
                    .foregroundStyle(viewModel.autoStopOnSilence ? .primary : .secondary)

                    Toggle("Auto-punctuation", isOn: $viewModel.autoPunctuation)

                    Picker("Cleanup", selection: $viewModel.cleanupLevel) {
                        ForEach(CleanupLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    Text(viewModel.cleanupLevel.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Stepper(
                        "Chunk length: \(viewModel.maxRecordDurationSeconds)s",
                        value: $viewModel.maxRecordDurationSeconds,
                        in: 10...60,
                        step: 5
                    )
                } header: {
                    Text("Recording Settings")
                } footer: {
                    Text("If recording keeps stopping itself before you finish speaking, turn off \"Auto-stop when silent\" - you'll just tap the record button again to stop manually instead.")
                }

                Section {
                    Toggle("Keep recent recordings", isOn: $viewModel.keepRecentAudio)
                } footer: {
                    Text("Keeps the audio of your last \(Constants.maxRecentUtterances) dictations on this phone - protected and excluded from backups - so any of them can be re-run with a different model from History, and a failed dictation is never lost. Turn off to keep nothing.")
                }

                Section("Data Management") {
                    LabeledContent("Storage Used", value: viewModel.storageUsedDescription)

                    ShareLink(item: HistoryViewModel.exportText(transcriptions)) {
                        Label("Export All Transcriptions", systemImage: "square.and.arrow.up")
                    }
                    .disabled(transcriptions.isEmpty)

                    Button("Clear All Transcriptions", role: .destructive) {
                        showClearAllConfirmation = true
                    }
                    .disabled(transcriptions.isEmpty)
                }

                Section {
                    ShareLink(item: DebugLogger.shared.fileURL) {
                        Label("Share Debug Log", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!hasDebugLog)

                    Button("Clear Debug Log", role: .destructive) {
                        Task {
                            await DebugLogger.shared.clear()
                            debugRefreshTrigger.toggle()
                        }
                    }
                    .disabled(!hasDebugLog)
                } header: {
                    Text("Debug Log")
                } footer: {
                    Text("A local, on-device log of recording/transcription/keyboard activity - nothing here is ever sent anywhere automatically. Share it if something breaks, so it can be diagnosed from real evidence instead of a description.")
                }

                Section {
                    if let latencySummary {
                        Text(latencySummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No dictations timed yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button("Clear Latency Stats", role: .destructive) {
                        LatencyLog.shared.clear()
                        debugRefreshTrigger.toggle()
                    }
                    .disabled(latencySummary == nil)
                } header: {
                    Text("Latency")
                } footer: {
                    Text("Median and 95th-percentile time per stage over the last \(LatencyLog.maxEntries) dictations: how long you spoke, the decode, the cleanup pass, and (keyboard dictations) the hand-off to the keyboard. On-device only.")
                }

                Section {
                    Toggle("Save Recordings", isOn: $viewModel.saveDebugAudio)

                    if let audioURL = latestDebugAudioURL {
                        ShareLink(item: audioURL) {
                            Label("Share Latest Recording", systemImage: "waveform")
                        }
                    } else {
                        Label("Share Latest Recording", systemImage: "waveform")
                            .foregroundStyle(.secondary)
                    }

                    Button("Clear Saved Recordings", role: .destructive) {
                        DebugAudioStore.clear()
                        debugRefreshTrigger.toggle()
                    }
                    .disabled(latestDebugAudioURL == nil)
                } header: {
                    Text("Debug Recordings")
                } footer: {
                    Text("Off by default. When on, keeps your last few recordings as audio files on-device (never uploaded) so a transcription problem can be checked against what you actually said, not just described. Turn this off again once you're done debugging.")
                }

                Section("About") {
                    LabeledContent("Version", value: Constants.appVersion)
                    Text("Built for Singapore's multilingual community.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear { debugRefreshTrigger.toggle() }
            .sheet(isPresented: $showKeyboardSetup) {
                KeyboardSetupView()
            }
            .sheet(isPresented: $showShortcutsGuide) {
                ShortcutsGuideView()
            }
            .confirmationDialog(
                "Delete all transcriptions? This can't be undone.",
                isPresented: $showClearAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    transcriptions.forEach(modelContext.delete)
                    try? modelContext.save()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
