import OSLog
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var players: [Player]
    @Query(
        filter: #Predicate<Habit> { !$0.isArchived },
        sort: \Habit.createdAt, order: .forward
    )
    private var habits: [Habit]
    @Query(sort: \TaskItem.createdAt, order: .forward)
    private var tasks: [TaskItem]
    // Bounded to today only — Home just needs xpToday and pending counts.
    // Unbounded fetches across the whole history is wasteful.
    @Query(filter: Self.todayPredicate, sort: \HabitCompletion.completedAt, order: .reverse)
    private var completions: [HabitCompletion]

    private static let todayPredicate: Predicate<HabitCompletion> = {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? .now
        return #Predicate<HabitCompletion> { $0.completedAt >= start && $0.completedAt < end }
    }()

    @State private var pendingLevelUp: LevelUpEvent?

    private var player: Player? { players.first }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.obsidian.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.gold.opacity(0.16), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 380
                )
                .ignoresSafeArea(edges: .top)
                .frame(height: 380)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if let player {
                            PlayerCard(player: player)
                            StatRow(player: player)
                        }

                        DailyTotalsRow(
                            streak: player?.currentStreak ?? 0,
                            xpToday: xpToday,
                            pending: pendingCount
                        )

                        VowStage()

                        QuestList(
                            habits: habitsDueToday,
                            tasks: openTasks,
                            onCompleteHabit: toggleHabit,
                            onCompleteTask: toggleTask
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habit: habit)
            }
        }
        .task(id: player?.id) {
            guard let player else { return }
            StreakEngine.applyMissedDayIfNeeded(for: player, habits: Array(habits))
            try? context.save()
        }
        .fullScreenCover(item: $pendingLevelUp) { event in
            LevelUpOverlay(event: event) {
                pendingLevelUp = nil
            }
        }
    }

    // MARK: - Derived state

    private var habitsDueToday: [Habit] {
        habits.filter { $0.cadence.isDue(on: .now) }
    }

    private var openTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }
    }

    private var xpToday: Int {
        let calendar = Calendar.current
        return completions
            .filter { calendar.isDateInToday($0.completedAt) }
            .reduce(0) { $0 + $1.xpAwarded }
    }

    private var pendingCount: Int {
        let openHabits = habitsDueToday.filter { !$0.isCompleted(on: .now) }.count
        return openHabits + openTasks.count
    }

    // MARK: - Actions

    private func toggleHabit(_ habit: Habit) {
        if habit.isCompleted(on: .now) {
            undoHabit(habit)
        } else {
            completeHabit(habit)
        }
    }

    private func completeHabit(_ habit: Habit) {
        let levelBefore = player.map { XPEngine.level(for: $0.totalXP) } ?? 1
        let rankBefore = Rank.rank(forLevel: levelBefore)

        let completion = HabitCompletion(habit: habit, xpAwarded: habit.xpReward)
        context.insert(completion)
        if let player {
            XPEngine.awardHabit(habit, to: player)
            StreakEngine.recordActivity(for: player)
        }
        try? context.save()
        HapticEngine.shared.quest(.complete)
        AppLogger.questActions.info("habit.complete name=\(habit.name, privacy: .private) cat=\(habit.category.rawValue, privacy: .public) xp=\(habit.xpReward, privacy: .public)")
        detectLevelUp(from: levelBefore, oldRank: rankBefore)
    }

    private func undoHabit(_ habit: Habit) {
        // Find today's completion(s) for this habit and roll them back.
        // There should normally be exactly one, but we delete all defensively
        // in case of bad data.
        let calendar = Calendar.current
        let todaysCompletions = habit.completions.filter {
            calendar.isDateInToday($0.completedAt)
        }
        for completion in todaysCompletions {
            context.delete(completion)
        }
        if let player {
            XPEngine.revokeHabit(habit, from: player)
            // Rebuild streak from what's actually on disk now. If this was the
            // last activity of the day, the streak drops back to where it was
            // before this completion bumped it.
            StreakEngine.rebuildStreak(for: player, in: context)
        }
        try? context.save()
        HapticEngine.shared.quest(.uncomplete)
        AppLogger.questActions.info("habit.undo name=\(habit.name, privacy: .private) cat=\(habit.category.rawValue, privacy: .public) xp=\(habit.xpReward, privacy: .public)")
    }

    private func toggleTask(_ task: TaskItem) {
        if task.isCompleted {
            undoTask(task)
        } else {
            completeTask(task)
        }
    }

    private func completeTask(_ task: TaskItem) {
        let levelBefore = player.map { XPEngine.level(for: $0.totalXP) } ?? 1
        let rankBefore = Rank.rank(forLevel: levelBefore)

        task.isCompleted = true
        task.completedAt = .now
        if let player {
            XPEngine.awardTask(task, to: player)
            StreakEngine.recordActivity(for: player)
        }
        try? context.save()
        HapticEngine.shared.quest(.complete)
        AppLogger.questActions.info("task.complete title=\(task.title, privacy: .private) cat=\(task.category.rawValue, privacy: .public) xp=\(task.xpReward, privacy: .public)")
        detectLevelUp(from: levelBefore, oldRank: rankBefore)
    }

    private func undoTask(_ task: TaskItem) {
        task.isCompleted = false
        task.completedAt = nil
        if let player {
            XPEngine.revokeTask(task, from: player)
            StreakEngine.rebuildStreak(for: player, in: context)
        }
        try? context.save()
        HapticEngine.shared.quest(.uncomplete)
        AppLogger.questActions.info("task.undo title=\(task.title, privacy: .private) cat=\(task.category.rawValue, privacy: .public) xp=\(task.xpReward, privacy: .public)")
    }

    private func detectLevelUp(from oldLevel: Int, oldRank: Rank) {
        guard let player else { return }
        let newLevel = XPEngine.level(for: player.totalXP)
        let newRank = Rank.rank(forLevel: newLevel)
        guard newLevel > oldLevel else { return }
        if newRank != oldRank {
            // Record going forward only — pre-Phase-3 ranks aren't backfilled.
            StatsAggregator.recordRankIfNeeded(newRank, in: context)
        }
        pendingLevelUp = LevelUpEvent(
            newLevel: newLevel,
            newRank: newRank,
            rankChanged: newRank != oldRank
        )
    }
}

