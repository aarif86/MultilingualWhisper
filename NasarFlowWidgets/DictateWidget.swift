import SwiftUI
import WidgetKit

/// A Lock Screen (and small Home Screen) widget that opens Nasar Flow straight
/// onto Quick Dictate - the same `nasarflow://dictate` URL the keyboard uses.
/// Static: nothing to fetch, nothing to refresh.
struct DictateWidget: Widget {
    let kind = "NasarFlowDictate"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DictateProvider()) { _ in
            DictateWidgetView()
        }
        .configurationDisplayName("Dictate")
        .description("Opens Nasar Flow listening. Add it to your Lock Screen for one-tap dictation.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .systemSmall])
    }
}

struct DictateEntry: TimelineEntry {
    let date: Date
}

struct DictateProvider: TimelineProvider {
    func placeholder(in context: Context) -> DictateEntry { DictateEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (DictateEntry) -> Void) {
        completion(DictateEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DictateEntry>) -> Void) {
        completion(Timeline(entries: [DictateEntry(date: Date())], policy: .never))
    }
}

struct DictateWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Image(systemName: "mic.fill")
                    .font(.title2)
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Dictate").font(.headline)
                        Text("Nasar Flow").font(.caption2)
                    }
                }
            default:
                VStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.tint)
                    Text("Dictate")
                        .font(.headline)
                    Text("Singlish, Malay, Arabic - on-device")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .widgetURL(DictationHandoff.launchURL)
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}
