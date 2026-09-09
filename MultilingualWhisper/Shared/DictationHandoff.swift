import Foundation

/// Hand-off point between the main app and the keyboard extension, via an App
/// Group shared container.
///
/// The keyboard can't record audio itself - Apple blocks microphone access from
/// keyboard extensions entirely, even with Full Access granted, for privacy
/// reasons (a malicious keyboard could otherwise silently record everything
/// typed *and* said). So the keyboard opens the main app to do the actual
/// recording/transcription, and the main app drops the result here for the
/// keyboard to offer once the user switches back to whatever they were doing.
enum DictationHandoff {
    /// Must match the App Group capability enabled on BOTH targets (see
    /// project.yml's `entitlements:` blocks) and registered as an actual App
    /// Group in the Apple Developer portal - this is just a string constant,
    /// registering the capability is a manual portal step, see README.
    static let appGroupID = "group.com.multilingualwhisper.app"

    /// Custom URL scheme the keyboard extension uses to launch the main app -
    /// registered in the main app's Info.plist via CFBundleURLTypes.
    static let urlScheme = "nasarflow"
    static let dictateHost = "dictate"
    /// Launches the "Flow is on" activation screen (FlowActivationView)
    /// instead of a one-shot QuickDictateView recording - see
    /// FlowSessionEngine for why this is a genuinely different flow, not
    /// just a different screen.
    static let startFlowHost = "startflow"

    static var launchURL: URL {
        URL(string: "\(urlScheme)://\(dictateHost)")!
    }

    static var startFlowURL: URL {
        URL(string: "\(urlScheme)://\(startFlowHost)")!
    }

    private static let pendingTextKey = "dictation.pendingText"
    private static let pendingDateKey = "dictation.pendingDate"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Called by the main app once a dictation finishes.
    static func publish(_ text: String) {
        guard let defaults = sharedDefaults, !text.isEmpty else { return }
        defaults.set(text, forKey: pendingTextKey)
        defaults.set(Date(), forKey: pendingDateKey)
    }

    /// Called by the keyboard extension to see if there's something to offer.
    static func pending() -> (text: String, date: Date)? {
        guard let defaults = sharedDefaults,
              let text = defaults.string(forKey: pendingTextKey),
              !text.isEmpty else { return nil }
        let date = defaults.object(forKey: pendingDateKey) as? Date ?? .distantPast
        return (text, date)
    }

    /// Called by the keyboard extension right after it inserts the pending text,
    /// so the same dictation doesn't get offered again indefinitely.
    static func clearPending() {
        sharedDefaults?.removeObject(forKey: pendingTextKey)
        sharedDefaults?.removeObject(forKey: pendingDateKey)
    }

    // MARK: - Commands (command-mode utterances, see VoiceCommand)

    private static let pendingCommandKey = "dictation.pendingCommand"

    /// Called by the main app when a command-mode utterance has been interpreted
    /// - either a recognised command, or `Payload.unrecognized(text)` so the
    /// keyboard can explain what it heard instead of silently doing nothing.
    static func publishCommand(_ payload: VoiceCommand.Payload) {
        guard let defaults = sharedDefaults, let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: pendingCommandKey)
    }

    static func pendingCommand() -> VoiceCommand.Payload? {
        guard let data = sharedDefaults?.data(forKey: pendingCommandKey) else { return nil }
        return try? JSONDecoder().decode(VoiceCommand.Payload.self, from: data)
    }

    static func clearPendingCommand() {
        sharedDefaults?.removeObject(forKey: pendingCommandKey)
    }
}
