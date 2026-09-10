import AVFoundation
import SwiftUI

/// Three screens on first launch, and nothing the app cannot explain honestly:
/// the microphone and why it is safe, one model download named by what it is for,
/// and the keyboard with the "why Full Access" line. Modelled on the parts of
/// Wispr / Willow / Dragon onboarding the playbook keeps (§3.1, §3.9): explain
/// every permission in one line, warn against dictating secrets (Monologue), and
/// tell new users the first few dictations are an adaptation phase (Dragon).
///
/// Skippable at every step - `hasCompletedOnboarding` is set when the last page is
/// dismissed or "Skip" is tapped, and never shown again. Existing installs with a
/// model already downloaded skip it entirely (see `MultilingualWhisperApp`).
struct OnboardingView: View {
    static let completedKey = "hasCompletedOnboarding"

    @Environment(\.dismiss) private var dismiss
    let modelDownloadService: ModelDownloadService
    let onFinish: () -> Void

    @State private var page = 0
    @State private var microphoneStatus = AVAudioApplication.shared.recordPermission
    @State private var showKeyboardSetup = false

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { finish() }
                    .font(.subheadline)
                    .padding()
                    .accessibilityIdentifier("onboarding.skip")
            }

            TabView(selection: $page) {
                microphonePage.tag(0)
                modelPage.tag(1)
                keyboardPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page == pageCount - 1 ? "Start dictating" : "Continue") {
                if page < pageCount - 1 {
                    withAnimation { page += 1 }
                } else {
                    finish()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            .accessibilityIdentifier("onboarding.continue")
        }
        .sheet(isPresented: $showKeyboardSetup) {
            KeyboardSetupView()
        }
    }

    private func finish() {
        onFinish()
        dismiss()
    }

    // MARK: - Page 1: microphone and privacy

    private var microphonePage: some View {
        page(
            symbol: "mic.fill",
            title: "Welcome to Nasar Flow",
            subtitle: "Speak Singlish, Malay and Arabic in one sentence. Nothing you say ever leaves your phone."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                permissionRow(
                    symbol: "mic",
                    title: "Microphone",
                    detail: "Only on while you are dictating, and recognition runs entirely on this phone - no account, no server, nothing to upload."
                )
                permissionRow(
                    symbol: "keyboard",
                    title: "Keyboard Full Access (later)",
                    detail: "Lets the keyboard open this app to listen. The keyboard itself cannot hear you - iOS does not allow any keyboard to."
                )
                permissionRow(
                    symbol: "lock.slash",
                    title: "One thing to avoid",
                    detail: "Don't dictate passwords or card numbers. Transcripts are saved in History on this phone, and each one sits on your clipboard for two minutes."
                )

                switch microphoneStatus {
                case .granted:
                    Label("Microphone allowed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                case .denied:
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Microphone access is off", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                default:
                    Button {
                        Task {
                            _ = await withCheckedContinuation { continuation in
                                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
                            }
                            microphoneStatus = AVAudioApplication.shared.recordPermission
                        }
                    } label: {
                        Label("Allow the microphone", systemImage: "mic.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("onboarding.allowMicrophone")
                }
            }
        }
    }

    // MARK: - Page 2: one model, named by what it is for

    private var modelPage: some View {
        page(
            symbol: "arrow.down.circle",
            title: "Pick your starting model",
            subtitle: "One download, then it works with no signal at all. You can add the others any time in Settings."
        ) {
            VStack(spacing: 10) {
                modelChoice(.singlish, name: "Singapore", detail: "Singlish, English and mixed-in Malay - the broadest net, and the default for Auto-Detect.")
                modelChoice(.malay, name: "Malaysia", detail: "Everyday Bahasa, including Manglish. Auto-Detect switches to it when a whole dictation is Malay.")
                modelChoice(.arabic, name: "Arabic", detail: "Colloquial Arabic, not just Modern Standard. Picked automatically when you speak Arabic.")

                Text("The first few dictations are an adaptation phase for both of you - speak the way you would to a friend, and teach the Custom Dictionary any name it keeps getting wrong.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
        }
    }

    private func modelChoice(_ model: WhisperModelType, name: String, detail: String) -> some View {
        let state = modelDownloadService.states[model] ?? .notDownloaded
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name).font(.headline)
                    Text(ByteCountFormatter.string(fromByteCount: model.approxSizeBytes, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if case .downloading(let progress) = state {
                    ProgressView(value: progress)
                } else if case .failed(let message) = state {
                    Text(message).font(.caption2).foregroundStyle(.red)
                }
            }
            Spacer(minLength: 0)
            switch state {
            case .downloaded:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .downloading:
                Button("Pause") { modelDownloadService.pauseDownload(model) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            case .verifying:
                ProgressView()
            case .paused:
                Button("Resume") { modelDownloadService.startDownload(model) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            case .notDownloaded, .failed:
                Button("Get") { modelDownloadService.startDownload(model) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("onboarding.download.\(model.rawValue)")
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    // MARK: - Page 3: the keyboard

    private var keyboardPage: some View {
        page(
            symbol: "keyboard",
            title: "Dictate in every app",
            subtitle: "Add the Nasar Flow keyboard once and the mic is on every keyboard - Messages, WhatsApp, Notes, Mail."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                permissionRow(
                    symbol: "1.circle",
                    title: "Settings > General > Keyboard > Keyboards",
                    detail: "Add New Keyboard, pick Nasar Flow, then tap it again and turn on Allow Full Access."
                )
                permissionRow(
                    symbol: "questionmark.circle",
                    title: "Why Full Access?",
                    detail: "Only so the keyboard can hand off to this app, which does the listening. The keyboard never sees your audio and never sends anything anywhere."
                )
                permissionRow(
                    symbol: "hand.tap",
                    title: "Then, in any app",
                    detail: "Hold the globe key, pick Nasar Flow, tap Start Flow once. After that, tap the mic to speak and long-press it for commands like \u{201C}new line\u{201D} or \u{201C}delete that\u{201D}."
                )
                Button {
                    showKeyboardSetup = true
                } label: {
                    Label("Show me the steps", systemImage: "list.number")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Building blocks

    private func page<Content: View>(symbol: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                    .padding(.top, 8)
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                content()
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func permissionRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    OnboardingView(modelDownloadService: ModelDownloadService(), onFinish: {})
}
