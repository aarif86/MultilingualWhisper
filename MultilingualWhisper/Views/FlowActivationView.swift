import SwiftUI

/// Shown once, right after activating a Flow session from the keyboard's
/// "Start" button (or the in-app toggle in Settings) - mirrors Wispr Flow's
/// own "Flow is on" screen. Unlike QuickDictateView, this does NOT record
/// anything itself - its only job is confirming the session is live and
/// showing how to get back to what they were doing, since there's still no
/// supported way for the app to do that automatically. Deliberately teaches
/// the general "swipe along the bottom edge to cycle to the most recently
/// used app" system gesture here (see SwipeGestureIllustration) rather than
/// the app-specific "\u{2039} Back to App" pill claimed earlier in
/// QuickDictateView's history, which didn't hold up on a real device for
/// that extension-triggered flow - the general gesture doesn't depend on how
/// Nasar Flow was opened, so it isn't resting on the same unverified ground.
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
                VStack(spacing: 10) {
                    SwipeGestureIllustration()
                    Text("Swipe right along the very bottom edge to jump back - faster than the app switcher.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
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

/// A general iOS system gesture (cycle to the most-recently-used app), not
/// tied to how Nasar Flow itself was opened - unlike the "\u{2039} Back to App"
/// pill this app can't reliably promise (see the earlier, retracted claim
/// about that in QuickDictateView's history), this one works regardless.
/// Modeled on Wispr Flow's own onboarding illustration for the same gesture.
private struct SwipeGestureIllustration: View {
    @State private var slid = false

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 30)
                .strokeBorder(.secondary, lineWidth: 3)

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.15))
                .padding(.horizontal, 14)
                .padding(.bottom, 28)
                .frame(height: 80)

            Capsule()
                .fill(.secondary)
                .frame(width: 46, height: 5)
                .padding(.bottom, 10)

            Circle()
                .fill(Color.accentColor)
                .frame(width: 24, height: 24)
                .shadow(radius: 2)
                .offset(x: slid ? 32 : -32, y: -8)
        }
        .frame(width: 110, height: 190)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                slid = true
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
