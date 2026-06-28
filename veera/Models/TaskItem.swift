import Foundation
import SwiftData

// Named TaskItem instead of Task because Swift's concurrency system already uses `Task`
// as a type. Conflicts cause cryptic errors. TaskItem is uglier but unambiguous.
@Model
final class TaskItem {
    var id: UUID
    var title: String
    var details: String?
    var createdAt: Date

    // MARK: - Deadline
    var deadline: Date?              // nil = no deadline ("someday" task)

    // MARK: - Completion
    var isCompleted: Bool
    var completedAt: Date?

    // MARK: - Reward
    var xpReward: Int
    var categoryRaw: String

    // Identifier of the mirrored EKEvent in Apple Calendar, if mirroring is on.
    var eventKitIdentifier: String?

    var category: StatCategory {
        get { StatCategory(rawValue: categoryRaw) ?? .will }
        set { categoryRaw = newValue.rawValue }
    }

    // MARK: - Init
    init(
        title: String,
        details: String? = nil,
        deadline: Date? = nil,
        xpReward: Int = 25,           // tasks default to more XP than habits since they're one-shot
        category: StatCategory = .will
    ) {
        self.id = UUID()
        self.title = title
        self.details = details
        self.createdAt = .now
        self.deadline = deadline
        self.isCompleted = false
        self.completedAt = nil
        self.xpReward = xpReward
        self.categoryRaw = category.rawValue
    }

    // MARK: - Computed
    var isOverdue: Bool {
        guard let deadline, !isCompleted else { return false }
        return deadline < .now
    }
}
