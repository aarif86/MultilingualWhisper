import SwiftData
import SwiftUI

/// Shown full-screen when the app is launched via the keyboard extension's
/// "Dictate" button (nasarflow://dictate) instead of opened normally. Starts
/// recording immediately - the whole reason the user is here is to dictate -
/// and once done, hands the result to DictationHandoff for the keyboard to
/// offer, plus copies it to the clipboard as a universal fallback.
struct QuickDictateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: QuickDictateViewModel
    @State private var hasStarted = false

    init(audioService: AudioService, whisperService: WhisperService) {
        _viewModel = State(initialValue: QuickDictateViewModel(audioService: audioService, whisperService: whisperService))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if viewModel.didPublish {
                    doneView
                } else {
                    recordingView
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Quick Dictate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true
                viewModel.start(modelContext: modelContext)
            }
            .onChange(of: viewModel.transcription.phase) { _, _ in
                viewModel.publishIfFinished()
            }
        }
    }

    private var recordingView: some View {
        VStack(spacing: 16) {
            RecordButton(
                isRecording: viewModel.transcription.isRecording,
                level: viewModel.transcription.recordingLevel
            ) {
                viewModel.transcription.toggleRecording(modelContext: modelContext)
            }
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        switch viewModel.transcription.phase {
        case .recording: return "Listening… tap to stop"
        case .transcribing: return "Transcribing…"
        case .error(let message): return message
        case .idle: return "Tap to start dictating"
        }
    }

    private var doneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text(viewModel.transcription.transcript)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))

            VStack(spacing: 4) {
                Text("Saved and ready to insert")
                    .font(.subheadline.weight(.medium))
                Text("Swipe right along the bottom edge (or tap \u{2039} Back at the top) to jump straight back to what you were typing - no need to tap Done first. Then tap the ready text on your Nasar Flow keyboard to insert it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }
}
