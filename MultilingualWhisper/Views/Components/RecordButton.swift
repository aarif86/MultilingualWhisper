import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let level: Float
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.accentColor)
                    .frame(width: Constants.recordButtonSize, height: Constants.recordButtonSize)
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
