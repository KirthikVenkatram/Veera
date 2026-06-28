import SwiftUI

// Heraldic divider: thin gold line with a small diamond ornament centered on it.
// Use between major sections to add visual rhythm without the weight of a card.
struct HeraldicDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            line
            Rectangle()
                .fill(Theme.gold)
                .frame(width: 8, height: 8)
                .rotationEffect(.degrees(45))
            line
        }
        .frame(maxWidth: .infinity)
    }

    private var line: some View {
        Rectangle()
            .fill(Theme.mutedGold.opacity(0.6))
            .frame(height: 1)
    }
}

// Section header banner: a rectangle with a downward chevron cut into the
// bottom edge. Use for big section titles in Stats and Quests.
struct HeraldicBanner: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(Fonts.title)
            .tracking(4)
            .foregroundStyle(Theme.gold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .background(Theme.surface)
            .overlay(
                Rectangle().stroke(Theme.border, lineWidth: 1)
            )
            .clipShape(BannerShape())
            .overlay(
                BannerShape().stroke(Theme.gold.opacity(0.4), lineWidth: 1)
            )
    }
}

private struct BannerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let chevronDepth: CGFloat = 10
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - chevronDepth))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - chevronDepth))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 32) {
        HeraldicDivider()
        HeraldicBanner(title: "Stats")
        HeraldicDivider()
    }
    .padding()
    .background(Theme.obsidian)
    .preferredColorScheme(.dark)
}
