import SwiftUI

/// Shown once, right after activating a Flow session from the keyboard's
/// "Start" button (or the in-app toggle in Settings) - mirrors Wispr Flow's
/// own "Flow is on" screen. Unlike QuickDictateView, this does NOT record
/// anything itself - its only job is confirming the session is live and
/// telling the user how to get back to what they were doing, since there's
/// still no supported way for the app to do that automatically (see project
/// memory on the swipe-gesture claim that didn't hold up on a real device -
/// deliberately not repeating that specific claim here).
struct FlowActivationView: View {
    @Environment(\.dismiss) private var dismiss
    let flowSession: FlowSessionEngine

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: flowSession.isActive ? "waveform.circle.fill" : "waveform.circle")
                .font(.system(size: 64))
                .foregroundStyle(flowSession.isActive ? .green : .secondary)

            Text(flowSession.isActive ? "Flow is on" : "Turning Flow on\u{2026}")
                .font(.title2.bold())

            if flowSession.isActive {
                Text("Dictate straight from the Nasar Flow keyboard now - no need to open this app again until you turn Flow off in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else if let error = flowSession.lastError {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            if flowSession.isActive {
                Text("Switch back to where you were (app switcher or Home) - the keyboard will be listening for you there.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 24)
        }
        .task {
            if !flowSession.isActive {
                await flowSession.activate()
            }
        }
    }
}

#Preview {
    FlowActivationView(flowSession: FlowSessionEngine(
        whisperService: WhisperService(modelStore: ModelDownloadService()),
        modelContainer: PersistenceService.makeModelContainer()
    ))
}
