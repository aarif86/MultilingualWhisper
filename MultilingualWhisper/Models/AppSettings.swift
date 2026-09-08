import Foundation
import Observation

/// App-wide user preferences.
///
/// The spec this app was built from modeled settings as a SwiftData `@Model`.
/// Settings are a single blob of scalars (an enum, a float, a couple of bools),
/// not a growing collection of records — SwiftData is built for the latter, and
/// using it here would mean solving "what if two settings rows exist" for no
/// benefit. UserDefaults + `@Observable` is the simpler, standard fit and is
/// what `@AppStorage` in the views is already backed by under the hood.
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults

    var languageMode: LanguageMode {
        didSet { defaults.set(languageMode.rawValue, forKey: Keys.languageMode) }
    }

    var vadSensitivity: Float {
        didSet { defaults.set(vadSensitivity, forKey: Keys.vadSensitivity) }
    }

    /// Escape hatch for the energy-threshold VAD, which is a heuristic that won't
    /// be perfectly calibrated on every device/environment. Off means fully manual:
    /// tap to start, tap again to stop, no auto-stop at all.
    var autoStopOnSilence: Bool {
        didSet { defaults.set(autoStopOnSilence, forKey: Keys.autoStopOnSilence) }
    }

    var autoPunctuation: Bool {
        didSet { defaults.set(autoPunctuation, forKey: Keys.autoPunctuation) }
    }

    var maxRecordDurationSeconds: Int {
        didSet { defaults.set(maxRecordDurationSeconds, forKey: Keys.maxRecordDuration) }
    }

    /// Off by default - this app's whole positioning is "nothing you say ever
    /// leaves your phone," and silently keeping recordings around, even
    /// on-device only, is a real change to that promise worth an explicit
    /// opt-in. When on, DebugAudioStore keeps the last few recordings as WAV
    /// files so a real transcription problem can be debugged against the
    /// actual audio instead of a typed-out description of what was said.
    var saveDebugAudio: Bool {
        didSet { defaults.set(saveDebugAudio, forKey: Keys.saveDebugAudio) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.languageMode = (defaults.string(forKey: Keys.languageMode)).flatMap(LanguageMode.init(rawValue:)) ?? .auto
        self.vadSensitivity = defaults.object(forKey: Keys.vadSensitivity) as? Float ?? Constants.defaultVADThreshold
        self.autoStopOnSilence = defaults.object(forKey: Keys.autoStopOnSilence) as? Bool ?? true
        self.autoPunctuation = defaults.object(forKey: Keys.autoPunctuation) as? Bool ?? true
        self.maxRecordDurationSeconds = defaults.object(forKey: Keys.maxRecordDuration) as? Int ?? Int(Constants.chunkDurationSeconds)
        self.saveDebugAudio = defaults.object(forKey: Keys.saveDebugAudio) as? Bool ?? false
    }

    private enum Keys {
        static let languageMode = "settings.languageMode"
        static let vadSensitivity = "settings.vadSensitivity"
        static let autoStopOnSilence = "settings.autoStopOnSilence"
        static let autoPunctuation = "settings.autoPunctuation"
        static let maxRecordDuration = "settings.maxRecordDuration"
        static let saveDebugAudio = "settings.saveDebugAudio"
    }
}
