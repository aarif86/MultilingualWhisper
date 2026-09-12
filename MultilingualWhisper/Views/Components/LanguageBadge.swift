import SwiftUI

struct LanguageBadge: View {
    let language: LanguageType
    /// Which specific languages make up `language` when it's `.mixed` - shown
    /// instead of the generic "Mixed" label when there's more than one, e.g.
    /// "Arabic + Malay + Singlish". Defaults to empty so existing call sites
    /// (and the preview below) keep showing the plain category name.
    var components: [LanguageType] = []

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        guard components.count > 1 else { return language.rawValue }
        return components.map(\.rawValue).joined(separator: " + ")
    }

    // Every case here is a text color on a ~15%-opacity tint of itself (near-
    // white) - `Brand.gold` (2.9:1) and `Brand.inkFaint` (3.0:1) both fail
    // WCAG AA's 4.5:1 for normal text at this badge's caption size, so text
    // colors stick to `goldDeep`/`inkSoft`/`terracotta`, all verified >=4.5:1.
    private var color: Color {
        switch language {
        case .singlish: return Brand.inkSoft
        case .malay: return Brand.goldDeep
        case .arabic: return Brand.terracotta
        case .english: return Brand.inkSoft
        case .mixed: return Brand.goldDeep
        case .unknown: return Brand.inkSoft
        }
    }
}

#Preview {
    HStack {
        ForEach(LanguageType.allCases) { LanguageBadge(language: $0) }
    }
    .padding()
}