// MARK: - Player card

private struct PlayerCard: View {
    let player: Player

    private var level: Int { XPEngine.level(for: player.totalXP) }
    private var rank: Rank { Rank.rank(forLevel: level) }
    private var progress: Double { XPEngine.progressThroughCurrentLevel(totalXP: player.totalXP) }
    private var xpToNext: Int { XPEngine.xpRemainingInCurrentLevel(totalXP: player.totalXP) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.gold)
                    Text("XP TOTAL")
                        .font(Fonts.micro)
                        .tracking(2)
                        .foregroundStyle(Theme.mutedGold)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("LEVEL \(level)")
                        .font(Fonts.micro)
                        .tracking(2)
                        .foregroundStyle(Theme.mutedGold)
                    Spacer()
                    Text("\(xpToNext) XP TO NEXT")
                        .font(Fonts.micro)
                        .tracking(1.5)
                        .foregroundStyle(Theme.mutedGold)
                }
                GoldProgressBar(progress: progress)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .heroCard()
    }
}

// MARK: - Stat row

private struct StatRow: View {
    let player: Player

    var body: some View {
        HStack(spacing: 0) {
            ForEach(StatCategory.allCases) { stat in
                let display = XPEngine.statLevel(for: player.points(for: stat))
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Theme.gold.opacity(0.10))
                            .frame(width: 30, height: 30)
                        Image(systemName: stat.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                    }
                    Text("\(display)")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.statColor(value: display, lowThreshold: 5))
                    Text(stat.rawValue)
                        .font(Fonts.micro)
                        .tracking(1.5)
                        .foregroundStyle(Theme.mutedGold)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 14)
        .glassCard()
    }
}

// MARK: - Daily totals

private struct DailyTotalsRow: View {
    let streak: Int
    let xpToday: Int
    let pending: Int

    var body: some View {
        HStack(spacing: 10) {
            tile(value: "\(streak)", label: "Streak", icon: "flame.fill")
            tile(value: "+\(xpToday)", label: "XP Today", icon: "sparkles")
            tile(value: "\(pending)", label: "Pending", icon: "hourglass")
        }
    }

    private func tile(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.gold.opacity(0.85))
                Text(label.uppercased())
                    .font(Fonts.micro)
                    .tracking(1.5)
                    .foregroundStyle(Theme.mutedGold)
            }
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.gold)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .glassCard()
    }
}

// MARK: - Quest list

