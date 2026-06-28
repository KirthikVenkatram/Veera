import SwiftData
import SwiftUI

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let existing: Habit?

    @State private var name: String
    @State private var details: String
    @State private var xpReward: Int
    @State private var category: StatCategory
    @State private var cadence: Cadence
    @State private var selectedDays: Set<Weekday>
    @State private var hasReminder: Bool
    @State private var reminderTime: Date

    init(existing: Habit? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _details = State(initialValue: existing?.details ?? "")
        _xpReward = State(initialValue: existing?.xpReward ?? 10)
        _category = State(initialValue: existing?.category ?? .discipline)

        let initialCadence = existing?.cadence ?? .daily
        _cadence = State(initialValue: initialCadence)

        if case .customDays(let days) = initialCadence {
            _selectedDays = State(initialValue: days)
        } else {
            _selectedDays = State(initialValue: [.monday, .wednesday, .friday])
        }

        let hasReminderInitial = existing?.reminderHour != nil
        _hasReminder = State(initialValue: hasReminderInitial)

        var initialReminderTime = Date.now
        if let hour = existing?.reminderHour, let minute = existing?.reminderMinute {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
            components.hour = hour
            components.minute = minute
            if let date = Calendar.current.date(from: components) {
                initialReminderTime = date
            }
        }
        _reminderTime = State(initialValue: initialReminderTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("QUEST") {
                    TextField("Name", text: $name)
                    TextField("Details", text: $details, axis: .vertical)
                }

                Section("REWARD") {
                    Picker("Stat", selection: $category) {
                        ForEach(StatCategory.allCases) { stat in
                            Label(stat.displayName, systemImage: stat.symbol)
                                .tag(stat)
                        }
                    }

                    Stepper(value: $xpReward, in: 5...100, step: 5) {
                        Text("+\(xpReward) XP")
                            .font(Fonts.smallNumeral)
                    }
                }

                Section("CADENCE") {
                    Picker("Repeat", selection: $cadence) {
                        Text("Daily").tag(Cadence.daily)
                        Text("Weekly").tag(Cadence.weekly)
                        Text("Custom").tag(Cadence.customDays(selectedDays))
                    }

                    if case .customDays = cadence {
                        WeekdayPicker(selection: $selectedDays)
                            .onChange(of: selectedDays) { _, newValue in
                                cadence = .customDays(newValue)
                            }
                    }
                }

                Section("REMINDER") {
                    Toggle("Reminder", isOn: $hasReminder)
                    if hasReminder {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Habit" : "Edit Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .tint(Theme.gold)
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let detailsValue = cleanDetails.isEmpty ? nil : cleanDetails

        let pushed: Habit
        if let existing {
            existing.name = cleanName
            existing.details = detailsValue
            existing.xpReward = xpReward
            existing.category = category
            existing.cadence = normalizedCadence
            existing.reminderHour = hasReminder ? components.hour : nil
            existing.reminderMinute = hasReminder ? components.minute : nil
            pushed = existing
        } else {
            let habit = Habit(
                name: cleanName,
                details: detailsValue,
                xpReward: xpReward,
                category: category,
                cadence: normalizedCadence,
                reminderHour: hasReminder ? components.hour : nil,
                reminderMinute: hasReminder ? components.minute : nil
            )
            context.insert(habit)
            pushed = habit
        }
        try? context.save()

        // Mirror to Apple Reminders (no-op when the Settings toggle is off).
        Task { try? await EventKitExporter.pushHabitReminder(pushed) }

        dismiss()
    }

    private var normalizedCadence: Cadence {
        if case .customDays = cadence {
            return .customDays(selectedDays)
        }
        return cadence
    }
}

private struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                Button {
                    if selection.contains(day) {
                        selection.remove(day)
                    } else {
                        selection.insert(day)
                    }
                } label: {
                    Text(day.shortName)
                        .font(Fonts.micro)
                        .foregroundStyle(selection.contains(day) ? Theme.obsidian : Theme.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selection.contains(day) ? Theme.gold : Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.royal)
            }
        }
    }
}
