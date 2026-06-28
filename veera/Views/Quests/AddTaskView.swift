import SwiftData
import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let existing: TaskItem?

    @State private var title: String
    @State private var details: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var xpReward: Int
    @State private var category: StatCategory

    init(existing: TaskItem? = nil) {
        self.existing = existing
        _title = State(initialValue: existing?.title ?? "")
        _details = State(initialValue: existing?.details ?? "")
        _hasDeadline = State(initialValue: existing?.deadline != nil)
        _deadline = State(initialValue: existing?.deadline ?? .now)
        _xpReward = State(initialValue: existing?.xpReward ?? 25)
        _category = State(initialValue: existing?.category ?? .will)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("TASK") {
                    TextField("Title", text: $title)
                    TextField("Details", text: $details, axis: .vertical)
                }

                Section("REWARD") {
                    Picker("Stat", selection: $category) {
                        ForEach(StatCategory.allCases) { stat in
                            Label(stat.displayName, systemImage: stat.symbol)
                                .tag(stat)
                        }
                    }

                    Stepper(value: $xpReward, in: 5...150, step: 5) {
                        Text("+\(xpReward) XP")
                            .font(Fonts.smallNumeral)
                    }
                }

                Section("DEADLINE") {
                    Toggle("Deadline", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Due", selection: $deadline)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Task" : "Edit Task")
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
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let detailsValue = cleanDetails.isEmpty ? nil : cleanDetails
        let deadlineValue = hasDeadline ? deadline : nil

        let pushed: TaskItem
        if let existing {
            existing.title = cleanTitle
            existing.details = detailsValue
            existing.deadline = deadlineValue
            existing.xpReward = xpReward
            existing.category = category
            pushed = existing
        } else {
            let task = TaskItem(
                title: cleanTitle,
                details: detailsValue,
                deadline: deadlineValue,
                xpReward: xpReward,
                category: category
            )
            context.insert(task)
            pushed = task
        }
        try? context.save()

        // Mirror deadline to Apple Calendar (no-op when toggle off or no deadline).
        Task { try? await EventKitExporter.pushTaskDeadline(pushed) }

        dismiss()
    }
}
