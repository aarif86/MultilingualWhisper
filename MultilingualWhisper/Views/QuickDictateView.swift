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

            // Was more specific here about a swipe gesture to jump straight
            // back - pulled that claim after a real device test showed no
            // such affordance actually appears for this app-extension-
            // triggered flow, so don't reintroduce it without new evidence.
            VStack(spacing: 4) {
                Text("Saved and ready to insert")
                    .font(.subheadline.weight(.medium))
                Text("No need to tap Done first - switch back to where you were typing (app switcher works fine) and the Nasar Flow keyboard types it in as soon as it appears. It's also on your clipboard for the next \(Int(ClipboardFallback.lifetime / 60)) minutes, in case you want to paste it somewhere else.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Brand.goldSolid)
        }
    }
}
