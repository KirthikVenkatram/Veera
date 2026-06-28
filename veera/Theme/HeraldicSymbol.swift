import SwiftUI

// The rotated-square level badge with a Roman numeral inside.
// This is what makes Veera feel like a personal kingdom rather than a generic RPG —
// a signet/seal rather than a game icon.
struct LevelBadge: View {
    let level: Int
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            // The diamond — a square rotated 45 degrees, with a gold border.
            Rectangle()
                .stroke(Theme.gold, lineWidth: 1.5)
                .background(
                    Rectangle().fill(Theme.surface)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(45))

            // Roman numeral inside — un-rotated so it reads normally.
            Text(romanNumeral(for: level))
                .font(.system(size: size * 0.4, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.gold)
        }
        // Important: the bounding box of a rotated square is larger than the square itself.
        // We compensate so the badge takes the right amount of space in parent layouts.
        .frame(width: size * 1.414, height: size * 1.414)
    }

    // Convert an Int to Roman numerals. Pure function, easy to test.
    // Caps at 3999 (MMMCMXCIX) — beyond that, Roman numerals need overlines we don't render.
    // For a habit app, level 3999 is more than fine.
    private func romanNumeral(for value: Int) -> String {
        guard value > 0 && value < 4000 else { return "\(value)" }

        let mapping: [(Int, String)] = [
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
            (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")
        ]

        var remaining = value
        var result = ""
        for (number, symbol) in mapping {
            while remaining >= number {
                result += symbol
                remaining -= number
            }
        }
        return result
    }
}

#Preview {
    ZStack {
        Theme.obsidian.ignoresSafeArea()
        HStack(spacing: 30) {
            LevelBadge(level: 1)
            LevelBadge(level: 7)
            LevelBadge(level: 12)
            LevelBadge(level: 47)
        }
    }
    .preferredColorScheme(.dark)
}
