import Foundation
import SwiftData

@Model
final class Reminder {
    var id: UUID
    var title: String
    var note: String?
    var fireAt: Date                          // when to notify
    var repeatPatternRaw: String              // ReminderRepeat raw value
    var isActive: Bool                        // false = paused, kept for history
    var createdAt: Date

    // Identifier of the mirrored EKReminder, if mirroring is on.
    var eventKitIdentifier: String?

    var repeatPattern: ReminderRepeat {
        get { ReminderRepeat(rawValue: repeatPatternRaw) ?? .once }
        set { repeatPatternRaw = newValue.rawValue }
    }

    init(
        title: String,
        note: String? = nil,
        fireAt: Date,
        repeatPattern: ReminderRepeat = .once
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.fireAt = fireAt
        self.repeatPatternRaw = repeatPattern.rawValue
        self.isActive = true
        self.createdAt = .now
    }
}
