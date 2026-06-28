import SwiftData
import SwiftUI

// "Sacred Vows" section — lives in the Quests tab. Swearing new vows and the
// daily Yes/No both happen here. Home shows the same active vows via `VowStage`
// (center-stage hero treatment) but without the add affordance.
struct VowsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Vow.startDate, order: .reverse) private var vows: [Vow]

    @State private var addPresented = false
    @State private var pendingBreak: Vow?

    private var visible: [Vow] {
        vows.filter { $0.isActive || $0.isBroken && Date.now <= $0.endDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SACRED VOWS").labelStyle()
                Spacer()
                Button { addPresented = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.gold)
                }
                .buttonStyle(.royal)
            }

            if visible.isEmpty {
                Text("No vows currently sworn.")
                    .font(Fonts.body)
                    .foregroundStyle(Theme.dim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 18)
                    .roundedCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(visible) { vow in
                        VowCard(
                            vow: vow,
                            onKeep: { recordCheckIn(for: vow, kept: true) },
                            onBreak: { pendingBreak = vow }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $addPresented) { AddVowView() }
        .fullScreenCover(item: $pendingBreak) { vow in
            VowBrokenOverlay(vow: vow) {
                breakVow(vow)
                pendingBreak = nil
            }
        }
    }

    private func recordCheckIn(for vow: Vow, kept: Bool) {
        if vow.checkIn() != nil { return }
        context.insert(VowCheckIn(vow: vow, kept: kept))
        try? context.save()
    }

    private func breakVow(_ vow: Vow) {
        vow.isBroken = true
        vow.brokenAt = .now
        context.insert(VowCheckIn(vow: vow, kept: false))
        try? context.save()
    }
}

// MARK: - Vow stage (Home center stage)

// The featured vow display on Home. Active vows get a heraldic banner + hero
// cards above the quest list. No add button — new vows are sworn from Quests.
// Hidden entirely when no vows are active, so Home stays uncluttered.
struct VowStage: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Vow.startDate, order: .reverse) private var vows: [Vow]

    @State private var pendingBreak: Vow?

    private var visible: [Vow] {
        vows.filter { $0.isActive || $0.isBroken && Date.now <= $0.endDate }
    }

    var body: some View {
        if !visible.isEmpty {
            VStack(spacing: 14) {
                HeraldicBanner(title: "Sacred Vow")
                VStack(spacing: 12) {
                    ForEach(visible) { vow in
                        VowCard(
                            vow: vow,
                            prominent: true,
                            onKeep: { recordCheckIn(for: vow, kept: true) },
                            onBreak: { pendingBreak = vow }
                        )
                    }
                }
            }
            .fullScreenCover(item: $pendingBreak) { vow in
                VowBrokenOverlay(vow: vow) {
                    breakVow(vow)
                    pendingBreak = nil
                }
            }
        }
    }

    private func recordCheckIn(for vow: Vow, kept: Bool) {
        if vow.checkIn() != nil { return }
        context.insert(VowCheckIn(vow: vow, kept: kept))
        try? context.save()
    }

    private func breakVow(_ vow: Vow) {
        vow.isBroken = true
        vow.brokenAt = .now
        context.insert(VowCheckIn(vow: vow, kept: false))
        try? context.save()
    }
}

// MARK: - Vow card

struct VowCard: View {
    let vow: Vow
    var prominent = false
    let onKeep: () -> Void
    let onBreak: () -> Void

    private var todaysCheckIn: VowCheckIn? { vow.checkIn() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vow.title)
                        .font(prominent ? .system(size: 20, weight: .semibold, design: .serif) : Fonts.bodyBold)
                        .foregroundStyle(Theme.parchment)
                    Text(vow.body)
                        .font(Fonts.caption)
                        .foregroundStyle(Theme.mutedGold)
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(vow.daysRemaining)")
                        .font(.system(size: prominent ? 32 : 22, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.gold)
                    Text("DAYS LEFT")
                        .font(Fonts.micro)
                        .tracking(1.5)
                        .foregroundStyle(Theme.mutedGold)
                }
            }

            if vow.isBroken {
                BrokenSeal()
            } else if let check = todaysCheckIn {
                HStack {
                    Image(systemName: check.kept ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .foregroundStyle(check.kept ? Theme.gold : Theme.red)
                    Text(check.kept ? "Kept today" : "Broken today")
                        .font(Fonts.caption)
                        .foregroundStyle(check.kept ? Theme.gold : Theme.red)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Did you keep this vow today?")
                        .font(Fonts.caption)
                        .foregroundStyle(Theme.parchment)
                    HStack(spacing: 8) {
                        Button(action: onKeep) {
                            Text("YES")
                                .font(Fonts.bodyBold)
                                .tracking(2)
                                .foregroundStyle(Theme.obsidian)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.gold)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.royal)
                        Button(action: onBreak) {
                            Text("NO")
                                .font(Fonts.bodyBold)
                                .tracking(2)
                                .foregroundStyle(Theme.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.red.opacity(0.12))
                                .overlay(Capsule().stroke(Theme.red.opacity(0.5), lineWidth: 1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.royal)
                    }
                }
            }
        }
        .padding(.vertical, prominent ? 18 : 14)
        .padding(.horizontal, 16)
        .modifier(VowCardBackground(prominent: prominent))
    }
}

private struct VowCardBackground: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content.heroCard()
        } else {
            content.roundedCard()
        }
    }
}

// MARK: - Broken seal

private struct BrokenSeal: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.red.opacity(0.25))
                    .frame(width: 32, height: 32)
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.red)
            }
            Text("VOW BROKEN")
                .font(Fonts.micro)
                .tracking(2)
                .foregroundStyle(Theme.red)
            Spacer()
        }
    }
}

// MARK: - Broken overlay

struct VowBrokenOverlay: View {
    let vow: Vow
    let onAcknowledge: () -> Void

    @State private var sealScale: CGFloat = 0.4
    @State private var sealOpacity: Double = 0

    var body: some View {
        ZStack {
            Theme.obsidian.opacity(0.97).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Theme.red.opacity(0.35))
                        .frame(width: 140, height: 140)
                    Image(systemName: "xmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(Theme.red)
                }
                .scaleEffect(sealScale)
                .opacity(sealOpacity)
                .shadow(color: Theme.red.opacity(0.5), radius: 28)

                Text("THE VOW IS BROKEN")
                    .font(Fonts.heading)
                    .tracking(6)
                    .foregroundStyle(Theme.red)

                Text("A red seal will mark this vow for the remaining days.")
                    .font(Fonts.body)
                    .foregroundStyle(Theme.parchment)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Spacer()
                Button(action: onAcknowledge) {
                    Text("ACKNOWLEDGE")
                        .font(Fonts.bodyBold)
                        .tracking(3)
                        .foregroundStyle(Theme.obsidian)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.gold)
                        .clipShape(Capsule())
                }
                .buttonStyle(.royal)
                .padding(.horizontal, 32)
                .padding(.bottom, 36)
            }
        }
        .task {
            HapticEngine.shared.vowBroken()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                sealScale = 1.0
                sealOpacity = 1.0
            }
        }
    }
}
