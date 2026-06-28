import SwiftUI

// Centralized font choices. The royal aesthetic depends on serif numerals + monospaced
// labels, so having one source of truth keeps the app feeling consistent.
//
// All fonts here use Apple's system serif (`.serif`) and monospaced (`.monospaced`)
// designs — they ship with iOS, no font files to bundle, no licensing.
// We can swap in a custom font later (e.g. Cinzel for headings) by changing this file only.
enum Fonts {

    // MARK: - Headings (serif, the regal voice)

    /// 28pt serif semibold — the main "VEERA" wordmark and major headings.
    static let heading = Font.system(size: 28, weight: .semibold, design: .serif)

    /// 17pt serif medium — section titles like "SOVEREIGN" on the player card.
    static let title = Font.system(size: 17, weight: .medium, design: .serif)

    /// 22pt serif semibold — Roman numerals on the level badge.
    static let romanNumeral = Font.system(size: 22, weight: .semibold, design: .serif)

    // MARK: - Body (default — sans, normal-feeling)

    /// 13pt regular — habit titles, quest names.
    static let body = Font.system(size: 13)

    /// 15pt medium — emphasized body text.
    static let bodyBold = Font.system(size: 15, weight: .medium)

    // MARK: - Labels (monospaced, the "engraved" voice)

    /// 11pt monospaced — section labels like "DAY 47 · DOMINION".
    static let label = Font.system(size: 11, design: .monospaced)

    /// 10pt monospaced — captions, dates, XP gain indicators.
    static let caption = Font.system(size: 10, design: .monospaced)

    /// 9pt monospaced — the smallest text in the app, used for stat labels (STR/INT/etc.).
    static let micro = Font.system(size: 9, design: .monospaced)

    // MARK: - Numerals (serif, for stat values and counters)

    /// 18pt serif medium — stat values, daily totals (STREAK 47, +37 XP TODAY).
    static let numeral = Font.system(size: 18, weight: .medium, design: .serif)

    /// 15pt serif medium — smaller numerals in the stat row.
    static let smallNumeral = Font.system(size: 15, weight: .medium, design: .serif)
}

// MARK: - View modifier — letterspacing for labels

// Letterspacing (tracking) is what makes the labels look engraved. We'll use this
// constantly, so this little modifier saves repetition.
extension View {
    /// Apply the "engraved label" style — typically 2pt tracking with muted gold color.
    func labelStyle() -> some View {
        self
            .font(Fonts.label)
            .tracking(2)
            .foregroundStyle(Theme.mutedGold)
    }
}

// MARK: - Card shapes

extension View {
    /// The standard heavy card: surface fill + dark border, rounded to Theme.cornerRadius.
    /// Use for stationary content surfaces (player card, stat row, daily totals).
    func roundedCard(cornerRadius: CGFloat = Theme.cornerRadius) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }

    /// A non-interactive Liquid Glass surface for tap rows.
    /// `.interactive()` is intentionally OFF here — when a glass effect is wrapped in
    /// a Button, the interactive variant adds its own touch recognizer that competes
    /// with the Button's tap and causes 3-4-tap lag. We use `RoyalButtonStyle` on the
    /// Button for press feedback instead, so taps stay snappy.
    func interactiveGlassCard(cornerRadius: CGFloat = Theme.cornerRadius) -> some View {
        self
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - Button press feedback

// Spring scale + opacity press feedback. NO haptic — haptics are reserved for
// meaningful events (completion, level-up, rank-up, vow rites, tab change) and
// fire via `HapticEngine.shared` at those specific call sites only.
struct RoyalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == RoyalButtonStyle {
    static var royal: RoyalButtonStyle { RoyalButtonStyle() }
}
