import SwiftData
import SwiftUI

// Detail screen for a single habit. Reachable by tapping a quest row in
// Home or Quests (the checkmark on the Home row is a separate tap target
// so toggling stays accessible). Pure read view — except for the Edit sheet
// and the Archive action.
struct HabitDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let habit: Habit

    @State private var editingHabit: Habit?
    @State private var archiveConfirmationPresented = false

    var body: some View {
        ZStack {
            Theme.obsidian.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    HabitDetailHeader(habit: habit)
                    SevenDayHeatmap(habit: habit)
                    HabitStatsRow(habit: habit)
                    HabitScheduleCard(habit: habit)
                    RecentCompletionsCard(habit: habit)
                    HabitActionRow(
                        onEdit: { editingHabit = habit },
                        onArchive: { archiveConfirmationPresented = true }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(Theme.gold)
        .sheet(item: $editingHabit) { existing in AddHabitView(existing: existing) }
        .confirmationDialog(
            "Archive this habit?",
            isPresented: $archiveConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Archive", role: .destructive) { archive() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Archived habits no longer appear in Today or Quests, but their history is preserved.")
        }
    }

    private func archive() {
        habit.isArchived = true
        try? context.save()
        dismiss()
    }
}

// MARK: - Header

private struct HabitDetailHeader: View {
    let habit: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(habit.name)
                .font(Fonts.heading)
                .foregroundStyle(Theme.parchment)

            HStack(spacing: 14) {
                Label {
                    Text(habit.category.displayName.uppercased())
                        .font(Fonts.micro)
                        .tracking(2)
                        .foregroundStyle(Theme.mutedGold)
                } icon: {
                    Image(systemName: habit.category.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }

                Text("·").foregroundStyle(Theme.dim)

                Text("+\(habit.xpReward) XP")
                    .font(Fonts.caption)
                    .tracking(1.5)
                    .foregroundStyle(Theme.gold)

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(habit.currentStreak())")
                        .font(Fonts.numeral)
                        .foregroundStyle(Theme.gold)
                    Text("STREAK").labelStyle()
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .roundedCard()
    }
}

// MARK: - 7-day heatmap

private struct SevenDayHeatmap: View {
    let habit: Habit

    private let calendar = Calendar.current
    private let daySize: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LAST 7 DAYS").labelStyle()

            HStack(spacing: 8) {
                ForEach(orderedDays, id: \.self) { day in
                    VStack(spacing: 8) {
                        cell(for: day)
                            .frame(width: daySize, height: daySize)
                        Text(letter(for: day))
                            .font(Fonts.micro)
                            .tracking(1)
                            .foregroundStyle(Theme.mutedGold)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .roundedCard()
    }

    private var orderedDays: [Date] {
        habit.completionMap(days: 7, calendar: calendar)
            .keys
            .sorted()   // oldest → newest, so today renders rightmost
    }

    @ViewBuilder
    private func cell(for day: Date) -> some View {
        let completed = habit.isCompleted(on: day, calendar: calendar)
        let isToday = calendar.isDateInToday(day)
        if completed {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.gold)
        } else if isToday {
            // Today, still open — dimmed gold so it reads as "pending", not "missed".
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.gold.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.gold.opacity(0.5), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
        }
    }

    private func letter(for day: Date) -> String {
        Weekday(date: day, calendar: calendar).letter
    }
}

// MARK: - Stats row

private struct HabitStatsRow: View {
    let habit: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STATS").labelStyle()

            HStack(spacing: 0) {
                cell(value: "\(habit.totalCompletions)", label: "TOTAL")
                divider
                cell(value: "\(habit.longestStreakEver())", label: "LONGEST")
                divider
                cell(value: "\(habit.currentStreak())", label: "CURRENT")
                divider
                cell(value: lastLabel, label: "LAST")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .roundedCard()
    }

    private var lastLabel: String {
        guard let last = habit.lastCompletedAt else { return "—" }
        return last.formatted(.dateTime.month(.abbreviated).day())
    }

    private func cell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Fonts.numeral)
                .foregroundStyle(Theme.gold)
            Text(label).labelStyle()
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(width: 1, height: 36)
    }
}

// MARK: - Schedule

private struct HabitScheduleCard: View {
    let habit: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SCHEDULE").labelStyle()

            row(icon: "calendar", label: "Cadence", value: habit.cadence.displaySummary)

            if let reminderTime {
                row(icon: "bell.fill", label: "Reminder", value: reminderTime)
            } else {
                row(icon: "bell.slash", label: "Reminder", value: "None")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .roundedCard()
    }

    private var reminderTime: String? {
        guard let hour = habit.reminderHour, let minute = habit.reminderMinute else {
            return nil
        }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else { return nil }
        return date.formatted(.dateTime.hour().minute())
    }

    private func row(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.mutedGold)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(Fonts.micro)
                    .tracking(1.5)
                    .foregroundStyle(Theme.mutedGold)
                Text(value)
                    .font(Fonts.body)
                    .foregroundStyle(Theme.parchment)
            }

            Spacer()
        }
    }
}

// MARK: - Recent completions

private struct RecentCompletionsCard: View {
    let habit: Habit

    private static let limit = 14

    private var entries: [HabitCompletion] {
        habit.completions
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(Self.limit)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT COMPLETIONS").labelStyle()

            if entries.isEmpty {
                Text("No completions yet.")
                    .font(Fonts.body)
                    .foregroundStyle(Theme.dim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 6) {
                    ForEach(entries) { entry in
                        completionRow(entry)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .roundedCard()
    }

    private func completionRow(_ entry: HabitCompletion) -> some View {
        HStack {
            Text(entry.completedAt.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated)))
                .font(Fonts.body)
                .foregroundStyle(Theme.parchment)

            Spacer()

            Text(entry.completedAt.formatted(.dateTime.hour().minute()))
                .font(Fonts.caption)
                .foregroundStyle(Theme.mutedGold)

            Text("+\(entry.xpAwarded) XP")
                .font(Fonts.caption)
                .tracking(1.5)
                .foregroundStyle(Theme.gold)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Action row

private struct HabitActionRow: View {
    let onEdit: () -> Void
    let onArchive: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                Label {
                    Text("EDIT")
                        .font(Fonts.bodyBold)
                        .tracking(2)
                } icon: {
                    Image(systemName: "pencil")
                }
                .foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .interactiveGlassCard()
            }
            .buttonStyle(.royal)

            Button(action: onArchive) {
                Label {
                    Text("ARCHIVE")
                        .font(Fonts.bodyBold)
                        .tracking(2)
                } icon: {
                    Image(systemName: "archivebox")
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
    let context = container.mainContext

    let habit = Habit(
        name: "Train · 1 hour",
        xpReward: 15,
        category: .strength,
        cadence: .customDays([.monday, .wednesday, .friday]),
        reminderHour: 7,
        reminderMinute: 30
    )
    context.insert(habit)

    let calendar = Calendar.current
    for offset in [0, 1, 2, 4, 6] {
        if let day = calendar.date(byAdding: .day, value: -offset, to: .now) {
            let completion = HabitCompletion(habit: habit, xpAwarded: habit.xpReward)
            completion.completedAt = day
            context.insert(completion)
        }
    }

    return NavigationStack {
        HabitDetailView(habit: habit)
    }
    .preferredColorScheme(.dark)
    .modelContainer(container)
}
