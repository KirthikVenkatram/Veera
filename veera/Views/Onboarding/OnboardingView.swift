import SwiftData
import SwiftUI

// Shown on first launch (after biometric unlock) — introduces the app's concepts
// and lets the user pick a starting difficulty. Stamps a flag in @AppStorage on completion
// so it never re-appears. Can be replayed from Settings.
struct OnboardingView: View {
    let onComplete: (Difficulty) -> Void

    @State private var page: Int = 0
    @State private var chosenDifficulty: Difficulty = .soft

    private let totalPages = 4

    var body: some View {
        ZStack {
            Theme.obsidian.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage.tag(0)
                    statsPage.tag(1)
                    ranksPage.tag(2)
                    difficultyPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                PageIndicator(current: page, total: totalPages)
                    .padding(.bottom, 16)

                bottomControl
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        OnboardingPage(
            icon: "crown.fill",
            eyebrow: "WELCOME",
            title: "VEERA",
            copy: "A personal kingdom of habits. Every day you forge yourself a little stronger."
        )
    }

    private var statsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("THE FIVE STATS")
                .labelStyle()

            Text("Earn points across each as you complete quests.")
                .font(Fonts.body)
                .foregroundStyle(Theme.parchment)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            HStack(spacing: 18) {
                ForEach(StatCategory.allCases) { stat in
                    VStack(spacing: 6) {
                        Image(systemName: stat.symbol)
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.gold)
                        Text(stat.rawValue)
                            .font(Fonts.micro)
                            .tracking(1.5)
                            .foregroundStyle(Theme.mutedGold)
                    }
                    .frame(width: 50)
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            .roundedCard()
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var ranksPage: some View {
        VStack(spacing: 18) {
            Spacer()

            Text("THE LADDER OF RANKS")
                .labelStyle()

            Text("Climb from Veera to Maaveeran.")
                .font(Fonts.body)
                .foregroundStyle(Theme.parchment)
                .multilineTextAlignment(.center)

            // Onboarding only ever shows the 5 visible ranks plus a single
            // mystery row. We never reveal how many secret ranks remain.
            VStack(spacing: 8) {
                ForEach(Rank.allCases.filter { !$0.isSecret }) { rank in
                    HStack {
                        Text(rank.rawValue.uppercased())
                            .font(Fonts.title)
                            .tracking(3)
                            .foregroundStyle(rank == .maaveeran ? Theme.gold : Theme.parchment)
                        Spacer()
                        Text(rank.romanLevelRange)
                            .font(Fonts.caption)
                            .tracking(1.5)
                            .foregroundStyle(Theme.mutedGold)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .roundedCard()
                }

                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.mutedGold)
                    Text("THE PATH BEYOND…")
                        .font(Fonts.title)
                        .tracking(3)
                        .foregroundStyle(Theme.mutedGold)
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .roundedCard()
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private var difficultyPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("CHOOSE YOUR PATH")
                .labelStyle()

            Text("You can switch this any time in Settings.")
                .font(Fonts.body)
                .foregroundStyle(Theme.parchment)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                DifficultyChoice(
                    isSelected: chosenDifficulty == .soft,
                    title: "SOFT",
                    detail: "Missed days reset the streak. No XP is lost."
                ) {
                    chosenDifficulty = .soft
                }

                DifficultyChoice(
                    isSelected: chosenDifficulty == .hard,
                    title: "HARD",
                    detail: "Missed days reset the streak AND deduct XP."
                ) {
                    chosenDifficulty = .hard
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Bottom control

    @ViewBuilder
    private var bottomControl: some View {
        if page == totalPages - 1 {
            Button {
                onComplete(chosenDifficulty)
            } label: {
                Text("ENTER THE REALM")
                    .font(Fonts.bodyBold)
                    .tracking(3)
                    .foregroundStyle(Theme.obsidian)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.gold)
                    .clipShape(Capsule())
            }
            .buttonStyle(.royal)
        } else {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    page += 1
                }
            } label: {
                Text("CONTINUE")
                    .font(Fonts.bodyBold)
                    .tracking(3)
                    .foregroundStyle(Theme.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .interactiveGlassCard()
            }
            .buttonStyle(.royal)
        }
    }

}

// MARK: - Page primitives

private struct OnboardingPage: View {
    let icon: String
    let eyebrow: String
    let title: String
    let copy: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Rectangle()
                    .stroke(Theme.gold, lineWidth: 1.5)
                    .background(Rectangle().fill(Theme.surface))
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(45))

                Image(systemName: icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }
            .frame(width: 88 * 1.414, height: 88 * 1.414)
            .shadow(color: Theme.gold.opacity(0.3), radius: 20)

            Text(eyebrow).labelStyle()

            Text(title)
                .font(Fonts.heading)
                .tracking(10)
                .foregroundStyle(Theme.gold)

            Text(copy)
                .font(Fonts.body)
                .foregroundStyle(Theme.parchment)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer()
        }
    }
}

private struct DifficultyChoice: View {
    let isSelected: Bool
    let title: String
    let detail: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Theme.gold, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(Theme.gold)
                            .frame(width: 14, height: 14)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Fonts.title)
                        .tracking(3)
                        .foregroundStyle(isSelected ? Theme.gold : Theme.parchment)
                    Text(detail)
                        .font(Fonts.caption)
                        .tracking(1)
                        .foregroundStyle(Theme.mutedGold)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .roundedCard()
        }
        .buttonStyle(.royal)
    }
}

private struct PageIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Theme.gold : Theme.border)
                    .frame(width: index == current ? 20 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

#Preview {
    OnboardingView { _ in }
        .preferredColorScheme(.dark)
}
