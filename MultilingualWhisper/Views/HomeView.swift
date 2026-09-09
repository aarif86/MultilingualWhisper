import SwiftData
import SwiftUI

/// Home now does what Willow/Wispr Flow's own home screens do: a Flow
/// on/off switch you can reach without digging into Settings, plus your
/// transcripts right below it - not a separate "History" tab. The manual
/// record button (this app's own original recording flow, predating Flow
/// sessions) stays above the transcript feed rather than being dropped,
/// since it's still the only way to dictate for someone not using the
/// keyboard.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transcription.date, order: .reverse) private var transcriptions: [Transcription]
    @State private var viewModel: TranscriptionViewModel
    @State private var historyViewModel = HistoryViewModel()
    @State private var showCopiedConfirmation = false
    @State private var showDeleteAllConfirmation = false
    @State private var showKeyboardSetup = false
    // Survives relaunches on purpose - once dismissed (or once Flow's been
    // turned on for real), there's no reason to keep asking.
    @AppStorage("hasSeenKeyboardSetupNudge") private var hasSeenKeyboardSetupNudge = false
    let flowSession: FlowSessionEngine
    // Stateless - see HistoryView's identical property for why this is
    // recomputed from saved text at display time instead of persisted.
    private let classifier = RuleBasedLanguageClassifier()

    init(audioService: AudioService, whisperService: WhisperService, flowSession: FlowSessionEngine) {
        _viewModel = State(initialValue: TranscriptionViewModel(audioService: audioService, whisperService: whisperService))
        self.flowSession = flowSession
    }

    /// Turning it on is async (mic permission + starting the continuous
    /// engine), but Toggle needs a plain Binding<Bool> - fire the async work
    /// and let flowSession.isActive (an @Observable property) drive the
    /// toggle's actual displayed state once it resolves, rather than
    /// assuming success immediately.
    private var flowToggleBinding: Binding<Bool> {
        Binding(
            get: { flowSession.isActive },
            set: { newValue in
                if newValue {
                    Task { await flowSession.activate() }
                } else {
                    flowSession.end()
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    topContent
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)

                let filtered = historyViewModel.filtered(transcriptions)
                ForEach(historyViewModel.grouped(filtered), id: \.label) { section in
                    Section(section.label) {
                        ForEach(section.items) { transcription in
                            row(for: transcription)
                        }
                    }
                }

                if transcriptions.isEmpty {
                    ContentUnavailableView(
                        "No transcriptions yet",
                        systemImage: "waveform",
                        description: Text("Recordings you transcribe will show up here.")
                    )
                    .listRowSeparator(.hidden)
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: historyViewModel.searchText)
                        .listRowSeparator(.hidden)
                }
            }
            .searchable(text: $historyViewModel.searchText, prompt: "Search transcriptions")
            .navigationTitle(Constants.appName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle("Flow", isOn: flowToggleBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarMenu
                }
            }
            .alert("Something went wrong", isPresented: errorBinding, presenting: errorMessage) { _ in
                if viewModel.microphonePermissionDenied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                        viewModel.dismissError()
                    }
                }
                Button("OK", role: .cancel) { viewModel.dismissError() }
            } message: { message in
                Text(message)
            }
            .alert("Copied to clipboard", isPresented: $showCopiedConfirmation) {
                Button("OK", role: .cancel) {}
            }
            .sheet(isPresented: $showKeyboardSetup) {
                KeyboardSetupView()
            }
            .confirmationDialog(
                "Delete all transcriptions? This can't be undone.",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    historyViewModel.deleteAll(transcriptions, context: modelContext)
                }
                Button("Cancel", role: .cancel) {}
            }
            .onChange(of: flowSession.isActive) { _, isActive in
                if isActive { hasSeenKeyboardSetupNudge = true }
            }
        }
    }

    // MARK: - Top section (record controls + Flow status)

    @ViewBuilder
    private var topContent: some View {
        VStack(spacing: Constants.standardPadding) {
            if !hasSeenKeyboardSetupNudge {
                keyboardSetupNudge
            }

            statsChip

            if flowSession.isRecording {
                Label("Flow is listening\u{2026}", systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if let error = flowSession.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            modeBanner
            transcriptCard
            actionButtons

            RecordButton(isRecording: viewModel.isRecording, level: viewModel.recordingLevel) {
                viewModel.toggleRecording(modelContext: modelContext)
            }
            .frame(maxWidth: .infinity)

            if viewModel.isRecording {
                Text(elapsedLabel)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            Button {
                viewModel.cycleLanguageMode()
            } label: {
                Label(viewModel.languageModeLabel, systemImage: "globe")
                    .font(.footnote)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isRecording || viewModel.phase == .transcribing)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }

    private var keyboardSetupNudge: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Turn on dictation everywhere")
                    .font(.headline)
                Spacer()
                Button {
                    hasSeenKeyboardSetupNudge = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Text("Set up the Nasar Flow keyboard once, then dictate straight into Messages, Notes, or any app - no need to open Nasar Flow first.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Set Up Keyboard") {
                showKeyboardSetup = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    private var statsChip: some View {
        HStack(spacing: 0) {
            statTile(value: "\(historyViewModel.wordsToday(transcriptions))", label: "words today")
            Divider().frame(height: 28)
            statTile(value: "\(historyViewModel.streak(transcriptions))d", label: "streak")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var modeBanner: some View {
        HStack {
            Image(systemName: modeIcon)
            Text(bannerText)
                .font(.subheadline)
            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    private var bannerText: String {
        switch viewModel.phase {
        case .recording: return "Listening…"
        case .transcribing: return "Transcribing…"
        case .idle, .error: return "Model: \(viewModel.languageModeLabel)"
        }
    }

    private var modeIcon: String {
        switch viewModel.phase {
        case .recording: return "waveform"
        case .transcribing: return "gearshape.2"
        case .idle, .error: return "globe"
        }
    }

    private var transcriptCard: some View {
        // No inner ScrollView here (the pre-Home version of this card had
        // one) - this row now lives inside Home's own List/ScrollView, and a
        // scrollable view nested inside another fights it for vertical drag
        // gestures. Letting the row grow to fit the text instead, capped at
        // a generous line limit, avoids that entirely.
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.transcript.isEmpty ? "Tap the record button and start speaking." : viewModel.transcript)
                .font(.body)
                .foregroundStyle(viewModel.transcript.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(10)
                .textSelection(.enabled)

            HStack {
                if let tag = viewModel.lastLanguageTag {
                    LanguageBadge(language: tag, components: viewModel.lastLanguageComponents)
                }
                Text("\(viewModel.wordCount) words · \(Int(viewModel.lastDuration))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    private var actionButtons: some View {
        HStack(spacing: Constants.standardPadding) {
            Button {
                UIPasteboard.general.string = viewModel.transcript
                showCopiedConfirmation = true
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(viewModel.transcript.isEmpty)

            ShareLink(item: viewModel.transcript) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.transcript.isEmpty)

            Button(role: .destructive) {
                viewModel.clearTranscript()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(viewModel.transcript.isEmpty)
        }
        .buttonStyle(.bordered)
        .labelStyle(.iconOnly)
        .font(.title3)
        .frame(maxWidth: .infinity)
    }

    private var elapsedLabel: String {
        let seconds = Int(viewModel.recordingElapsed)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: {
                if case .error = viewModel.phase { return true }
                return false
            },
            set: { isPresented in if !isPresented { viewModel.dismissError() } }
        )
    }

    private var errorMessage: String? {
        if case .error(let message) = viewModel.phase { return message }
        return nil
    }

    // MARK: - Transcript feed (formerly the standalone History tab)

    private var toolbarMenu: some View {
        Menu {
            Picker("Language", selection: $historyViewModel.languageFilter) {
                Text("All Languages").tag(LanguageType?.none)
                ForEach(LanguageType.allCases) { language in
                    Text(language.rawValue).tag(Optional(language))
                }
            }

            ShareLink(item: HistoryViewModel.exportText(transcriptions)) {
                Label("Export All", systemImage: "square.and.arrow.up")
            }
            .disabled(transcriptions.isEmpty)

            Button(role: .destructive) {
                showDeleteAllConfirmation = true
            } label: {
                Label("Delete All", systemImage: "trash")
            }
            .disabled(transcriptions.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func languageComponents(for transcription: Transcription) -> [LanguageType] {
        classifier.classify(text: transcription.text).components
    }

    private func row(for transcription: Transcription) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(transcription.text)
                .lineLimit(3)

            HStack(spacing: 6) {
                Text(transcription.date, format: .dateTime.hour().minute())
                Text("· \(Int(transcription.duration))s ·")
                LanguageBadge(language: transcription.languageUsed, components: languageComponents(for: transcription))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .swipeActions {
            Button("Delete", role: .destructive) {
                historyViewModel.delete(transcription, context: modelContext)
            }
        }
        .contextMenu {
            Button {
                UIPasteboard.general.string = transcription.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            ShareLink(item: transcription.text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                historyViewModel.delete(transcription, context: modelContext)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
