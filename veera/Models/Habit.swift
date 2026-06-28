import Foundation
import SwiftData

@Model
final class Habit {
    // MARK: - Identity
    var id: UUID
    var name: String                          // "Train · 1 hour"
    var details: String?                      // optional longer description / note
    var createdAt: Date
    var isArchived: Bool                      // soft delete — keeps history intact

    // MARK: - Reward
    var xpReward: Int                         // XP granted per completion
    var categoryRaw: String                   // StatCategory raw value

    var category: StatCategory {
        get { StatCategory(rawValue: categoryRaw) ?? .will }
        set { categoryRaw = newValue.rawValue }
    }

    // MARK: - Schedule
    // Cadence is encoded as Data (JSON) because enums-with-associated-values
    // don't play nicely as SwiftData properties yet. This is the cleanest workaround.
    var cadenceData: Data

    var cadence: Cadence {
        get {
            (try? JSONDecoder().decode(Cadence.self, from: cadenceData)) ?? .daily
        }
        set {
            cadenceData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    // MARK: - Reminders
    // Hour/minute components for the daily fire time. nil means no reminder.
    // We split hour and minute as Ints rather than storing a full Date,
    // because the date part is meaningless — only the time of day matters.
    var reminderHour: Int?
    var reminderMinute: Int?

    // Identifier of the mirrored EKReminder in Apple Reminders, if mirroring is on.
    // Nil = not mirrored. See `EventKitExporter`.
    var eventKitIdentifier: String?

    // MARK: - Relationships
    // .cascade — deleting a Habit deletes its completion history too.
    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion] = []

    // MARK: - Init
    init(
        name: String,
        details: String? = nil,
        xpReward: Int = 10,
        category: StatCategory = .will,
        cadence: Cadence = .daily,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.details = details
        self.createdAt = .now
        self.isArchived = false
        self.xpReward = xpReward
        self.categoryRaw = category.rawValue
        self.cadenceData = (try? JSONEncoder().encode(cadence)) ?? Data()
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }

    // MARK: - Computed
    // True if this habit was completed today (in the user's local calendar).
    func isCompleted(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        completions.contains { calendar.isDate($0.completedAt, inSameDayAs: date) }
    }

    // Current streak — consecutive days from today backward where the habit was completed.
    // Walks backward day-by-day, stops on first miss.
    func currentStreak(calendar: Calendar = .current) -> Int {
        var streak = 0
        var cursor = Date.now
        while isCompleted(on: cursor, calendar: calendar) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}

// MARK: - History helpers
//
// Pure read helpers for HabitDetailView and the future Stats tab. All work off
// the `completions` relationship (already cascade-loaded with the habit) and
// avoid touching the ModelContext, so they're safe to call from view code.
extension Habit {
    var totalCompletions: Int {
        completions.count
    }

    var lastCompletedAt: Date? {
        completions.map(\.completedAt).max()
    }

    // Subset of completions whose `completedAt` falls inside `range`.
    // The caller picks the granularity — usually a 7- or 30-day window.
    func completions(in range: ClosedRange<Date>) -> [HabitCompletion] {
        completions.filter { range.contains($0.completedAt) }
    }

    // [start-of-day → was completed that day] for the last N days, where day N-1
    // is `endingOn` and day 0 is `(N-1)` days earlier. Returned dictionary always
    // contains exactly N entries (missed days are present with value `false`).
    func completionMap(
        days: Int,
        endingOn referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [Date: Bool] {
        guard days > 0 else { return [:] }
        let today = calendar.startOfDay(for: referenceDate)
        var result: [Date: Bool] = [:]
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let normalized = calendar.startOfDay(for: day)
            result[normalized] = isCompleted(on: normalized, calendar: calendar)
        }
        return result
    }

    // Longest run of consecutive days ever completed. Walks unique day-starts
    // in sorted order in linear time. Returns 0 when the habit has no history.
    func longestStreakEver(calendar: Calendar = .current) -> Int {
        let days = Set(completions.map { calendar.startOfDay(for: $0.completedAt) })
        let sortedDays = days.sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var longestRun = 1
        var currentRun = 1
        for index in 1..<sortedDays.count {
            let previous = sortedDays[index - 1]
            let current = sortedDays[index]
            if let dayAfterPrev = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(dayAfterPrev, inSameDayAs: current) {
                currentRun += 1
                longestRun = max(longestRun, currentRun)
            } else {
                currentRun = 1
            }
        }
        return longestRun
    }
}
