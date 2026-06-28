import SwiftData
import SwiftUI

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Query private var players: [Player]

    @State private var mode: CalendarDisplayMode = .month
    @State private var anchorDate = Date.now
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var summaries: [CalendarDaySummary] = []
    @State private var heatmapDays: [HeatmapDay] = []

    private let calendar = Calendar.current
    private var player: Player? { players.first }

    private var visibleDays: [Date] {
        switch mode {
        case .month:
            return CalendarAggregator.monthGridDays(containing: anchorDate, calendar: calendar)
        case .week:
            return CalendarAggregator.days(
                in: CalendarAggregator.weekRange(containing: anchorDate, calendar: calendar),
                calendar: calendar
            )
        }
    }

    private var selectedSummary: CalendarDaySummary? {
        summaries.first { calendar.isDate($0.day, inSameDayAs: selectedDay) }
    }

    private var title: String {
        switch mode {
        case .month:
            return anchorDate.formatted(.dateTime.month(.wide).year())
        case .week:
            let range = CalendarAggregator.weekRange(containing: anchorDate, calendar: calendar)
            return "\(range.start.formatted(.dateTime.month(.abbreviated).day())) - \(range.end.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day()))"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.obsidian.ignoresSafeArea()
                RadialGradient(
                    colors: [Theme.gold.opacity(0.16), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 360
                )
                .ignoresSafeArea(edges: .top)
                .frame(height: 360)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        CalendarHeaderCard(
                            title: title,
                            selectedDay: selectedDay,
                            summary: selectedSummary,
                            onPrevious: moveBackward,
                            onNext: moveForward
                        )

                        SegmentedTabBar<CalendarDisplayMode>(selection: $mode)
                            .padding(.top, 4)

                        CalendarGridCard(
                            mode: mode,
                            anchorDate: anchorDate,
                            selectedDay: selectedDay,
                            days: visibleDays,
                            summaries: summaries,
                            onSelect: { selectedDay = $0 }
                        )

                        DayDetailCard(
                            day: selectedDay,
                            summary: selectedSummary,
                            onToggleHabit: toggleHabit,
                            onToggleTask: toggleTask,
                            onKeepVow: keepVow
                        )

                        HeatmapCard(days: heatmapDays)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Calendar")
            .toolbarBackground(.hidden, for: .navigationBar)
            .tint(Theme.gold)
        }
        .onAppear(perform: reload)
        .onChange(of: mode) { reload() }
        .onChange(of: anchorDate) { reload() }
    }

    private func reload() {
        let summaryRange = CalendarAggregator.visibleRange(containing: anchorDate, mode: mode, calendar: calendar)
        summaries = CalendarAggregator.fetchSummaries(for: summaryRange, in: context, calendar: calendar)

        let heatmapEnd = CalendarAggregator.dayRange(containing: .now, calendar: calendar).end
        let heatmapStart = calendar.date(byAdding: .day, value: -83, to: calendar.startOfDay(for: .now)) ?? heatmapEnd
        heatmapDays = CalendarAggregator.fetchHeatmap(
            for: CalendarDateRange(start: heatmapStart, end: heatmapEnd),
            in: context,
            calendar: calendar
        )
    }

    private func moveBackward() {
        let component: Calendar.Component = mode == .month ? .month : .weekOfYear
        anchorDate = calendar.date(byAdding: component, value: -1, to: anchorDate) ?? anchorDate
    }

    private func moveForward() {
        let component: Calendar.Component = mode == .month ? .month : .weekOfYear
        anchorDate = calendar.date(byAdding: component, value: 1, to: anchorDate) ?? anchorDate
    }

    private func toggleHabit(_ habit: Habit) {
        if habit.isCompleted(on: selectedDay, calendar: calendar) {
            undoHabit(habit)
        } else {
            completeHabit(habit)
        }
        reload()
    }

    private func completeHabit(_ habit: Habit) {
        let levelBefore = player.map { XPEngine.level(for: $0.totalXP) } ?? 1
        let rankBefore = Rank.rank(forLevel: levelBefore)
        let completion = HabitCompletion(habit: habit, completedAt: selectedDay, xpAwarded: habit.xpReward)
        context.insert(completion)
        if let player {
            XPEngine.awardHabit(habit, to: player)
            StreakEngine.recordActivity(for: player)
        }
        try? context.save()
        HapticEngine.shared.quest(.complete)
        detectLevelUp(from: levelBefore, oldRank: rankBefore)
    }

    private func undoHabit(_ habit: Habit) {
        let targetCompletions = habit.completions.filter {
            calendar.isDate($0.completedAt, inSameDayAs: selectedDay)
        }
        for completion in targetCompletions {
            context.delete(completion)
        }
        if let player {
            XPEngine.revokeHabit(habit, from: player)
            StreakEngine.rebuildStreak(for: player, in: context)
        }
        try? context.save()
        HapticEngine.shared.quest(.uncomplete)
    }

    private func toggleTask(_ task: TaskItem) {
        if task.isCompleted {
            task.isCompleted = false
            task.completedAt = nil
            if let player {
                XPEngine.revokeTask(task, from: player)
                StreakEngine.rebuildStreak(for: player, in: context)
            }
            HapticEngine.shared.quest(.uncomplete)
        } else {
            let levelBefore = player.map { XPEngine.level(for: $0.totalXP) } ?? 1
            let rankBefore = Rank.rank(forLevel: levelBefore)
            task.isCompleted = true
            task.completedAt = selectedDay
            if let player {
                XPEngine.awardTask(task, to: player)
                StreakEngine.recordActivity(for: player)
            }
            HapticEngine.shared.quest(.complete)
            detectLevelUp(from: levelBefore, oldRank: rankBefore)
        }
        try? context.save()
        reload()
    }

    private func keepVow(_ vow: Vow) {
        guard vow.checkIn(on: selectedDay, calendar: calendar) == nil else { return }
        context.insert(VowCheckIn(vow: vow, date: selectedDay, kept: true))
        try? context.save()
        HapticEngine.shared.quest(.complete)
        reload()
    }

    private func detectLevelUp(from oldLevel: Int, oldRank: Rank) {
        guard let player else { return }
        let newLevel = XPEngine.level(for: player.totalXP)
        let newRank = Rank.rank(forLevel: newLevel)
        guard newLevel > oldLevel, newRank != oldRank else { return }
        StatsAggregator.recordRankIfNeeded(newRank, in: context)
    }
}

