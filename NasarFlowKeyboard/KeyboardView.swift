import SwiftUI

struct KeyboardView: View {
    let hasFullAccess: Bool
    let pending: (text: String, date: Date)?
    let onDictate: () -> Void
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

    private var dictateButton: some View {
        Button(action: onDictate) {
            Label("Dictate with Nasar Flow", systemImage: "waveform")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
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
        onDictate: {},
        onInsert: { _ in }
    )
    .frame(height: 216)
}
