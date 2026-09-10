import SwiftUI

/// Every physical and voice entry point iOS offers, in one place - the Action
/// Button guide the playbook asks for (§3.1), plus Back Tap and the Siri phrases
/// registered by `NasarFlowShortcuts`. iOS gives an app no way to assign the
/// Action Button itself, so this is a walkthrough, like `KeyboardSetupView`.
struct ShortcutsGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Nasar Flow registers three Shortcuts on install. Assign one to a button, or just say it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Action Button (iPhone 15 Pro and later)") {
                    step(1, "Settings > Action Button")
                    step(2, "Swipe to Shortcut, tap Choose a Shortcut")
                    step(3, "Under Nasar Flow, pick Dictate (or Turn On Flow)")
                }

                Section("Back Tap (any iPhone)") {
                    step(1, "Settings > Accessibility > Touch > Back Tap")
                    step(2, "Double Tap or Triple Tap > scroll to Shortcuts")
                    step(3, "Pick Dictate under Nasar Flow")
                }

                Section("Siri") {
                    phrase("Dictate with Nasar Flow", does: "Opens Quick Dictate and starts listening")
                    phrase("Turn on Flow in Nasar Flow", does: "Starts a Flow session for the keyboard")
                    phrase("Turn off Flow in Nasar Flow", does: "Ends the session and releases the mic")
                }

                Section {
                    Button {
                        if let url = URL(string: "shortcuts://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Shortcuts", systemImage: "square.2.layers.3d")
                    }
                } footer: {
                    Text("Every entry point opens Nasar Flow first, because iOS only lets an app that is on screen start the microphone. Control Center and Lock Screen controls need a widget extension and are coming later.")
                }
            }
            .navigationTitle("Buttons & Siri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.tint, in: Circle())
            Text(text)
                .font(.subheadline)
        }
        .padding(.vertical, 2)
    }

    private func phrase(_ text: String, does: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\u{201C}\(text)\u{201D}")
                .font(.subheadline.weight(.medium))
            Text(does)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ShortcutsGuideView()
}