private struct CalendarHeaderCard: View {
    let title: String
    let selectedDay: Date
    let summary: CalendarDaySummary?
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.royal)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .tracking(3)
                        .foregroundStyle(Theme.parchment)
                    Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(Fonts.micro)
                        .tracking(1.5)
                        .foregroundStyle(Theme.mutedGold)
                }

                Spacer()

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.royal)
            }

            HStack(spacing: 10) {
                CalendarMetric(value: "\(summary?.habits.count ?? 0)", label: "Habits", color: Theme.gold)
                CalendarMetric(value: "\(summary?.tasks.count ?? 0)", label: "Tasks", color: Theme.red)
                CalendarMetric(value: "\(summary?.vows.count ?? 0)", label: "Vows", color: Theme.parchment)
                CalendarMetric(value: "+\(summary?.xpEarned ?? 0)", label: "XP", color: Theme.gold)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 18)
        .heroCard()
    }
}

private struct CalendarMetric: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label.uppercased())
                .font(Fonts.micro)
                .tracking(1.4)
                .foregroundStyle(Theme.mutedGold)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CalendarGridCard: View {
    let mode: CalendarDisplayMode
    let anchorDate: Date
    let selectedDay: Date
    let days: [Date]
    let summaries: [CalendarDaySummary]
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Quest calendar", caption: "Dots: habits, tasks, vows")
            weekdayRow
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days, id: \.self) { day in
                    CalendarDayCell(
                        day: day,
                        isInCurrentMonth: mode == .week || calendar.isDate(day, equalTo: anchorDate, toGranularity: .month),
                        isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                        isToday: calendar.isDateInToday(day),
                        summary: summaries.first { calendar.isDate($0.day, inSameDayAs: day) },
                        onSelect: { onSelect(day) }
                    )
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassCard()
    }

    private var weekdayRow: some View {
        HStack(spacing: 6) {
            ForEach(shortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol.uppercased())
                    .font(Fonts.micro)
                    .tracking(1)
                    .foregroundStyle(Theme.mutedGold)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var shortWeekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = max(0, calendar.firstWeekday - 1)
        return Array(symbols[first...] + symbols[..<first])
    }
}

private struct CalendarDayCell: View {
    let day: Date
    let isInCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let summary: CalendarDaySummary?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 5) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.system(size: 15, weight: isSelected ? .bold : .semibold, design: .serif))
                    .foregroundStyle(textColor)
                    .monospacedDigit()

                DotRow(summary: summary)
                    .frame(height: 5)
            }
            .frame(height: 46)
            .frame(maxWidth: .infinity)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isToday ? Theme.gold.opacity(0.65) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.royal)
        .opacity(isInCurrentMonth ? 1 : 0.38)
    }

    private var textColor: Color {
        if isSelected { return Theme.obsidian }
        return isInCurrentMonth ? Theme.parchment : Theme.dim
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.goldGradient)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface.opacity(0.35))
        }
    }
}

private struct DotRow: View {
    let summary: CalendarDaySummary?

