import Foundation

/// Shared state for the "Flow session" feature (see FlowSessionEngine in the
/// main app target) - same App Group reasoning as DictationHandoff: the
/// keyboard extension and main app are separate sandboxes, so this shared
/// UserDefaults suite is the one place both can read/write.
///
/// Darwin notifications (DarwinNotification.swift) carry the "something just
/// happened, go check" signal; these properties carry the actual state to
/// check. Notifications alone can't hold a payload worth trusting across
/// processes, and polling shared UserDefaults alone can't wake a suspended
/// listener - the two mechanisms are complementary, not redundant.
enum FlowSessionState {

    // MARK: - Darwin notification names

    /// Posted by the keyboard when its mic button is tapped - tells the main
    /// app (already running in the background from an earlier activation) to
    /// start buffering the next utterance.
    static let startUtterance = "com.multilingualwhisper.app.flow.startUtterance"
    /// Posted by the keyboard when tapped again to stop - tells the main app
    /// to stop buffering and transcribe what it captured.
    static let stopUtterance = "com.multilingualwhisper.app.flow.stopUtterance"
    /// Posted by the main app whenever isActive/isRecording/a result changes,
    /// so the keyboard can refresh immediately instead of waiting for the
    /// next incidental UIInputViewController lifecycle callback.
    static let stateChanged = "com.multilingualwhisper.app.flow.stateChanged"

    // MARK: - Persisted state

    private static let isActiveKey = "flow.isActive"
    private static let isRecordingKey = "flow.isRecording"
    private static let startedAtKey = "flow.utteranceStartedAt"
    private static let lastFailureKey = "flow.lastFailureAt"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: DictationHandoff.appGroupID)
    }

    /// Whether a session is currently active - i.e. FlowSessionEngine's audio
    /// engine is (supposed to be) running continuously in the background.
    /// The keyboard trusts this to decide whether to show "Start" or the
    /// live listening UI; see KeyboardViewController's short post-tap timeout
    /// for what happens when this says active but the app has actually died.
    static var isActive: Bool {
        get { sharedDefaults?.bool(forKey: isActiveKey) ?? false }
        set { sharedDefaults?.set(newValue, forKey: isActiveKey) }
    }

    static var isRecording: Bool {
        get { sharedDefaults?.bool(forKey: isRecordingKey) ?? false }
        set { sharedDefaults?.set(newValue, forKey: isRecordingKey) }
    }

    /// When the current utterance started, so the keyboard can compute its
    /// own elapsed-time display (Date() - this) locally instead of needing a
    /// once-a-second push from the app.
    static var utteranceStartedAt: Date? {
        get { sharedDefaults?.object(forKey: startedAtKey) as? Date }
        set { sharedDefaults?.set(newValue, forKey: startedAtKey) }
    }

    /// Set by the app the instant a transcription attempt fails or comes back
    /// empty - lets the keyboard notice and give up immediately instead of
    /// only ever finding out via its own 20-second last-resort timeout, which
    /// otherwise looks indistinguishable from "still working" the whole time.
    static var lastFailureAt: Date? {
        get { sharedDefaults?.object(forKey: lastFailureKey) as? Date }
        set { sharedDefaults?.set(newValue, forKey: lastFailureKey) }
    }

    /// Called when a session ends (explicitly, or the app decides to time it
    /// out) so the keyboard falls back to "Start" instead of a stale
    /// listening-capable state that no longer actually works.
    static func clear() {
        isActive = false
        isRecording = false
        utteranceStartedAt = nil
        lastFailureAt = nil
    }
}
