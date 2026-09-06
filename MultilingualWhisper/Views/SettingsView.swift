import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transcriptions: [Transcription]
    @State private var viewModel: SettingsViewModel
    @State private var showClearAllConfirmation = false
    // Toggled after clearing the debug log to force `hasDebugLog` to
    // re-evaluate - SwiftUI has no other reason to know the file on disk changed.
    @State private var debugLogRefreshTrigger = false

    private var hasDebugLog: Bool {
        _ = debugLogRefreshTrigger
        return FileManager.default.fileExists(atPath: DebugLogger.shared.fileURL.path)
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
                            debugLogRefreshTrigger.toggle()
                        }
                    }
                    .disabled(!hasDebugLog)
                } header: {
                    Text("Debug Log")
                } footer: {
                    Text("A local, on-device log of recording/transcription activity - nothing here is ever sent anywhere automatically. Share it if something breaks, so it can be diagnosed from real evidence instead of a description.")
                }

                Section("About") {
                    LabeledContent("Version", value: Constants.appVersion)
                    Text("Built for Singapore's multilingual community.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
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
