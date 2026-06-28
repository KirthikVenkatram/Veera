import SwiftData
import SwiftUI

struct ContentView: View {
    @AppStorage("veera.onboardingCompleted") private var onboardingCompleted = false
    @Environment(\.modelContext) private var context
    @Query private var players: [Player]

    // Tracks whether we've shown the per-session greeting yet.
    // @State resets on cold launch only, so warm restarts (e.g. tab back
    // from Control Center) don't re-trigger the splash.
    @State private var hasGreeted = false

    @State private var selectedTab: Int = 0

    var body: some View {
        if !onboardingCompleted {
            OnboardingView { difficulty in
                if let player = players.first {
                    player.difficulty = difficulty
                    try? context.save()
                }
                onboardingCompleted = true
                // First-launch onboarding *is* the greeting — don't double up.
                hasGreeted = true
            }
        } else if !hasGreeted {
            WelcomeBackView(name: players.first?.displayName ?? "Veera") {
                hasGreeted = true
            }
        } else {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label("Today", systemImage: "crown.fill") }
                    .tag(0)

                QuestsView()
                    .tabItem { Label("Quests", systemImage: "scroll.fill") }
                    .tag(1)

                CalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                    .tag(2)

                StatsView()
                    .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                    .tag(3)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(4)
            }
            .tint(Theme.gold)
            .onChange(of: selectedTab) { HapticEngine.shared.tabChange() }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
        .modelContainer(
            for: [
                Player.self, Habit.self, HabitCompletion.self, TaskItem.self, Reminder.self,
                RankAchievement.self, Vow.self, VowCheckIn.self
            ],
            inMemory: true
        )
}
