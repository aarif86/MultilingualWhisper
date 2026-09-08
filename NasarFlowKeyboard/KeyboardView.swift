import SwiftUI

struct KeyboardView: View {
    // SwiftUI's own open-URL mechanism, not a UIKit call - see the comment on
    // `startFlowButton` for why this replaced two failed UIKit-level attempts.
    @Environment(\.openURL) private var openURL

    /// What this keyboard's main control should show - session state comes
    /// from FlowSessionState (shared with the main app via the App Group),
    /// computed by KeyboardViewController since it also needs to layer in a
    /// couple of local-only states (optimistic "just tapped, waiting for the
    /// app to confirm" and "waiting for a transcription result") that aren't
    /// worth persisting to shared state for.
    enum FlowUIState {
        case inactive
        case readyToListen
        case listening(elapsed: TimeInterval)
        case transcribing
        case failed
    }

    let hasFullAccess: Bool
    let pending: (text: String, date: Date)?
    let lastInsertedText: String?
    let flowState: FlowUIState
    let onStartListening: () -> Void
    let onStopListening: () -> Void
    let onInsert: (String) -> Void
    let onUndoInsert: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if !hasFullAccess {
                fullAccessNeeded
            } else {
                if let pending {
                    pendingResultRow(pending.text)
                } else if let lastInsertedText {
                    // Only shown once there's no new pending result waiting -
                    // a fresh dictation always takes priority over undoing
                    // the previous one.
                    undoInsertRow(lastInsertedText)
                }
                flowControl
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var flowControl: some View {
        switch flowState {
        case .inactive:
            startFlowButton
        case .readyToListen:
            listenButton
        case .listening(let elapsed):
            listeningButton(elapsed: elapsed)
        case .transcribing:
            transcribingView
        case .failed:
            failedButton
        }
    }

    // Two prior UIKit-level attempts (extensionContext.open, then walking the
    // responder chain to invoke UIApplication's openURL: dynamically) both
    // confirmed-on-device did nothing - no crash, no error, app never
    // foregrounded. SwiftUI's `\.openURL` environment action is a genuinely
    // different code path, not just another way to call the same restricted
    // UIKit API - it's the same mechanism that lets a `Link` open its
    // containing app from inside a WidgetKit widget, another context where
    // direct UIApplication calls don't work. Confirmed working on-device for
    // this exact call shape.
    private var startFlowButton: some View {
        VStack(spacing: 4) {
            Button {
                DebugLogger.shared.log("Start Flow tapped, opening \(DictationHandoff.startFlowURL) via SwiftUI openURL", category: "keyboard")
                openURL(DictationHandoff.startFlowURL)
            } label: {
                Label("Start Flow", systemImage: "waveform")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)

            Text("Turns on dictation for every app - open Nasar Flow once, then come back here")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var listenButton: some View {
        Button {
            onStartListening()
        } label: {
            Label("Tap to speak", systemImage: "mic.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
    }

    private func listeningButton(elapsed: TimeInterval) -> some View {
        Button {
            onStopListening()
        } label: {
            Label("Listening\u{2026} \(Int(elapsed))s - tap to stop", systemImage: "waveform")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private var transcribingView: some View {
        Label("Transcribing\u{2026}", systemImage: "ellipsis")
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    private var failedButton: some View {
        Button {
            onStartListening()
        } label: {
            Label("Couldn't transcribe that - tap to try again", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(.orange)
    }

    private func pendingResultRow(_ text: String) -> some View {
        Button {
            onInsert(text)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tap to insert")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func undoInsertRow(_ text: String) -> some View {
        Button(role: .destructive) {
            onUndoInsert()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Not what you said? Tap to remove")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(text)
                        .font(.subheadline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var fullAccessNeeded: some View {
        VStack(spacing: 6) {
            Text("Enable Full Access")
                .font(.headline)
            Text("Settings > Keyboard > Keyboards > Nasar Flow > Allow Full Access - needed so this keyboard can open the app to dictate.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Inactive") {
    KeyboardView(
        hasFullAccess: true,
        pending: nil,
        lastInsertedText: nil,
        flowState: .inactive,
        onStartListening: {},
        onStopListening: {},
        onInsert: { _ in },
        onUndoInsert: {}
    )
    .frame(height: 216)
}

#Preview("Listening") {
    KeyboardView(
        hasFullAccess: true,
        pending: nil,
        lastInsertedText: nil,
        flowState: .listening(elapsed: 4),
        onStartListening: {},
        onStopListening: {},
        onInsert: { _ in },
        onUndoInsert: {}
    )
    .frame(height: 216)
}

#Preview("Pending result") {
    KeyboardView(
        hasFullAccess: true,
        pending: (text: "Bismillah, let's go makan lah", date: Date()),
        lastInsertedText: nil,
        flowState: .readyToListen,
        onStartListening: {},
        onStopListening: {},
        onInsert: { _ in },
        onUndoInsert: {}
    )
    .frame(height: 216)
}

#Preview("After insert") {
    KeyboardView(
        hasFullAccess: true,
        pending: nil,
        lastInsertedText: "Bismillah, let's go makan lah",
        flowState: .readyToListen,
        onStartListening: {},
        onStopListening: {},
        onInsert: { _ in },
        onUndoInsert: {}
    )
    .frame(height: 216)
}
