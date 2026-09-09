import AppIntents

/// "Dictate with Nasar Flow" - the entry point every competitor keyboard exposes
/// (Wispr Flow: Action Button, Back Tap, Control Center, Siri phrases; see
/// `docs/competitor-kb/mobile-keyboards.md`). Assign it to the Action Button
/// (Settings → Action Button → Shortcut), Back Tap (Settings → Accessibility →
/// Touch → Back Tap), or say the phrase to Siri.
///
/// Opens the app because iOS only lets an app that is in the foreground start the
/// microphone, and Quick Dictate is a screen. The transcript lands on the clipboard
/// and in the keyboard's "Tap to insert" row, exactly as it does from the keyboard.
struct DictateIntent: AppIntent {
    static var title: LocalizedStringResource = "Dictate"
    static var description = IntentDescription(
        "Opens Nasar Flow and starts listening straight away. The transcript is copied to your clipboard and ready for the keyboard's Insert button."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentRouter.shared.request(.dictate)
        return .result()
    }
}

/// Starts a Flow session - the background microphone session the keyboard's
/// mic button talks to - without hunting for the toggle in the app.
struct StartFlowIntent: AppIntent {
    static var title: LocalizedStringResource = "Turn On Flow"
    static var description = IntentDescription(
        "Starts a Flow session so the Nasar Flow keyboard can dictate into any app. The microphone stays on until you turn Flow off."
    )
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentRouter.shared.request(.startFlow)
        return .result()
    }
}

/// Ends the Flow session and releases the microphone.
struct StopFlowIntent: AppIntent {
    static var title: LocalizedStringResource = "Turn Off Flow"
    static var description = IntentDescription("Ends the Flow session and turns the microphone off.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentRouter.shared.request(.stopFlow)
        return .result()
    }
}

/// Registers the intents with Shortcuts and Siri on install, with the phrases
/// users say. Every phrase must contain the app name; Siri matches loosely.
struct NasarFlowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DictateIntent(),
            phrases: [
                "Dictate with \(.applicationName)",
                "Start dictating with \(.applicationName)",
                "Quick dictate with \(.applicationName)",
                "Dictate to clipboard with \(.applicationName)",
            ],
            shortTitle: "Dictate",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StartFlowIntent(),
            phrases: [
                "Turn on Flow in \(.applicationName)",
                "Start Flow in \(.applicationName)",
                "Turn on \(.applicationName)",
            ],
            shortTitle: "Turn On Flow",
            systemImageName: "waveform"
        )
        AppShortcut(
            intent: StopFlowIntent(),
            phrases: [
                "Turn off Flow in \(.applicationName)",
                "Stop Flow in \(.applicationName)",
                "Turn off \(.applicationName)",
            ],
            shortTitle: "Turn Off Flow",
            systemImageName: "waveform.slash"
        )
    }
}
