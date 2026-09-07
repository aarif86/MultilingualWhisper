import SwiftUI

struct KeyboardView: View {
    // SwiftUI's own open-URL mechanism, not a UIKit call - see the comment on
    // `dictateButton` for why this replaced two failed UIKit-level attempts.
    @Environment(\.openURL) private var openURL

    let hasFullAccess: Bool
    let pending: (text: String, date: Date)?
    let onInsert: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if !hasFullAccess {
                fullAccessNeeded
            } else {
                if let pending {
                    pendingResultRow(pending.text)
                }
                dictateButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Two prior UIKit-level attempts (extensionContext.open, then walking the
    // responder chain to invoke UIApplication's openURL: dynamically) both
    // confirmed-on-device did nothing - no crash, no error, app never
    // foregrounded. SwiftUI's `\.openURL` environment action is a genuinely
    // different code path, not just another way to call the same restricted
    // UIKit API - it's the same mechanism that lets a `Link` open its
    // containing app from inside a WidgetKit widget, another context where
    // direct UIApplication calls don't work. Not yet confirmed on-device
    // either, but well-precedented and untried, unlike a third UIKit variant.
    private var dictateButton: some View {
        VStack(spacing: 4) {
            Button {
                DebugLogger.shared.log("Dictate tapped, opening \(DictationHandoff.launchURL) via SwiftUI openURL", category: "keyboard")
                openURL(DictationHandoff.launchURL)
            } label: {
                Label("Dictate with Nasar Flow", systemImage: "waveform")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)

            // Stays usable even if this OS boundary never becomes fully
            // automatic: switch to Nasar Flow yourself, dictate, then come
            // back and use Insert above once there's a pending result.
            Text("If nothing happens, open Nasar Flow yourself, dictate, then come back")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func pendingResultRow(_ text: String) -> some View {
        Button {
            onInsert(text)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tap to insert")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var fullAccessNeeded: some View {
        VStack(spacing: 6) {
            Text("Enable Full Access")
                .font(.headline)
            Text("Settings > Keyboard > Keyboards > Nasar Flow > Allow Full Access - needed so this keyboard can open the app to dictate.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    KeyboardView(
        hasFullAccess: true,
        pending: (text: "Bismillah, let's go makan lah", date: Date()),
        onInsert: { _ in }
    )
    .frame(height: 216)
}
