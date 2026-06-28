import Foundation
import SwiftData
import Testing
@testable import veera

// Covers the read-helpers on Habit that HabitDetailView consumes:
// - completions(in:) date-range filter
// - completionMap(days:endingOn:calendar:) — including the today/6-days-ago
//   inclusivity boundary and the 8-days-ago exclusion
// - longestStreakEver() consecutive-day walk
//
// Uses an in-memory ModelContainer so the @Relationship inverse between
// Habit.completions and HabitCompletion.habit wires up correctly.
@MainActor
struct HabitDetailDataTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Player.self, Habit.self, HabitCompletion.self, TaskItem.self, Reminder.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container.mainContext
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    @Test func dateRangeFilterIncludesOnlyMatchingCompletions() throws {
        let context = try makeContext()
        let habit = Habit(name: "Read", xpReward: 10, category: .intellect)
        context.insert(habit)

        let day1 = try day(2026, 6, 1)
        let day3 = try day(2026, 6, 3)
        let day5 = try day(2026, 6, 5)
        let day10 = try day(2026, 6, 10)

        for date in [day1, day3, day5, day10] {
            let completion = HabitCompletion(habit: habit, xpAwarded: 10)
            completion.completedAt = date
            context.insert(completion)
        }

        let range = try day(2026, 6, 2)...day(2026, 6, 6)
        let matched = habit.completions(in: range)

        let matchedDates = Set(matched.map(\.completedAt))
        #expect(matched.count == 2)
        #expect(matchedDates.contains(day3))
        #expect(matchedDates.contains(day5))
        #expect(matchedDates.contains(day1) == false)
        #expect(matchedDates.contains(day10) == false)
    }

    @Test func completionMapHasExactlyNEntriesAndCorrectKeys() throws {
        let context = try makeContext()
        let habit = Habit(name: "Read", xpReward: 10, category: .intellect)
        context.insert(habit)

        let today = try day(2026, 6, 7)
        let map = habit.completionMap(days: 7, endingOn: today, calendar: calendar)

        #expect(map.count == 7)

        // Keys must be exactly today, today-1, ..., today-6 (all start-of-day).
        for offset in 0..<7 {
            let expected = try #require(calendar.date(byAdding: .day, value: -offset, to: today))
            let normalized = calendar.startOfDay(for: expected)
            #expect(map[normalized] != nil, "missing day at offset \(offset)")
        }
    }

    @Test func completionMapMarksRecentDaysAsCompletedAndExcludesOlder() throws {
        let context = try makeContext()
        let habit = Habit(name: "Read", xpReward: 10, category: .intellect)
        context.insert(habit)

        let today = try day(2026, 6, 7)
        let yesterday = try day(2026, 6, 6)
        let sixDaysAgo = try day(2026, 6, 1)
        let eightDaysAgo = try day(2026, 5, 30)

        for date in [today, yesterday, sixDaysAgo, eightDaysAgo] {
            let completion = HabitCompletion(habit: habit, xpAwarded: 10)
            completion.completedAt = date
            context.insert(completion)
        }

        let map = habit.completionMap(days: 7, endingOn: today, calendar: calendar)

        // Today, yesterday, and 6-days-ago all fall inside the 7-day window.
        #expect(map[calendar.startOfDay(for: today)] == true)
        #expect(map[calendar.startOfDay(for: yesterday)] == true)
        #expect(map[calendar.startOfDay(for: sixDaysAgo)] == true)

        // 8-days-ago is outside the window — it should not appear as a key,
        // even though a completion exists for that date.
        #expect(map[calendar.startOfDay(for: eightDaysAgo)] == nil)

        // Days inside the window with no completion should be present with `false`.
        let twoDaysAgo = try day(2026, 6, 5)
        #expect(map[calendar.startOfDay(for: twoDaysAgo)] == false)
    }

    @Test func longestStreakEverWalksConsecutiveDays() throws {
        let context = try makeContext()
        let habit = Habit(name: "Read", xpReward: 10, category: .intellect)
        context.insert(habit)

        // Two runs: Jun 1-3 (3 days), then Jun 7-11 (5 days). Plus one isolated day.
        let dates: [Date] = try [
            day(2026, 6, 1),
            day(2026, 6, 2),
            day(2026, 6, 3),
            day(2026, 6, 5),   // isolated
            day(2026, 6, 7),
            day(2026, 6, 8),
            day(2026, 6, 9),
            day(2026, 6, 10),
            day(2026, 6, 11)
        ]
        for date in dates {
            let completion = HabitCompletion(habit: habit, xpAwarded: 10)
            completion.completedAt = date
            context.insert(completion)
        }

        #expect(habit.longestStreakEver(calendar: calendar) == 5)
    }

    @Test func longestStreakEverIsZeroWithNoCompletions() throws {
        let context = try makeContext()
        let habit = Habit(name: "Read", xpReward: 10, category: .intellect)
        context.insert(habit)

        #expect(habit.longestStreakEver(calendar: calendar) == 0)
    }
}
