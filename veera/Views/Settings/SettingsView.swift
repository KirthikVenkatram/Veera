import EventKit
import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var players: [Player]
    @Query(
        filter: #Predicate<Habit> { !$0.isArchived },
        sort: \Habit.createdAt, order: .forward
    )
    private var habits: [Habit]

    @AppStorage("veera.onboardingCompleted") private var onboardingCompleted = false
    @AppStorage(NotificationService.hideLockScreenContentKey) private var hideLockScreenContent = true
    @State private var editedName = ""
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var resetConfirmationPresented = false

    private var player: Player? { players.first }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.obsidian.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.gold.opacity(0.14), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 340
                )
                .ignoresSafeArea(edges: .top)
                .frame(height: 340)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if let player {
                            PlayerSummaryCard(player: player)
                            NameEditorCard(name: $editedName) {
                                saveName(for: player)
                            }
                            ProgressCard(totalXP: player.totalXP)
                            PenaltyCard(
                                difficulty: difficultyBinding(for: player),
                                onApply: { applyMissedDayCheck(for: player) }
                            )
                        }
                        NotificationStatusCard(status: notificationStatus) {
                            await handleNotificationCardTap()
                        }
                        NotificationPrivacyCard(hide: $hideLockScreenContent)
                            .onChange(of: hideLockScreenContent) {
                                Task { await NotificationService.rescheduleAll(in: context) }
                            }
                        HealthAutoXPCard()
                        EventKitMirrorCard()
                        HapticsCard()
                        ReplayOnboardingCard {
                            onboardingCompleted = false
                        }
                        DangerZoneCard {
                            resetConfirmationPresented = true
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Settings")
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(Theme.gold)
            .task {
                if let player { editedName = player.displayName }
                await refreshNotificationStatus()
            }
            .confirmationDialog(
                "Erase all habits, tasks, reminders, and progress?",
                isPresented: $resetConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    Task { await PersistenceController.resetLocalData(in: context) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone. A fresh empty Player will be created.")
            }
        }
    }

    // MARK: - Actions

    private func difficultyBinding(for player: Player) -> Binding<Difficulty> {
        Binding(
            get: { player.difficulty },
            set: { newValue in
                player.difficulty = newValue
                try? context.save()
            }
        )
    }

    private func saveName(for player: Player) {
        let cleanName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        player.displayName = cleanName
        try? context.save()
    }

    private func applyMissedDayCheck(for player: Player) {
        StreakEngine.applyMissedDayIfNeeded(for: player, habits: habits)
        try? context.save()
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    private func handleNotificationCardTap() async {
        switch notificationStatus {
        case .notDetermined:
            // First time: ask iOS to show the system permission prompt.
            await NotificationService.requestAuthorization()
            await refreshNotificationStatus()
        case .denied:
            // Already denied: only iOS Settings can re-enable. Deep-link there.
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
        default:
            break
        }
    }
}

// MARK: - Player summary

private struct PlayerSummaryCard: View {
    let player: Player

    private var level: Int { XPEngine.level(for: player.totalXP) }
    private var rank: Rank { Rank.rank(forLevel: level) }

    var body: some View {
        HStack(spacing: 16) {
            LevelBadge(level: level, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("SOVEREIGN")
                    .font(Fonts.micro)
                    .tracking(2.5)
                    .foregroundStyle(Theme.mutedGold)
                Text(player.displayName.uppercased())
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .tracking(3)
                    .foregroundStyle(Theme.parchment)
                Text(rank.rawValue.uppercased())
                    .font(Fonts.caption)
                    .tracking(2.5)
                    .foregroundStyle(Theme.gold)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(player.totalXP)")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.gold)
                Text("XP TOTAL")
                    .font(Fonts.micro)
                    .tracking(2)
                    .foregroundStyle(Theme.mutedGold)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .heroCard()
    }
}

// MARK: - Name editor

private struct NameEditorCard: View {
    @Binding var name: String
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NAME").labelStyle()

            TextField("Name", text: $name)
                .font(Fonts.bodyBold)
                .foregroundStyle(Theme.parchment)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.obsidian)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassCard()
    }
}

// MARK: - Progress

private struct ProgressCard: View {
    let totalXP: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PROGRESS").labelStyle()
                Spacer()
                Text("\(XPEngine.xpRemainingInCurrentLevel(totalXP: totalXP)) XP TO NEXT")
                    .font(Fonts.micro)
                    .tracking(1.5)
                    .foregroundStyle(Theme.mutedGold)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.obsidian)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.gold)
                        .frame(width: max(8, geo.size.width * XPEngine.progressThroughCurrentLevel(totalXP: totalXP)))
                }
            }
            .frame(height: 10)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassCard()
    }
}

// MARK: - Penalty

private struct PenaltyCard: View {
    @Binding var difficulty: Difficulty
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PENALTY MODE").labelStyle()

