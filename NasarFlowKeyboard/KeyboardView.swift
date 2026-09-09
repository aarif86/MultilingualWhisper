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
    let lastInsertedText: String?
    /// A spelling fix the user made by hand to the last insert, offered for the
    /// Custom Dictionary - see CorrectionLearner.
    let suggestedCorrection: CorrectionLearner.Correction?
    /// A command-mode utterance the app could not match to any command.
    let unrecognizedCommand: String?
    let flowState: FlowUIState
    let onStartListening: () -> Void
    /// Long-press on the mic: the next utterance is a VoiceCommand.
    let onStartCommand: () -> Void
    let onInsertUnrecognized: () -> Void
    let onDismissUnrecognized: () -> Void
    let onStopListening: () -> Void
    let onUndoInsert: () -> Void
    let onLearnCorrection: () -> Void
    let onDismissCorrection: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if !hasFullAccess {
                fullAccessNeeded
            } else {
                // A finished dictation is inserted the instant it's ready
                // (see KeyboardViewController.autoInsertPendingResult) - this
                // row is the confirmation of what just got typed, and the
                // one-tap fix if it heard you wrong.
                if let unrecognizedCommand {
                    unrecognizedRow(unrecognizedCommand)
                } else if let suggestedCorrection {
                    learnRow(suggestedCorrection)
                } else if let lastInsertedText {
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

            Text(recentlyTimedOut
                 ? "Flow turned itself off after a while without dictation - start it again when you need it"
                 : "Turns on dictation for every app - open Nasar Flow once, then come back here")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var listenButton: some View {
        VStack(spacing: 4) {
            Button {
                onStartListening()
            } label: {
                Label("Tap to speak", systemImage: "mic.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            // Long-press = command mode. Kept on the same control so the
            // boundary between "dictate" and "command" is the gesture itself,
            // never a guess about the words (see VoiceCommand).
            .highPriorityGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in onStartCommand() })

            if let minutes = minutesUntilIdleTimeout {
                Text("Flow turns off in \(minutes) min if unused - tap to speak keeps it on")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Hold for a command: new line, delete that, full stop\u{2026}")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// The app heard a command-mode utterance but matched no command. Say what it
    /// heard and let the user decide - insert it as text, or drop it.
    private func unrecognizedRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Not a command I know")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\u{201C}\(text)\u{201D}")
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
            Button("Insert") { onInsertUnrecognized() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button {
                onDismissUnrecognized()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Dismiss")
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Idle timeout hints (read straight from the shared state; the
    // controller re-creates this view on every tick, so they stay current)

    /// Minutes left before the app ends the session for inactivity, only once
    /// that is close enough to be worth saying (five minutes or less).
    private var minutesUntilIdleTimeout: Int? {
        guard let deadline = FlowSessionState.idleDeadline else { return nil }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0, remaining <= 5 * 60 else { return nil }
        return max(1, Int((remaining / 60).rounded(.up)))
    }

    private var recentlyTimedOut: Bool {
        guard let at = FlowSessionState.lastIdleTimeoutAt else { return false }
        return Date().timeIntervalSince(at) < 10 * 60
    }

    private func listeningButton(elapsed: TimeInterval) -> some View {
        Button {
            onStopListening()
        } label: {
            // "stop.fill" - the same icon RecordButton already uses for its
            // own in-progress-recording state, not "waveform" (which reads as
            // a passive "it's on" indicator rather than a control you can
            // tap to stop).
            Label(
                FlowSessionState.utteranceIsCommand
                    ? "Say a command\u{2026} \(Int(elapsed))s - tap to stop"
                    : "Listening\u{2026} \(Int(elapsed))s - tap to stop",
                systemImage: "stop.fill"
            )
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

    /// Wispr Flow's "Add to Dictionary" pill, triggered by what the user actually
    /// fixed rather than by a settings screen. One tap teaches the app; the
    /// dictionary applies it to every future dictation.
    private func learnRow(_ correction: CorrectionLearner.Correction) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "text.book.closed")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Teach Nasar Flow this spelling?")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(correction.heard) → \(correction.corrected)")
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
            Button("Add") { onLearnCorrection() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Button {
                onDismissCorrection()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Not now")
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
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
        lastInsertedText: nil,
        suggestedCorrection: nil,
        unrecognizedCommand: nil,
        flowState: .inactive,
        onStartListening: {},
        onStartCommand: {},
        onInsertUnrecognized: {},
        onDismissUnrecognized: {},
        onStopListening: {},
        onUndoInsert: {},
        onLearnCorrection: {},
        onDismissCorrection: {}
    )
    .frame(height: 216)
}

#Preview("Listening") {
    KeyboardView(
        hasFullAccess: true,
        lastInsertedText: nil,
        suggestedCorrection: nil,
        unrecognizedCommand: nil,
        flowState: .listening(elapsed: 4),
        onStartListening: {},
        onStartCommand: {},
        onInsertUnrecognized: {},
        onDismissUnrecognized: {},
        onStopListening: {},
        onUndoInsert: {},
        onLearnCorrection: {},
        onDismissCorrection: {}
    )
    .frame(height: 216)
}

#Preview("After insert") {
    KeyboardView(
        hasFullAccess: true,
        lastInsertedText: "Bismillah, let's go makan lah",
        suggestedCorrection: nil,
        unrecognizedCommand: nil,
        flowState: .readyToListen,
        onStartListening: {},
        onStartCommand: {},
        onInsertUnrecognized: {},
        onDismissUnrecognized: {},
        onStopListening: {},
        onUndoInsert: {},
        onLearnCorrection: {},
        onDismissCorrection: {}
    )
    .frame(height: 216)
}
