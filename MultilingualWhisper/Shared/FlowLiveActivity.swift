import ActivityKit
import AppIntents
import Foundation

/// The Live Activity / Dynamic Island "Flow is on" badge - the single most
/// important trust affordance for a background microphone session
/// (`docs/DICTATION-PLAYBOOK.md` §3.1, Willow's pattern): while Flow keeps the
/// mic open, the phone says so at the top of the screen, and one tap turns it
/// off. Shared between the app (which starts, updates and ends the activity)
/// and the NasarFlowWidgets extension (which draws it).
struct FlowActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// An utterance is being captured right now.
        var isRecording: Bool
        /// When the current state began - the activity shows a live timer from it.
        var since: Date
    }

    /// When the session was turned on.
    var startedAt: Date
}

/// The "Off" button on the Live Activity. `LiveActivityIntent` runs in the app's
/// own process even when it is in the background, so this just rings the same
/// Darwin bell the keyboard would - `FlowSessionEngine` observes it and ends the
/// session. Compiled into both the app and the widget extension.
struct StopFlowLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Turn Off Flow"
    static var description = IntentDescription("Ends the Flow session and turns the microphone off.")
    /// The Shortcuts-facing "Turn Off Flow" is `StopFlowIntent` in the app; this
    /// one exists only for the button.
    static var isDiscoverable: Bool = false

    init() {}

    func perform() async throws -> some IntentResult {
        DarwinNotification.post(FlowSessionState.endSession)
        return .result()
    }
}
