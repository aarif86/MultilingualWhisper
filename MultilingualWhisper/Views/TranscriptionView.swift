import SwiftData
import SwiftUI

struct TranscriptionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TranscriptionViewModel
    @State private var showCopiedConfirmation = false

    init(audioService: AudioService, whisperService: WhisperService) {
        _viewModel = State(initialValue: TranscriptionViewModel(audioService: audioService, whisperService: whisperService))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.standardPadding) {
                modeBanner
                transcriptCard
                actionButtons

                Spacer(minLength: 0)

                RecordButton(isRecording: viewModel.isRecording, level: viewModel.recordingLevel) {
                    viewModel.toggleRecording(modelContext: modelContext)
                }

                if viewModel.isRecording {
                    Text(elapsedLabel)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.cycleLanguageMode()
                } label: {
                    Label(viewModel.languageModeLabel, systemImage: "globe")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRecording || viewModel.phase == .transcribing)
            }
            .padding()
            .navigationTitle(Constants.appName)
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
        }
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
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                Text(viewModel.transcript.isEmpty ? "Tap the record button and start speaking." : viewModel.transcript)
                    .font(.body)
                    .foregroundStyle(viewModel.transcript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}
