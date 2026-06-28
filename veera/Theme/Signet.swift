import SwiftUI

// The Veera signet — gold rotated-square emblem with a centered serif "V".
// Shared visual primitive used by the onboarding intro, the lock-screen splash
// (when it existed), and intended for the launch screen / future hero spots.
//
// The launch screen itself is generated from build settings (UILaunchScreen
// keys in Info.plist). To wire this asset to the launch screen, add a 1024×1024
// "LaunchSignet" image set under Assets.xcassets and set
// `INFOPLIST_KEY_UILaunchScreen_ImageName = LaunchSignet` plus
// `INFOPLIST_KEY_UILaunchScreen_BackgroundColor = LaunchBackground` in target
// build settings — that's a manual Xcode UI step, not a code change.
struct Signet: View {
    var size: CGFloat = 88
    var showsGlow: Bool = false

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Theme.gold, lineWidth: 1.5)
                .background(Rectangle().fill(Theme.surface))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(45))

            Text("V")
                .font(.system(size: size * 0.42, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.gold)
                .offset(y: size * -0.04)   // optical centering — V is top-heavy
        }
        .frame(width: size * 1.414, height: size * 1.414)
        .shadow(color: Theme.gold.opacity(showsGlow ? 0.4 : 0), radius: showsGlow ? 22 : 0)
    }
}

#Preview {
    HStack(spacing: 24) {
        Signet(size: 60)
        Signet(size: 88, showsGlow: true)
    }
    .padding()
    .background(Theme.obsidian)
    .preferredColorScheme(.dark)
}
