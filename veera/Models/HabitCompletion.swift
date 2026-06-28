import Foundation
import SwiftData

@Model
final class HabitCompletion {
    var id: UUID
    var completedAt: Date
    var xpAwarded: Int              // snapshot of XP at completion time — important if XP rewards change later
    var habit: Habit?               // inverse relationship; nil only briefly during deletion

    init(habit: Habit, completedAt: Date = .now, xpAwarded: Int) {
        self.id = UUID()
        self.habit = habit
        self.completedAt = completedAt
        self.xpAwarded = xpAwarded
    }
}
