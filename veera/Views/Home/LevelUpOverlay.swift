import SwiftUI

// Fired from HomeView when a completion pushes the player into a new level.
// Identifiable so it can drive a fullScreenCover / overlay item.
struct LevelUpEvent: Identifiable {
    let id = UUID()
    let newLevel: Int
    let newRank: Rank
    let rankChanged: Bool
}

// Full-screen celebration shown when the player levels up.
// Tap anywhere to dismiss. Triggers a success haptic on appear.
struct LevelUpOverlay: View {
    let event: LevelUpEvent
    let onDismiss: () -> Void

    @State private var badgeScale: CGFloat = 0.3
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Theme.obsidian.opacity(0.97).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text("LEVEL UP")
                    .font(Fonts.heading)
                    .tracking(10)
                    .foregroundStyle(Theme.gold)
                    .opacity(contentOpacity)

                LevelBadge(level: event.newLevel, size: 100)
                    .scaleEffect(badgeScale)
                    .shadow(color: Theme.gold.opacity(0.4), radius: 24)

                if event.rankChanged {
                    VStack(spacing: 8) {
                        // The unlock moment IS the reveal — show the secret's full title.
                        Text(event.newRank.isSecret ? "SECRET RANK UNLOCKED" : "NEW RANK")
                            .labelStyle()
                        Text(event.newRank.rawValue.uppercased())
                            .font(Fonts.heading)
                            .tracking(6)
                            .foregroundStyle(Theme.gold)
                        if let blurb = event.newRank.unlockBlurb {
                            Text(blurb)
                                .font(Fonts.caption)
                                .tracking(1.5)
                                .foregroundStyle(Theme.mutedGold)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    .opacity(contentOpacity)
                } else {
                    Text(event.newRank.rawValue.uppercased())
                        .font(Fonts.title)
                        .tracking(4)
                        .foregroundStyle(Theme.mutedGold)
                        .opacity(contentOpacity)
                }

                Spacer()

                Text("TAP TO CONTINUE")
                    .font(Fonts.micro)
                    .tracking(3)
                    .foregroundStyle(Theme.mutedGold)
                    .opacity(contentOpacity)

                Spacer().frame(height: 40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .task {
            // Rank crossings get the more elaborate pattern; level-only crossings get the lighter one.
            if event.rankChanged {
                HapticEngine.shared.rankUp()
            } else {
                HapticEngine.shared.levelUp()
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                badgeScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.25)) {
                contentOpacity = 1.0
            }
        }
    }
}

#Preview("Level up only") {
    LevelUpOverlay(
        event: LevelUpEvent(newLevel: 4, newRank: .veera, rankChanged: false),
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Level + rank up") {
    LevelUpOverlay(
        event: LevelUpEvent(newLevel: 5, newRank: .maravan, rankChanged: true),
        onDismiss: {}
    )
    .preferredColorScheme(.dark)
}