            Picker("Mode", selection: $difficulty) {
                ForEach(Difficulty.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(difficulty == .soft
                 ? "Soft: missed days reset the streak. No XP is lost."
                 : "Hard: missed days reset the streak AND deduct XP per missed habit.")
                .font(Fonts.caption)
                .tracking(1)
                .foregroundStyle(Theme.mutedGold)

            Button(action: onApply) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                    Text("Run Missed-Day Check")
                        .font(Fonts.bodyBold)
                }
                .foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .interactiveGlassCard()
            }
            .buttonStyle(.royal)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassCard()
    }
}

// MARK: - Notification status

private struct NotificationStatusCard: View {
    let status: UNAuthorizationStatus
    let onTap: () async -> Void

    private var displayText: String {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return "Enabled"
        case .denied:
            return "Denied — tap to open iOS Settings"
        case .notDetermined:
            return "Tap to enable"
        @unknown default:
            return "Unknown"
        }
    }

    private var tone: Color {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return Theme.gold
        case .denied:
            return Theme.red
        default:
            return Theme.mutedGold
        }
    }

    private var isActionable: Bool {
        status == .notDetermined || status == .denied
    }

    var body: some View {
        Button {
            Task { await onTap() }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tone.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tone)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("NOTIFICATIONS").labelStyle()
                    Text(displayText)
                        .font(Fonts.body)
                        .foregroundStyle(Theme.parchment)
                }

                Spacer()

                if isActionable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.mutedGold)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .glassCard()
        }
        .buttonStyle(.royal)
        .disabled(!isActionable)
    }
}

// MARK: - Notification privacy

private struct NotificationPrivacyCard: View {
    @Binding var hide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                SettingCardIcon("eye.slash.fill")

                VStack(alignment: .leading, spacing: 2) {
                    Text("LOCK SCREEN PRIVACY").labelStyle()
                    Text("Hide reminder content on lock screen")
                        .font(Fonts.body)
                        .foregroundStyle(Theme.parchment)
                }

                Spacer()

                Toggle("", isOn: $hide)
                    .labelsHidden()
                    .tint(Theme.gold)
            }

            Text(hide
                 ? "Lock screen shows \"Veera · A quest awaits.\" Real reminder title and body open inside the app."
                 : "Lock screen shows the full reminder title and body.")
                .font(Fonts.caption)
                .tracking(1)
                .foregroundStyle(Theme.mutedGold)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassCard()
    }
}

// MARK: - Health auto-XP

private struct HealthAutoXPCard: View {
    @AppStorage(HealthKitImporter.stepsToggleKey) private var steps = false
    @AppStorage(HealthKitImporter.sleepToggleKey) private var sleep = false
    @AppStorage(HealthKitImporter.mindfulToggleKey) private var mindfulness = false
    @AppStorage(HealthKitImporter.workoutsToggleKey) private var workouts = false

    // HealthKit hides read-authorization; on enable we probe and show a soft hint.
    @State private var showAccessHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                SettingCardIcon("heart.text.square")
                VStack(alignment: .leading, spacing: 2) {
                    Text("AUTO-XP · HEALTH").labelStyle()
                    Text("Read-only. Daily summaries, never leaves device.")
                        .font(Fonts.caption)
                        .tracking(1)
                        .foregroundStyle(Theme.mutedGold)
                }
                Spacer()
            }

            toggleRow("Steps → STR", isOn: $steps)
            toggleRow("Sleep → VIT", isOn: $sleep)
            toggleRow("Mindful minutes → DSC", isOn: $mindfulness)
            toggleRow("Workouts → STR+VIT", isOn: $workouts)

            if showAccessHint {
                PermissionNote(text: "Veera couldn't access Health — check Settings.", soft: true)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassCard()
        .onChange(of: steps) { _, on in if on { Task { await probeAccess() } } }
        .onChange(of: sleep) { _, on in if on { Task { await probeAccess() } } }
        .onChange(of: mindfulness) { _, on in if on { Task { await probeAccess() } } }
        .onChange(of: workouts) { _, on in if on { Task { await probeAccess() } } }
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .font(Fonts.body)
                .foregroundStyle(Theme.parchment)
        }
        .tint(Theme.gold)
    }

    // Raise the hint only when Health is unavailable or the request errors —
    // never claiming the user explicitly denied (HealthKit hides that).
    private func probeAccess() async {
        guard HealthKitImporter.isAvailable else { showAccessHint = true; return }
        do {
            try await HealthKitImporter.requestPermissions()
            showAccessHint = false
        } catch { showAccessHint = true }
    }
}

// MARK: - EventKit mirror

private struct EventKitMirrorCard: View {
    @Environment(\.modelContext) private var context
    @AppStorage(EventKitExporter.habitToggleKey) private var mirrorHabits = false
    @AppStorage(EventKitExporter.taskToggleKey) private var mirrorTasks = false

