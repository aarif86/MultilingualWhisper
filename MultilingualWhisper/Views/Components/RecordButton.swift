import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let level: Float
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Brand.terracottaGradient : Brand.goldGradient)
                    .frame(width: Constants.recordButtonSize, height: Constants.recordButtonSize)
                    .shadow(color: (isRecording ? Brand.terracotta : Brand.gold).opacity(0.45), radius: 16, y: 8)
                    .overlay(
                        Circle()
                            .strokeBorder((isRecording ? Brand.terracotta : Brand.gold).opacity(0.16), lineWidth: 9)
                            .frame(width: Constants.recordButtonSize + 18, height: Constants.recordButtonSize + 18)
                    )
                    .scaleEffect(isRecording ? 1 + CGFloat(level) * 0.12 : 1)

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.1), value: level)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }
}

#Preview("Idle") {
    RecordButton(isRecording: false, level: 0) {}
}

#Preview("Recording") {
    RecordButton(isRecording: true, level: 0.6) {}
}
