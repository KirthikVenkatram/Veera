import OSLog
import SwiftData
import SwiftUI

struct QuestsView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<Habit> { !$0.isArchived },
        sort: \Habit.createdAt, order: .forward
    )
    private var habits: [Habit]
    @Query(sort: \TaskItem.createdAt, order: .forward)
    private var tasks: [TaskItem]
    @Query(sort: \Reminder.fireAt, order: .forward)
    private var reminders: [Reminder]

    @State private var addHabitPresented = false
    @State private var addTaskPresented = false
    @State private var addReminderPresented = false
    @State private var addVowPresented = false

    @State private var editingHabit: Habit?
    @State private var editingTask: TaskItem?
    @State private var editingReminder: Reminder?

    private var openTasks: [TaskItem] {
        tasks.filter { !$0.isCompleted }
    }

    private var activeReminders: [Reminder] {
        reminders.filter(\.isActive)
    }

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
                    VStack(spacing: 24) {
                        QuestActionRow(
                            onAddHabit: { addHabitPresented = true },
                            onAddTask: { addTaskPresented = true },
                            onAddReminder: { addReminderPresented = true },
                            onAddVow: { addVowPresented = true }
                        )

                        questSection(
                            title: "Habits",
                            caption: habits.isEmpty ? nil : "\(habits.count) recurring",
                            isEmpty: habits.isEmpty,
                            emptyCopy: "No recurring habits yet."
                        ) {
                            ForEach(habits) { habit in
                                HabitQuestCard(
                                    habit: habit,
                                    onEdit: { editingHabit = habit },
                                    onArchive: { archive(habit) }
                                )
                            }
                        }

                        questSection(
                            title: "Tasks",
                            caption: openTasks.isEmpty ? nil : "\(openTasks.count) open",
                            isEmpty: openTasks.isEmpty,
                            emptyCopy: "No open tasks. The realm is at peace."
                        ) {
                            ForEach(openTasks) { task in
                                TaskQuestCard(
                                    task: task,
                                    onEdit: { editingTask = task },
                                    onDelete: { delete(task) }
                                )
                            }
                        }

                        questSection(
                            title: "Reminders",
                            caption: activeReminders.isEmpty ? nil : "\(activeReminders.count) active",
                            isEmpty: activeReminders.isEmpty,
                            emptyCopy: "No active bells."
                        ) {
                            ForEach(activeReminders) { reminder in
                                ReminderQuestCard(
                                    reminder: reminder,
                                    onEdit: { editingReminder = reminder },
                                    onPause: { pause(reminder) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Quests")
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habit: habit)
            }
            .sheet(isPresented: $addHabitPresented) { AddHabitView() }
            .sheet(isPresented: $addTaskPresented) { AddTaskView() }
            .sheet(isPresented: $addReminderPresented) { AddReminderView() }
            .sheet(isPresented: $addVowPresented) { AddVowView() }
            .sheet(item: $editingHabit) { habit in AddHabitView(existing: habit) }
            .sheet(item: $editingTask) { task in AddTaskView(existing: task) }
            .sheet(item: $editingReminder) { reminder in AddReminderView(existing: reminder) }
            .tint(Theme.gold)
        }
    }

    @ViewBuilder
    private func questSection<Items: View>(
        title: String,
        caption: String?,
        isEmpty: Bool,
        emptyCopy: String,
        @ViewBuilder items: () -> Items
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title, caption: caption)

            if isEmpty {
                Text(emptyCopy)
                    .font(Fonts.body)
                    .foregroundStyle(Theme.dim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 22)
                    .glassCard()
            } else {
                VStack(spacing: 10) {
                    items()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func archive(_ habit: Habit) {
        EventKitExporter.remove(habit: habit)
        habit.isArchived = true
        try? context.save()
        AppLogger.questActions.info("habit.archive name=\(habit.name, privacy: .private) cat=\(habit.category.rawValue, privacy: .public)")
    }

    private func delete(_ task: TaskItem) {
        AppLogger.questActions.info("task.delete title=\(task.title, privacy: .private) cat=\(task.category.rawValue, privacy: .public)")
        EventKitExporter.remove(task: task)
        context.delete(task)
        try? context.save()
    }

    private func pause(_ reminder: Reminder) {
        reminder.isActive = false
        NotificationService.cancel(reminder: reminder)
        EventKitExporter.remove(reminder: reminder)
        try? context.save()
        AppLogger.questActions.info("reminder.pause title=\(reminder.title, privacy: .private)")
    }
}

// MARK: - Action row

private struct QuestActionRow: View {
    let onAddHabit: () -> Void
    let onAddTask: () -> Void
    let onAddReminder: () -> Void
    let onAddVow: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            QuestActionButton(icon: "repeat", label: "HABIT", action: onAddHabit)
            QuestActionButton(icon: "checklist", label: "TASK", action: onAddTask)
            QuestActionButton(icon: "bell.badge.fill", label: "BELL", action: onAddReminder)
            QuestActionButton(icon: "seal.fill", label: "VOW", action: onAddVow)
        }
    }
}

