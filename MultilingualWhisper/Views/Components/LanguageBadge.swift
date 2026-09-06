import SwiftUI

struct LanguageBadge: View {
    let language: LanguageType

    var body: some View {
        Text(language.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch language {
        case .singlish: return .blue
        case .malay: return .green
        case .arabic: return .purple
        case .english: return .indigo
        case .mixed: return .orange
        case .unknown: return .gray
        }
    }
}

#Preview {
    HStack {
        ForEach(LanguageType.allCases) { LanguageBadge(language: $0) }
    }
    .padding()
}
