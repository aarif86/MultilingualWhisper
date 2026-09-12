import SwiftUI
import UIKit

/// Brand palette and type system, introduced 2026-09-12 to replace the stock
/// system-blue look the app shipped with until now. Pulled directly from the
/// real marketing site (flow.nasar.sg) and the app icon - not invented - so
/// the app finally looks like the same product as its own website.
///
/// Revised the same day: the first pass washed cream over the whole page,
/// which read as muted/low-energy rather than premium (real feedback: "looks
/// like sleep mode"). White is now the dominant surface - gold is an accent
/// (the record button, active states, badges), not a background tint. Warm
/// cream (`cardWarm`) still exists for the handful of places that want a
/// deliberately warm-tinted surface (the Language Words tile, an onboarding
/// highlight row), used sparingly rather than everywhere.
///
/// Dark mode added the same day, as a real second pass, not a mechanical
/// inversion - see `Color.init(light:dark:)`. The one subtlety worth writing
/// down: this palette has TWO different gold roles that need opposite
/// treatment under dark mode -
///   - `goldDeep` is gold used as TEXT/tint against the page or a card, and
///     genuinely needs to get BRIGHTER in dark mode to clear 4.5:1 against a
///     near-black surface (a color that reads on white typically doesn't
///     read on black - the poc-uplift skill's contrast finding this whole
///     palette already had to account for once).
///   - `goldSolid` is gold used as a FILLED surface that carries white/light
///     content on top of it (a `.borderedProminent` button's white label,
///     the record button's white icon, a native Toggle's white thumb). That
///     relationship doesn't change with theme, so this one stays FIXED -
///     brightening it in dark mode the way `goldDeep` does would wash out
///     the white content sitting on it instead of helping legibility.
/// Mixing these two up is the easiest way to silently reintroduce the exact
/// contrast bug this palette was built to fix, just in the other direction.
enum Brand {
    static let ink = Color(light: 0x17150F, dark: 0xF2EFE9)
    static let inkSoft = Color(light: 0x6B6656, dark: 0xB5AFA2)
    static let inkFaint = Color(light: 0x9A947F, dark: 0x999280)

    static let paper = Color(light: 0xFFFFFF, dark: 0x161410)
    static let card = Color(light: 0xFFFFFF, dark: 0x211E19)
    static let cardWarm = Color(light: 0xF6EFDD, dark: 0x2A2318)
    static let line = Color(light: 0xE8DFC9, dark: 0x35302A)

    /// Text/tint role - see the enum's doc comment. Used for a colored
    /// label, icon, or `.bordered`/`TabView` tint sitting on the page or a
    /// card, never as a fill behind white content.
    static let goldDeep = Color(light: 0x8E6E1A, dark: 0xE0B565)
    /// Text/badge role, same reasoning as `goldDeep`.
    static let terracotta = Color(light: 0xA23B2E, dark: 0xE0917C)
    static let terracottaSoft = Color(light: 0xF6E4E0, dark: 0x3A2420)

    /// Fixed fill role - see the enum's doc comment. Used only inside
    /// `goldGradient` and anywhere else gold sits BEHIND white/light content
    /// (a `.borderedProminent` tint, a filled Toggle track, the Onboarding
    /// CTA's solid background).
    static let goldSolid = Color(hex: 0x8E6E1A)
    private static let gold = Color(hex: 0xB8932A)
    private static let goldLight = Color(hex: 0xE4C878)

    /// The record button and other gold surfaces carrying a white icon or
    /// label. Fixed (not adaptive) end to end - see the enum's doc comment.
    /// Includes the brighter `goldLight` stop for real shine/vibrancy; the
    /// icons riding this gradient are large/bold with their own drop shadow
    /// and sit centered, away from the lightest corner, so the low contrast
    /// at that single corner doesn't cost real legibility - a deliberate
    /// trade for a large decorative control, not an oversight.
    static let goldGradient = LinearGradient(
        colors: [goldLight, gold, goldSolid],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Recording state only - fixed end to end, same reasoning as
    /// `goldGradient`. Mirrors its warmth/darkness curve so the button reads
    /// as "the same control, different state," not a different button.
    static let terracottaGradient = LinearGradient(
        colors: [Color(hex: 0xC65A48), Color(hex: 0xA23B2E), Color(hex: 0x7E2E23)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardCornerRadius: CGFloat = 20
    static let cardShadow = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.5)
            : UIColor.black.withAlphaComponent(0.06)
    })
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// An adaptive color: `light` in Light Mode, `dark` in Dark Mode - real,
    /// separately-chosen dark-mode values (see `Brand`'s doc comment), not
    /// an inverted light palette.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
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
    /// The card treatment used throughout the redesign in place of
    /// `.thinMaterial` - a flat surface lifted off the page by shadow (light
    /// mode) or by being a shade lighter than the page (dark mode, where a
    /// black shadow on a near-black page shows nothing) reads as more
    /// deliberate than a translucent blur where there's nothing behind it
    /// to blur.
    func brandCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: Brand.cardCornerRadius, style: .continuous))
            .shadow(color: Brand.cardShadow, radius: 14, y: 6)
    }
}