private struct QuestActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Theme.gold.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                }
                Text(label)
                    .font(Fonts.micro)
                    .tracking(2.5)
                    .foregroundStyle(Theme.mutedGold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassCard()
        }
        .buttonStyle(.royal)
        .accessibilityLabel("Add \(label.capitalized)")
    }
}

// MARK: - Quest cards

private struct HabitQuestCard: View {
    let habit: Habit
    let onEdit: () -> Void
    let onArchive: () -> Void

    var body: some View {
        NavigationLink(value: habit) {
            QuestCardLayout(
                icon: habit.category.symbol,
                title: habit.name,
                metaLeft: habit.category.rawValue,
                metaRight: "+\(habit.xpReward) XP"
            )
        }
        .buttonStyle(.royal)
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onArchive) {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }
}

private struct TaskQuestCard: View {
    let task: TaskItem
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var metaLeft: String {
        if task.isOverdue {
            return "OVERDUE"
        }
        if let deadline = task.deadline {
            return deadline.formatted(date: .abbreviated, time: .omitted)
        }
        return task.category.rawValue
    }

    var body: some View {
        QuestCardLayout(
            icon: task.category.symbol,
            title: task.title,
            metaLeft: metaLeft,
            metaRight: "+\(task.xpReward) XP",
            metaLeftTone: task.isOverdue ? .red : .mutedGold
        )
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct ReminderQuestCard: View {
    let reminder: Reminder
    let onEdit: () -> Void
    let onPause: () -> Void

    var body: some View {
        QuestCardLayout(
            icon: "bell.fill",
            title: reminder.title,
            metaLeft: reminder.repeatPattern.displayName.uppercased(),
            metaRight: reminder.fireAt.formatted(date: .omitted, time: .shortened)
        )
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(action: onPause) {
                Label("Pause", systemImage: "bell.slash")
            }
        }
    }
}

private struct QuestCardLayout: View {
    enum Tone {
        case mutedGold
        case red
    }

    let icon: String
    let title: String
    let metaLeft: String
    let metaRight: String
    var metaLeftTone: Tone = .mutedGold

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Theme.gold.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.gold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Fonts.bodyBold)
                    .foregroundStyle(Theme.parchment)

                HStack(spacing: 6) {
                    Text(metaLeft)
                        .foregroundStyle(metaLeftTone == .red ? Theme.red : Theme.mutedGold)
                    Text("·")
                        .foregroundStyle(Theme.dim)
                    Text(metaRight)
                        .foregroundStyle(Theme.gold)
                }
                .font(Fonts.micro)
                .tracking(1.5)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.dim)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
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
    let context = container.mainContext

    context.insert(Habit(name: "Train", xpReward: 15, category: .strength))
    context.insert(Habit(name: "Read", xpReward: 10, category: .intellect))
    context.insert(TaskItem(
        title: "Renew passport",
        deadline: Calendar.current.date(byAdding: .day, value: 2, to: .now),
        xpReward: 50,
        category: .will
    ))
    context.insert(Reminder(
        title: "Visit Amma",
        fireAt: Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now,
        repeatPattern: .weekly
    ))

    return QuestsView()
        .preferredColorScheme(.dark)
        .modelContainer(container)
}
