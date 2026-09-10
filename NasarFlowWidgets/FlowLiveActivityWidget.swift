import ActivityKit
import SwiftUI
import WidgetKit

/// "Flow is on" while the background microphone session runs - see
/// `FlowActivityAttributes`. The Dynamic Island shows a waveform the whole time
/// (red while an utterance is being captured), the expanded view and the Lock
/// Screen banner carry a live timer and the one-tap **Off** button.
struct FlowLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlowActivityAttributes.self) { context in
            // Lock Screen and banner.
            HStack(spacing: 12) {
                statusIcon(context.state)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.isRecording ? "Listening\u{2026}" : "Flow is on")
                        .font(.headline)
                    Text(context.state.isRecording
                         ? "Say it, then pause - the keyboard types it in."
                         : "Tap the mic on the Nasar Flow keyboard to dictate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(context.state.since, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 60)
                    offButton
                }
            }
            .padding(14)
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        statusIcon(context.state)
                        Text(context.state.isRecording ? "Listening" : "Flow on")
                            .font(.headline)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    offButton
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.isRecording
                             ? "Say it, then pause - it types itself."
                             : "Mic is open for the Nasar Flow keyboard.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(context.state.since, style: .timer)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 52)
                    }
                }
            } compactLeading: {
                statusIcon(context.state)
            } compactTrailing: {
                Text(context.state.since, style: .timer)
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: 40)
            } minimal: {
                statusIcon(context.state)
            }
        }
    }

    private func statusIcon(_ state: FlowActivityAttributes.ContentState) -> some View {
        Image(systemName: state.isRecording ? "waveform" : "waveform.circle.fill")
            .foregroundStyle(state.isRecording ? Color.red : Color.green)
            .symbolEffect(.variableColor, isActive: state.isRecording)
    }

    private var offButton: some View {
        Button(intent: StopFlowLiveActivityIntent()) {
            Label("Off", systemImage: "power")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }
}
