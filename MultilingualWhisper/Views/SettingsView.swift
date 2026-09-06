import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transcriptions: [Transcription]
    @State private var viewModel: SettingsViewModel
    @State private var showClearAllConfirmation = false

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
