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

    var autoPunctuation: Bool {
        didSet { defaults.set(autoPunctuation, forKey: Keys.autoPunctuation) }
    }

    var maxRecordDurationSeconds: Int {
        didSet { defaults.set(maxRecordDurationSeconds, forKey: Keys.maxRecordDuration) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.languageMode = (defaults.string(forKey: Keys.languageMode)).flatMap(LanguageMode.init(rawValue:)) ?? .auto
        self.vadSensitivity = defaults.object(forKey: Keys.vadSensitivity) as? Float ?? Constants.defaultVADThreshold
        self.autoPunctuation = defaults.object(forKey: Keys.autoPunctuation) as? Bool ?? true
        self.maxRecordDurationSeconds = defaults.object(forKey: Keys.maxRecordDuration) as? Int ?? Int(Constants.chunkDurationSeconds)
    }

    private enum Keys {
        static let languageMode = "settings.languageMode"
        static let vadSensitivity = "settings.vadSensitivity"
        static let autoPunctuation = "settings.autoPunctuation"
        static let maxRecordDuration = "settings.maxRecordDuration"
    }
}
