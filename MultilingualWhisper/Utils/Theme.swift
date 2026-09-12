import SwiftUI

/// Brand palette and type system, introduced 2026-09-12 to replace the stock
/// system-blue look the app shipped with until now. Pulled directly from the
/// real marketing site (flow.nasar.sg) and the app icon - not invented - so
/// the app finally looks like the same product as its own website.
///
/// Deliberately light-mode only for this pass: the warm paper background is
/// the whole point of the look, and a faithful dark variant is its own
/// design exercise, not a mechanical color inversion.
enum Brand {
    static let ink = Color(hex: 0x17150F)
    static let inkSoft = Color(hex: 0x6B6656)
    static let inkFaint = Color(hex: 0x9A947F)

    static let paper = Color(hex: 0xFBF7F0)
    static let card = Color(hex: 0xFFFFFF)
    static let cardWarm = Color(hex: 0xF6EFDD)
    static let line = Color(hex: 0xE8DFC9)

    static let gold = Color(hex: 0xB8932A)
    static let goldLight = Color(hex: 0xE4C878)
    static let goldDeep = Color(hex: 0x8E6E1A)
    static let goldTint = Color(hex: 0xF3E8CC)

    static let terracotta = Color(hex: 0xA23B2E)
    static let terracottaSoft = Color(hex: 0xF6E4E0)

    /// The record button and other gold surfaces carrying a white icon or
    /// label. Deliberately excludes `goldLight` - a white icon on that stop
    /// alone measures ~1.6:1 contrast (WCAG needs 3:1 even for large
    /// graphical objects), a real defect caught via the poc-uplift skill's
    /// documented finding that this exact gold (`0xB8932A`, 2.9:1 on white)
    /// already failed contrast on a past project. `gold` itself still dips
    /// under 3:1 at its lightest edge, but the icons riding this gradient
    /// are large/bold and centered nearer the `goldDeep` half in practice.
    static let goldGradient = LinearGradient(
        colors: [gold, goldDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Recording state only - mirrors goldGradient's warmth/darkness curve so
    /// the button reads as "the same control, different state," not a
    /// different button.
    static let terracottaGradient = LinearGradient(
        colors: [Color(hex: 0xC65A48), terracotta, Color(hex: 0x7E2E23)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardCornerRadius: CGFloat = 20
    static let cardShadow = Color.black.opacity(0.06)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Font {
    /// DM Serif Display, bundled under Resources/Fonts and registered via
    /// UIAppFonts (see project.yml) - reserved for hero moments only (the
    /// wordmark, onboarding headlines). Everything else stays system San
    /// Francisco, so the app still reads as a native iOS app up close
    /// instead of a website transplanted onto a phone.
    static func brandSerif(_ size: CGFloat) -> Font {
        .custom("DMSerifDisplay-Regular", size: size)
    }
}

extension View {
    /// The warm card treatment used throughout the redesign in place of
    /// `.thinMaterial` - a flat white surface on the cream background reads
    /// as more deliberate than a translucent blur where there's nothing
    /// behind it to blur.
    func brandCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius, style: .continuous))
            .shadow(color: Brand.cardShadow, radius: 14, y: 6)
    }
}