    // EventKit exposes a real status — reflect a hard denial and reset revoked toggles.
    @State private var remindersDenied = false
    @State private var eventsDenied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                SettingCardIcon("calendar.badge.plus")
                VStack(alignment: .leading, spacing: 2) {
                    Text("APPLE CALENDAR & REMINDERS").labelStyle()
                    Text("One-way push. Deleting in Veera removes the mirror. Deleting in Apple Reminders does not affect Veera.")
                        .font(Fonts.caption)
                        .tracking(1)
                        .foregroundStyle(Theme.mutedGold)
                }
                Spacer()
            }

            Toggle("Mirror to Apple Reminders", isOn: $mirrorHabits)
                .font(Fonts.body).foregroundStyle(Theme.parchment).tint(Theme.gold)
            if remindersDenied {
                PermissionNote(text: "Reminders access denied.")
            }

            Toggle("Mirror task deadlines to Calendar", isOn: $mirrorTasks)
                .font(Fonts.body).foregroundStyle(Theme.parchment).tint(Theme.gold)
            if eventsDenied {
                PermissionNote(text: "Calendar access denied.")
            }

            Button {
                Task { await EventKitExporter.resyncAll(in: context) }
            } label: {
                Text("RE-SYNC ALL")
                    .font(Fonts.bodyBold).tracking(2).foregroundStyle(Theme.gold)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .interactiveGlassCard()
            }
            .buttonStyle(.royal)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassCard()
        .task { reflectStatus() }
        .onChange(of: mirrorHabits) { _, on in if on { Task { await enableReminders() } } }
        .onChange(of: mirrorTasks) { _, on in if on { Task { await enableEvents() } } }
    }

    // Reconcile stored toggles with live status so none reads "on" after revoke.
    private func reflectStatus() {
        remindersDenied = isDenied(EKEventStore.authorizationStatus(for: .reminder))
        eventsDenied = isDenied(EKEventStore.authorizationStatus(for: .event))
        if remindersDenied && mirrorHabits { mirrorHabits = false }
        if eventsDenied && mirrorTasks { mirrorTasks = false }
    }
    private func isDenied(_ status: EKAuthorizationStatus) -> Bool {
        status == .denied || status == .restricted
    }
    private func enableReminders() async {
        remindersDenied = await EventKitExporter.requestReminders() == false
        if remindersDenied { mirrorHabits = false }
    }
    private func enableEvents() async {
        eventsDenied = await EventKitExporter.requestEvents() == false
        if eventsDenied { mirrorTasks = false }
    }
}

// MARK: - Shared bits

// Gold rounded-square icon badge shared across setting cards.
private struct SettingCardIcon: View {
    let systemName: String
    init(_ systemName: String) { self.systemName = systemName }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.gold.opacity(0.12))
                .frame(width: 38, height: 38)
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
    }
}

// Inline denied note + Open-Settings link. `soft` softens the red styling for HealthKit.
private struct PermissionNote: View {
    let text: String
    var soft = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: soft ? "info.circle" : "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(soft ? Theme.mutedGold : Theme.red)
            Text(text)
                .font(Fonts.caption)
                .tracking(1)
                .foregroundStyle(soft ? Theme.parchment : Theme.red)
            Spacer(minLength: 8)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Task { await UIApplication.shared.open(url) }
                }
            } label: {
                Text("OPEN SETTINGS")
                    .font(Fonts.micro)
                    .tracking(1.5)
                    .foregroundStyle(Theme.gold)
            }
            .buttonStyle(.royal)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
    }
}

// MARK: - Haptics

private struct HapticsCard: View {
    @AppStorage("veera.haptics.enabled") private var enabled = true

    var body: some View {
        HStack(spacing: 14) {
            SettingCardIcon("waveform")
            VStack(alignment: .leading, spacing: 2) {
                Text("HAPTICS").labelStyle()
                Text("Reserved for meaningful events.")
                    .font(Fonts.body)
                    .foregroundStyle(Theme.parchment)
            }
            Spacer()
            Toggle("", isOn: $enabled).labelsHidden().tint(Theme.gold)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassCard()
    }
}

// MARK: - Replay onboarding

private struct ReplayOnboardingCard: View {
    let onReplay: () -> Void

    var body: some View {
        Button(action: onReplay) {
            HStack(spacing: 14) {
                SettingCardIcon("crown")

                VStack(alignment: .leading, spacing: 2) {
                    Text("REPLAY INTRO").labelStyle()
                    Text("Walk through the realm's tour again")
                        .font(Fonts.body)
                        .foregroundStyle(Theme.parchment)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.mutedGold)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .glassCard()
        }
        .buttonStyle(.royal)
    }
}

// MARK: - Danger zone

private struct DangerZoneCard: View {
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DANGER ZONE").labelStyle()

            Text("Erases all habits, tasks, reminders, completions, and XP. The Player is rebuilt from scratch.")
                .font(Fonts.caption)
                .tracking(1)
                .foregroundStyle(Theme.mutedGold)

            Button(action: onReset) {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text("Reset Local Data")
                        .font(Fonts.bodyBold)
                }
                .foregroundStyle(Theme.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .fill(Theme.red.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .stroke(Theme.red.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.royal)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .glassCard()
    }
}

#Preview {
    let schema = Schema([
        Player.self, Habit.self, HabitCompletion.self, TaskItem.self, Reminder.self
    ])
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let player = Player(displayName: "Kirthik", totalXP: 1240, difficulty: .hard)
    container.mainContext.insert(player)

    return SettingsView()
        .preferredColorScheme(.dark)
        .modelContainer(container)
}
