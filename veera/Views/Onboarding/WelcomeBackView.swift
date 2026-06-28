import SwiftUI

// Brief greeting shown on cold launch (after biometric unlock) once the user has
// already completed onboarding. Auto-dismisses after `dwell` seconds.
// Skipped on warm restarts because the parent's @State persists across re-locks.
struct WelcomeBackView: View {
    let name: String
    let onComplete: () -> Void

    var dwell: Duration = .milliseconds(1400)

    @State private var emblemScale: CGFloat = 0.7
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Theme.obsidian.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                ZStack {
                    Rectangle()
                        .stroke(Theme.gold, lineWidth: 1.5)
                        .background(Rectangle().fill(Theme.surface))
                        .frame(width: 78, height: 78)
                        .rotationEffect(.degrees(45))

                    Image(systemName: "crown.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }
                .frame(width: 78 * 1.414, height: 78 * 1.414)
                .scaleEffect(emblemScale)
                .shadow(color: Theme.gold.opacity(0.4), radius: 22)

                VStack(spacing: 6) {
                    Text("WELCOME BACK").labelStyle()
                    Text(name.uppercased())
                        .font(Fonts.heading)
                        .tracking(8)
                        .foregroundStyle(Theme.gold)
                }
                .opacity(contentOpacity)

                Spacer()
            }
        }
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                emblemScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.35).delay(0.15)) {
                contentOpacity = 1.0
            }

            try? await Task.sleep(for: dwell)

            withAnimation(.easeOut(duration: 0.35)) {
                contentOpacity = 0
                emblemScale = 0.9
            }
            try? await Task.sleep(for: .milliseconds(350))
            onComplete()
        }
    }
}

#Preview {
    WelcomeBackView(name: "Kirthik") {}
        .preferredColorScheme(.dark)
}
