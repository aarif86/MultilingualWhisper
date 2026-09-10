import AppIntents
import SwiftUI
import WidgetKit

/// Control Center buttons (iOS 18): "Dictate" opens Quick Dictate, "Flow" turns
/// a Flow session on. Both run in this extension's process and then open the app
/// through the same URLs the keyboard uses - iOS only lets a foreground app
/// start the microphone, so opening the app is the whole job here.
@available(iOS 18.0, *)
struct DictateControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.multilingualwhisper.app.control.dictate") {
            ControlWidgetButton(action: OpenDictateIntent()) {
                Label("Dictate", systemImage: "mic.fill")
            }
        }
        .displayName("Dictate with Nasar Flow")
        .description("Opens Nasar Flow listening.")
    }
}

@available(iOS 18.0, *)
struct FlowControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.multilingualwhisper.app.control.flow") {
            ControlWidgetButton(action: OpenStartFlowIntent()) {
                Label("Turn On Flow", systemImage: "waveform")
            }
        }
        .displayName("Turn On Flow")
        .description("Starts a Flow session so the Nasar Flow keyboard can dictate anywhere.")
    }
}

@available(iOS 18.0, *)
struct OpenDictateIntent: AppIntent {
    static var title: LocalizedStringResource = "Dictate with Nasar Flow"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(DictationHandoff.launchURL))
    }
}

@available(iOS 18.0, *)
struct OpenStartFlowIntent: AppIntent {
    static var title: LocalizedStringResource = "Turn On Flow"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(DictationHandoff.startFlowURL))
    }
}
