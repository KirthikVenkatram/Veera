import SwiftUI

// The royal palette for Veera. Centralized here so we never repeat RGB values
// in views. If you ever want to tweak the gold (say, push it slightly warmer
// for evenings), you change it once and the whole app shifts.
//
// All colors are defined as static Color extensions on a custom Theme namespace.
// Usage: Theme.gold, Theme.parchment, etc.
enum Theme {

    // MARK: - Core palette

    /// The royal gold. Used for active states, completed habits, XP, and the level badge.
    /// Hex #C9A24B — a slightly aged, muted gold, not modern neon yellow.
    static let gold = Color(red: 0xC9/255, green: 0xA2/255, blue: 0x4B/255)

    /// The danger red. Reserved for deadlines, missed habits, overdue items.
    /// Hex #B83838 — oxblood, not bright traffic-light red. Reads serious, not alarming.
    static let red = Color(red: 0xB8/255, green: 0x38/255, blue: 0x38/255)

    /// The base black. Slightly warmer than pure #000000 — sits better on OLED
    /// without looking flat. Hex #0A0A0A.
    static let obsidian = Color(red: 0x0A/255, green: 0x0A/255, blue: 0x0A/255)

    /// The card/surface color. Used for habit row backgrounds and quest cards.
    /// Hex #14100A — slightly warm, almost imperceptibly so, to feel parchment-adjacent.
    static let surface = Color(red: 0x14/255, green: 0x10/255, blue: 0x0A/255)

    /// The body text color. A warm cream, not pure white — reduces eye strain
    /// and feels more like ink on aged paper than a sterile UI. Hex #E8DCC4.
    static let parchment = Color(red: 0xE8/255, green: 0xDC/255, blue: 0xC4/255)

    /// Secondary text — muted gold for labels, captions, secondary info.
    /// Hex #8B6F3D. Darker variant of the main gold.
    static let mutedGold = Color(red: 0x8B/255, green: 0x6F/255, blue: 0x3D/255)

    /// Border/divider color. Hex #2A1F12 — a brown so dark it almost reads as black.
    static let border = Color(red: 0x2A/255, green: 0x1F/255, blue: 0x12/255)

    /// Disabled / completed text — dimmer parchment for struck-through items.
    /// Hex #6B5530.
    static let dim = Color(red: 0x6B/255, green: 0x55/255, blue: 0x30/255)

    // MARK: - Shape

    /// The corner radius used for cards, rows, and tap surfaces. One value used everywhere
    /// keeps the silhouette consistent. 16pt matches Apple's grouped-card default.
    static let cornerRadius: CGFloat = 16

    // MARK: - Semantic helpers

    /// Color for a stat value based on whether it's "low" (below threshold).
    /// Low stats glow red — passive nudge toward what needs work.
    static func statColor(value: Int, lowThreshold: Int = 30) -> Color {
        value < lowThreshold ? red : gold
    }
}
