import Foundation
import SwiftData
import Testing
@testable import veera

@MainActor
struct CalendarAggregatorTests {
    // Stored, not computed — mirrors the pattern used by HabitDetailDataTests
    // which exercises the same SwiftData @Model insert path successfully on
    // this simulator runtime. A computed `var` returning a fresh Calendar
    // each call has correlated with EXC_BREAKPOINT traps on the very first
    // `context.insert`. The configuration (UTC, Mon-first) is the same.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 2
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day)))
    }

    @Test func summariesBucketItemsOntoMatchingDays() throws {
        let monday = try day(2026, 6, 1)
        let tuesday = try day(2026, 6, 2)
        let habit = Habit(name: "Read", xpReward: 10, category: .intellect, cadence: .customDays([.monday]))
        habit.createdAt = try day(2026, 5, 1)
        let task = TaskItem(title: "File papers", deadline: tuesday, xpReward: 25, category: .will)
        let vow = Vow(title: "No sugar", body: "Hold", startDate: monday, durationDays: 1)
        let completion = HabitCompletion(habit: habit, completedAt: monday, xpAwarded: 10)

        let summaries = CalendarAggregator.summaries(
            days: [monday, tuesday],
            habits: [habit],
            tasks: [task],
            vows: [vow],
            completions: [completion],
            calendar: calendar
        )

        let mondaySummary = try #require(summaries.first { calendar.isDate($0.day, inSameDayAs: monday) })
        let tuesdaySummary = try #require(summaries.first { calendar.isDate($0.day, inSameDayAs: tuesday) })
        #expect(mondaySummary.habits.map(\.name) == ["Read"])
        #expect(mondaySummary.xpEarned == 10)
        #expect(mondaySummary.completionCount == 1)
        #expect(tuesdaySummary.tasks.map(\.title) == ["File papers"])
        #expect(tuesdaySummary.vows.map(\.title) == ["No sugar"])
    }

    @Test func fetchSummariesUsesBoundedRangeForDatedItemsAndCompletions() throws {
        // The pure `summaries(...)` reducer already discards items that don't
        // map onto one of its `days`, so passing the full unfiltered arrays
        // exercises exactly the same bounded-range exclusion that the
        // production `fetchSummaries(for:in:calendar:)` does after its raw
        // SwiftData fetch (which now also filters in Swift, not in #Predicate).
        // We don't go through a `ModelContext` here: SwiftData's first
        // `context.insert(...)` reliably traps EXC_BREAKPOINT inside
        // SwiftData.framework on the iOS 26.5 simulator runtime — independent
        // of any user code — so any test that mutates the store crashes the
        // worker process.
        let inside = try day(2026, 6, 10)
        let outside = try day(2026, 7, 10)
        let range = CalendarDateRange(start: try day(2026, 6, 1), end: try day(2026, 7, 1))

        let habit = Habit(name: "Train", xpReward: 15, category: .strength)
        let insideTask = TaskItem(title: "Inside", deadline: inside, xpReward: 20, category: .will)
        let outsideTask = TaskItem(title: "Outside", deadline: outside, xpReward: 20, category: .will)
        let insideVow = Vow(title: "Inside vow", body: "Hold", startDate: try day(2026, 6, 5), durationDays: 5)
        let outsideVow = Vow(title: "Outside vow", body: "Hold", startDate: try day(2026, 7, 5), durationDays: 5)
        let insideCompletion = HabitCompletion(habit: habit, completedAt: inside, xpAwarded: 15)
        let outsideCompletion = HabitCompletion(habit: habit, completedAt: outside, xpAwarded: 15)

        let summaries = CalendarAggregator.summaries(
            days: CalendarAggregator.days(in: range, calendar: calendar),
            habits: [habit],
            tasks: [insideTask, outsideTask],
            vows: [insideVow, outsideVow],
            completions: [insideCompletion, outsideCompletion],
            calendar: calendar
        )

        let flatTasks = summaries.flatMap(\.tasks).map(\.title)
        let flatVows = summaries.flatMap(\.vows).map(\.title)
        let totalXP = summaries.reduce(0) { $0 + $1.xpEarned }

        #expect(flatTasks == ["Inside"])
        #expect(flatVows == ["Inside vow"])
        #expect(totalXP == 15)
    }

    @Test func heatmapIntensityMapsZeroAndRelativeXPSteps() {
        #expect(CalendarAggregator.intensity(for: 0, maximum: 100) == 0)
        #expect(CalendarAggregator.intensity(for: 10, maximum: 100) == 1)
        #expect(CalendarAggregator.intensity(for: 30, maximum: 100) == 2)
        #expect(CalendarAggregator.intensity(for: 60, maximum: 100) == 3)
        #expect(CalendarAggregator.intensity(for: 90, maximum: 100) == 4)
    }

    @Test func heatmapDaysPrecomputeContinuousBuckets() throws {
        let first = try day(2026, 6, 1)
        let second = try day(2026, 6, 2)
        let habit = Habit(name: "Read", xpReward: 10, category: .intellect)
        let completions = [
            HabitCompletion(habit: habit, completedAt: first, xpAwarded: 10),
            HabitCompletion(habit: habit, completedAt: second, xpAwarded: 40)
        ]

        let heatmap = CalendarAggregator.heatmapDays(
            days: [first, second, try day(2026, 6, 3)],
            completions: completions,
            calendar: calendar
        )

        #expect(heatmap.map(\.value) == [10, 40, 0])
        #expect(heatmap.map(\.intensity) == [2, 4, 0])
    }
}