private struct QuestList: View {
    let habits: [Habit]
    let tasks: [TaskItem]
    let onCompleteHabit: (Habit) -> Void
    let onCompleteTask: (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(
                "Today's quests",
                caption: habits.isEmpty && tasks.isEmpty ? "The realm rests" : "\(habits.count + tasks.count) open"
            )

            if habits.isEmpty && tasks.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "crown")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Theme.mutedGold)
                    Text("THE REALM RESTS")
                        .font(Fonts.label)
                        .tracking(3)
                        .foregroundStyle(Theme.gold)
                    Text("No quests for today. Forge new ones from the Quests tab.")
                        .font(Fonts.body)
                        .foregroundStyle(Theme.dim)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .glassCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(habits) { habit in
                        HabitCheckRow(habit: habit, onComplete: { onCompleteHabit(habit) })
                    }
                    ForEach(tasks) { task in
                        TaskCheckRow(task: task, onComplete: { onCompleteTask(task) })
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HabitCheckRow: View {
    let habit: Habit
    let onComplete: () -> Void

    private var done: Bool { habit.isCompleted(on: .now) }

    var body: some View {
        // Two tap targets in one row:
        // - the leading checkmark circle toggles the habit (onComplete)
        // - the rest of the row navigates to HabitDetailView
        // Using NavigationLink as the outer wrapper so the inner Button intercepts
        // its own area; iOS routes the tap to whichever responder is on top.
        NavigationLink(value: habit) {
            HStack(spacing: 12) {
                Button(action: onComplete) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(done ? Theme.gold : Theme.mutedGold)
                        .padding(.vertical, 4)
                        .padding(.trailing, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.royal)
                .accessibilityLabel(done ? "Mark \(habit.name) as not done" : "Mark \(habit.name) as done")

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(Fonts.bodyBold)
                        .foregroundStyle(done ? Theme.dim : Theme.parchment)
                        .strikethrough(done, color: Theme.dim)

                    HStack(spacing: 6) {
                        Image(systemName: habit.category.symbol)
                            .font(.system(size: 9))
                        Text(habit.category.rawValue)
                            .font(Fonts.micro)
                            .tracking(1.5)
                    }
                    .foregroundStyle(Theme.mutedGold)
                }

                Spacer()

                Text("+\(habit.xpReward) XP")
                    .font(Fonts.caption)
                    .tracking(1.5)
                    .foregroundStyle(done ? Theme.dim : Theme.gold)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .interactiveGlassCard()
        }
        .buttonStyle(.royal)
        .accessibilityLabel("View \(habit.name) details")
    }
}

private struct TaskCheckRow: View {
    let task: TaskItem
    let onComplete: () -> Void

    var body: some View {
        Button(action: onComplete) {
            HStack(spacing: 12) {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(task.isCompleted ? Theme.gold : Theme.mutedGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Fonts.bodyBold)
                        .foregroundStyle(task.isCompleted ? Theme.dim : Theme.parchment)
                        .strikethrough(task.isCompleted, color: Theme.dim)

                    if task.isOverdue {
                        Text("OVERDUE")
                            .font(Fonts.micro)
                            .tracking(1.5)
                            .foregroundStyle(Theme.red)
                    } else if let deadline = task.deadline {
                        Text(deadline, style: .relative)
                            .font(Fonts.caption)
                            .tracking(1)
                            .foregroundStyle(Theme.mutedGold)
                    }
                }

                Spacer()

                Text("+\(task.xpReward) XP")
                    .font(Fonts.caption)
                    .tracking(1.5)
                    .foregroundStyle(task.isCompleted ? Theme.dim : Theme.gold)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .interactiveGlassCard()
        }
        .buttonStyle(.royal)
        .accessibilityLabel(task.isCompleted ? "Mark \(task.title) as not done" : "Mark \(task.title) as done")
    }
}

// MARK: - Preview

#Preview {
    let schema = Schema([
        Player.self, Habit.self, HabitCompletion.self, TaskItem.self, Reminder.self
    ])
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let player = Player(displayName: "Kirthik", totalXP: 1240, currentStreak: 7)
    player.strXP = 380
    player.intXP = 520
    player.vitXP = 95   // low — should glow red in the stat row
    player.dscXP = 240
    player.wilXP = 180
    context.insert(player)

    let train = Habit(name: "Train · 1 hour", xpReward: 15, category: .strength)
    let read = Habit(name: "Read · 30 min", xpReward: 10, category: .intellect)
    let meditate = Habit(name: "Meditate · 10 min", xpReward: 10, category: .discipline)
    context.insert(train)
    context.insert(read)
    context.insert(meditate)

    // Mark one as already done today so the strikethrough state is visible.
    context.insert(HabitCompletion(habit: read, xpAwarded: read.xpReward))

    let deadline = Calendar.current.date(byAdding: .day, value: 2, to: .now)
    context.insert(TaskItem(
        title: "Renew passport",
        deadline: deadline,
        xpReward: 50,
        category: .will
    ))

    return HomeView()
        .preferredColorScheme(.dark)
        .modelContainer(container)
}
