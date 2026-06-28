import SwiftData
import SwiftUI

struct AddReminderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let existing: Reminder?

    @State private var title: String
    @State private var note: String
    @State private var fireAt: Date
    @State private var repeatPattern: ReminderRepeat

    init(existing: Reminder? = nil) {
        self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _note = State(initialValue: existing?.note ?? "")
        _fireAt = State(initialValue: existing?.fireAt ?? .now)
        _repeatPattern = State(initialValue: existing?.repeatPattern ?? .once)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("REMINDER") {
                    TextField("Title", text: $title)
                    TextField("Note", text: $note, axis: .vertical)
                    DatePicker("Fire At", selection: $fireAt)
                }

                Section("REPEAT") {
                    Picker("Repeat", selection: $repeatPattern) {
                        ForEach(ReminderRepeat.allCases) { pattern in
                            Text(pattern.displayName).tag(pattern)
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Reminder" : "Edit Reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .tint(Theme.gold)
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteValue = cleanNote.isEmpty ? nil : cleanNote

        let scheduled: Reminder
        if let existing {
            existing.title = cleanTitle
            existing.note = noteValue
            existing.fireAt = fireAt
            existing.repeatPattern = repeatPattern
            scheduled = existing
        } else {
            let reminder = Reminder(
                title: cleanTitle,
                note: noteValue,
                fireAt: fireAt,
                repeatPattern: repeatPattern
            )
            context.insert(reminder)
            scheduled = reminder
        }
        try? context.save()

        // UNUserNotificationCenter.add replaces an existing request with the same
        // identifier, so editing also re-schedules correctly without an explicit cancel.
        Task {
            await NotificationService.schedule(reminder: scheduled)
            try? await EventKitExporter.pushStandaloneReminder(scheduled)
        }

        dismiss()
    }
}