    var body: some View {
        HStack(spacing: 3) {
            if summary?.habits.isEmpty == false {
                dot(Theme.gold)
            }
            if summary?.tasks.isEmpty == false {
                dot(Theme.red)
            }
            if summary?.vows.isEmpty == false {
                dot(Theme.parchment)
            }
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 5, height: 5)
    }
}

private struct DayDetailCard: View {
    let day: Date
    let summary: CalendarDaySummary?
    let onToggleHabit: (Habit) -> Void
    let onToggleTask: (TaskItem) -> Void
    let onKeepVow: (Vow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Day detail", caption: day.formatted(.dateTime.weekday(.wide).month(.wide).day()))

            if let summary, summary.itemCount > 0 {
                VStack(spacing: 10) {
                    ForEach(summary.habits) { habit in
                        CalendarItemRow(
                            icon: "repeat",
                            title: habit.name,
                            meta: "+\(habit.xpReward) XP · \(habit.category.rawValue)",
                            color: Theme.gold,
                            isDone: habit.isCompleted(on: day),
                            actionTitle: habit.isCompleted(on: day) ? "Undo" : "Done",
                            action: { onToggleHabit(habit) }
                        )
                    }
                    ForEach(summary.tasks) { task in
                        CalendarItemRow(
                            icon: "checklist",
                            title: task.title,
                            meta: "+\(task.xpReward) XP · due",
                            color: Theme.red,
                            isDone: task.isCompleted,
                            actionTitle: task.isCompleted ? "Undo" : "Done",
                            action: { onToggleTask(task) }
                        )
                    }
                    ForEach(summary.vows) { vow in
                        CalendarItemRow(
                            icon: "seal.fill",
                            title: vow.title,
                            meta: vow.isBroken ? "broken vow" : "vow ending",
                            color: Theme.parchment,
                            isDone: vow.checkIn(on: day)?.kept == true,
                            actionTitle: vow.checkIn(on: day) == nil ? "Keep" : "Kept",
                            action: { onKeepVow(vow) }
                        )
                        .disabled(vow.checkIn(on: day) != nil || vow.isBroken)
                    }
                }
            } else {
                CalendarEmptyHintRow(text: "No quests land on this day.")
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassCard()
    }
}

private struct CalendarEmptyHintRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Fonts.body)
            .foregroundStyle(Theme.dim)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 22)
    }
}

private struct CalendarItemRow: View {
    let icon: String
    let title: String
    let meta: String
    let color: Color
    let isDone: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.13))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Fonts.bodyBold)
                    .foregroundStyle(isDone ? Theme.dim : Theme.parchment)
                    .strikethrough(isDone, color: Theme.dim)
                    .lineLimit(2)
                Text(meta.uppercased())
                    .font(Fonts.micro)
                    .tracking(1.3)
                    .foregroundStyle(Theme.mutedGold)
            }

            Spacer()

            Button(action: action) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDone ? Theme.gold : Theme.mutedGold)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.royal)
            .accessibilityLabel(actionTitle)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .interactiveGlassCard()
    }
}

private struct HeatmapCard: View {
    let days: [HeatmapDay]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 12)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel("Contribution heatmap", caption: "Last 12 weeks by XP earned")
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color(for: day.intensity))
                        .aspectRatio(1, contentMode: .fit)
                        .accessibilityLabel("\(day.value) XP on \(day.day.formatted(date: .abbreviated, time: .omitted))")
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .glassCard()
    }

    private func color(for intensity: Int) -> Color {
        switch intensity {
        case 1: return Theme.gold.opacity(0.25)
        case 2: return Theme.gold.opacity(0.45)
        case 3: return Theme.gold.opacity(0.68)
        case 4: return Theme.gold
        default: return Theme.surface.opacity(0.8)
        }
    }
}

#Preview {
    let schema = Schema([
        Player.self, Habit.self, HabitCompletion.self, TaskItem.self, Reminder.self,
        RankAchievement.self, Vow.self, VowCheckIn.self
    ])
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    // swiftlint:disable:next redundant_discardable_let
    let _ = {
        let context = container.mainContext
        let player = Player(displayName: "Kirthik", totalXP: 320)
        context.insert(player)
        let train = Habit(name: "Train", xpReward: 15, category: .strength)
        let read = Habit(name: "Read", xpReward: 10, category: .intellect, cadence: .customDays([.monday, .wednesday, .friday]))
        context.insert(train)
        context.insert(read)
        context.insert(HabitCompletion(habit: train, completedAt: .now, xpAwarded: 15))
        context.insert(TaskItem(title: "Renew passport", deadline: .now, xpReward: 50, category: .will))
        context.insert(Vow(title: "No sugar", body: "Hold the line", durationDays: 7))
    }()

    CalendarView()
        .preferredColorScheme(.dark)
        .modelContainer(container)
}
