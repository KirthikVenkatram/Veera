import Foundation
import OSLog
import SwiftData

enum StreakEngine {
    static func recordActivity(for player: Player, on date: Date = .now, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)

        guard let lastActiveDate = player.lastActiveDate else {
            player.currentStreak = max(1, player.currentStreak)
            player.longestStreak = max(player.longestStreak, player.currentStreak)
            player.lastActiveDate = day
            return
        }

        let lastDay = calendar.startOfDay(for: lastActiveDate)

        if calendar.isDate(lastDay, inSameDayAs: day) {
            player.longestStreak = max(player.longestStreak, player.currentStreak)
            return
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
           calendar.isDate(lastDay, inSameDayAs: yesterday) {
            player.currentStreak += 1
        } else {
            player.currentStreak = 1
        }

        player.longestStreak = max(player.longestStreak, player.currentStreak)
        player.lastActiveDate = day
    }

    static func missedHabitsYesterday(
        habits: [Habit],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [Habit] {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate) else {
            return []
        }

        return habits.filter { habit in
            !habit.isArchived
            && habit.cadence.isDue(on: yesterday, calendar: calendar)
            && !habit.isCompleted(on: yesterday, calendar: calendar)
        }
    }

    // Pure helper that reconstructs the streak from a set of activity-day starts.
    // Walks back from `mostRecent` counting consecutive days present in `activityDays`.
    // Returns (newStreak, newLastActive). If `activityDays` is empty, returns (0, nil).
    // Exposed for testability — recompute(for:in:) does the SwiftData fetching.
    static func computeStreak(
        activityDays: Set<Date>,
        calendar: Calendar = .current
    ) -> (streak: Int, lastActive: Date?) {
        guard let mostRecent = activityDays.max() else {
            return (0, nil)
        }

        var streak = 1
        var cursor = mostRecent
        while let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor),
              activityDays.contains(previousDay) {
            streak += 1
            cursor = previousDay
        }
        return (streak, mostRecent)
    }

    // Rebuilds player.currentStreak + lastActiveDate from the persisted record of
    // activity (HabitCompletion timestamps + completed TaskItem.completedAt).
    // Used after an undo so the streak honestly reflects what's still on disk.
    //
    // We deliberately do NOT touch `longestStreak` — that's a historical max, not
    // a derived value, and an undo shouldn't erase a record you previously held.
    @MainActor
    static func rebuildStreak(
        for player: Player,
        in context: ModelContext,
        calendar: Calendar = .current
    ) {
        let completions = (try? context.fetch(FetchDescriptor<HabitCompletion>())) ?? []
        let completedTasks = (try? context.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isCompleted })
        )) ?? []

        var activityDays: Set<Date> = []
        for completion in completions {
            activityDays.insert(calendar.startOfDay(for: completion.completedAt))
        }
        for task in completedTasks {
            if let completedAt = task.completedAt {
                activityDays.insert(calendar.startOfDay(for: completedAt))
            }
        }

        let result = computeStreak(activityDays: activityDays, calendar: calendar)
        player.currentStreak = result.streak
        player.lastActiveDate = result.lastActive
    }

    static func applyMissedDayIfNeeded(
        for player: Player,
        habits: [Habit],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) {
        guard let lastActiveDate = player.lastActiveDate else { return }
        let today = calendar.startOfDay(for: referenceDate)
        let lastDay = calendar.startOfDay(for: lastActiveDate)
        guard lastDay < today else { return }

        if let lastChecked = player.lastMissCheckedDate,
           calendar.isDate(calendar.startOfDay(for: lastChecked), inSameDayAs: today) {
            return
        }

        let missed = missedHabitsYesterday(
            habits: habits,
            referenceDate: referenceDate,
            calendar: calendar
        )

        player.lastMissCheckedDate = today

        guard !missed.isEmpty else { return }
        player.currentStreak = 0
        XPEngine.applyMissPenalty(to: player, missedCount: missed.count)
        AppLogger.questActions.info("missed.penalty mode=\(player.difficulty.rawValue, privacy: .public) missed=\(missed.count, privacy: .public)")
    }
}
