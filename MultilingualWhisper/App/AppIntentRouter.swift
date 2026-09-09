import Foundation
import Observation

/// The hand-off between App Intents (Shortcuts, Siri, the Action Button, Back Tap,
/// Spotlight) and the running app.
///
/// An intent's `perform()` runs inside the app process but has no handle on the
/// app's services - `FlowSessionEngine` and the Quick Dictate cover are owned by
/// `MultilingualWhisperApp`. So the intent leaves a request here, and the app,
/// which already reacts to `nasarflow://` URLs the same way, picks it up in
/// `onChange(of: sequence)` and does exactly what the matching URL would do.
///
/// `sequence` exists so two identical requests in a row ("Dictate", then "Dictate"
/// again) both trigger the observer - `pending` alone would not change value.
@MainActor
@Observable
final class AppIntentRouter {
    static let shared = AppIntentRouter()

    enum Request: Equatable {
        /// Open the app on the Quick Dictate cover and start listening at once -
        /// the same thing the keyboard's `nasarflow://dictate` URL does.
        case dictate
        /// Show the Flow activation sheet - the same as `nasarflow://startflow`.
        case startFlow
        /// End the background Flow session.
        case stopFlow
    }

    private(set) var pending: Request?
    private(set) var sequence = 0

    func request(_ request: Request) {
        pending = request
        sequence += 1
    }

    /// Returns and clears the pending request, so a request is acted on once.
    @discardableResult
    func consume() -> Request? {
        defer { pending = nil }
        return pending
    }
}
