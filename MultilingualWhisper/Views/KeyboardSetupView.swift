import SwiftUI

/// Walks the user through adding the Nasar Flow keyboard. iOS has no API for an
/// app to install or enable its own keyboard extension automatically - the same
/// category of restriction as blocking microphone access from keyboards - and no
/// supported deep link goes straight to Settings > General > Keyboard > Keyboards
/// (`UIApplication.openSettingsURLString` only opens this app's own Settings
/// page). Every third-party keyboard, including Wispr Flow and Willow, hits this
/// exact wall - the best any app can do is explain the steps clearly and get the
/// user into Settings with one tap.
struct KeyboardSetupView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Step: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(title: "Open Settings", detail: "Tap \u{201C}Open Settings\u{201D} below, or go there yourself: Settings app \u{2192} General \u{2192} Keyboard \u{2192} Keyboards."),
        Step(title: "Add New Keyboard", detail: "Tap \u{201C}Add New Keyboard\u{2026}\u{201D} and select \u{201C}Nasar Flow\u{201D} from the list."),
        Step(title: "Allow Full Access", detail: "Tap \u{201C}Nasar Flow\u{201D} in that same Keyboards list again, then turn on \u{201C}Allow Full Access.\u{201D} This is required - the keyboard can't even open this app to dictate without it."),
        Step(title: "Switch keyboards to use it", detail: "In any app with a text field, tap and hold (or tap) the globe icon on the keyboard to switch to Nasar Flow, then tap \u{201C}Start Flow.\u{201D} That's a one-time activation (also toggleable in Settings) - after it, the keyboard's own mic button dictates directly without opening Nasar Flow again."),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Nasar Flow can work as a keyboard in any app - Messages, Notes, anywhere you type - so you can dictate without switching apps. iOS requires a few manual steps to turn this on; there's no way for any app to skip them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Steps") {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(.tint, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(.headline)
                                Text(step.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                    }
                } footer: {
                    Text("This opens Nasar Flow's own Settings page - iOS doesn't allow linking directly to the Keyboards screen, so from there go to the Settings app's home, then General \u{2192} Keyboard \u{2192} Keyboards.")
                }
            }
            .navigationTitle("Set Up Keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    KeyboardSetupView()
}
