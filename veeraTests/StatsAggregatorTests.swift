import Foundation
import SwiftData
import Testing
@testable import veera

@MainActor
struct StatsAggregatorTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Player.self, Habit.self, HabitCompletion.self, TaskItem.self, Reminder.self,
            RankAchievement.self
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

    // MARK: - Weekly XP

    @Test func weeklyXPReturnsRequestedNumberOfBuckets() throws {
        let context = try makeContext()
        let habit = Habit(name: "Read", xpReward: 10, category: .intellect)
        context.insert(habit)

        let buckets = StatsAggregator.weeklyXP(
            completions: [],
            weeks: 8,
            endingOn: try day(2026, 6, 7),
            calendar: calendar
        )
        #expect(buckets.count == 8)
    }

    @Test func weeklyXPBucketsXPIntoTheRightWeek() throws {
        let context = try makeContext()
        let habit = Habit(name: "Read", xpReward: 10, category: .intellect)
        context.insert(habit)

        let referenceDate = try day(2026, 6, 7)   // Sunday
        let thisWeek = try day(2026, 6, 5)        // Friday — same week as reference
        let lastWeek = try day(2026, 5, 29)       // previous week

        for date in [thisWeek, thisWeek, lastWeek] {
            let completion = HabitCompletion(habit: habit, xpAwarded: 10)
            completion.completedAt = date
            context.insert(completion)
        }

        let completionsArray = [HabitCompletion(habit: habit, xpAwarded: 0)]   // placeholder
        _ = completionsArray
        // Use the @Query-equivalent: fetch all completions for the habit.
        let buckets = StatsAggregator.weeklyXP(
            completions: habit.completions,
            weeks: 8,
            endingOn: referenceDate,
            calendar: calendar
        )

        let thisWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate)
        )
        let lastWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastWeek)
        )

        let thisWeekBucket = try #require(buckets.first(where: { $0.weekStart == thisWeekStart }))
        let lastWeekBucket = try #require(buckets.first(where: { $0.weekStart == lastWeekStart }))

        #expect(thisWeekBucket.totalXP == 20, "two same-week completions of 10 XP should sum to 20")
        #expect(lastWeekBucket.totalXP == 10)
    }

    @Test func weeklyXPIgnoresCompletionsOutsideWindow() throws {
        let context = try makeContext()
        let habit = Habit(name: "Read", xpReward: 10, category: .intellect)
        context.insert(habit)

        let outside = try day(2026, 1, 1)
        let inside = try day(2026, 6, 5)
        for date in [outside, inside] {
            let completion = HabitCompletion(habit: habit, xpAwarded: 10)
            completion.completedAt = date
            context.insert(completion)
        }

        let buckets = StatsAggregator.weeklyXP(
            completions: habit.completions,
            weeks: 8,
            endingOn: try day(2026, 6, 7),
            calendar: calendar
        )

        let total = buckets.reduce(0) { $0 + $1.totalXP }
        #expect(total == 10, "completion in January should be outside the 8-week window from June")
    }

    // MARK: - Per-stat columns

    @Test func statColumnsReturnsAllFiveStats() {
        let player = Player()
        player.strXP = 10
        player.intXP = 20
        player.vitXP = 30

        let columns = StatsAggregator.statColumns(player: player)
        #expect(columns.count == 5)
        let strColumn = columns.first { $0.category == .strength }
        #expect(strColumn?.value == 10)
    }

    // MARK: - Longest streak per category

    @Test func longestStreakByCategoryPicksMaxAcrossHabitsInCategory() throws {
        let context = try makeContext()
        let calendar = Calendar(identifier: .gregorian)

        let read = Habit(name: "Read", xpReward: 10, category: .intellect)
        let study = Habit(name: "Study", xpReward: 10, category: .intellect)
        context.insert(read); context.insert(study)

        // Read: 2-day run. Study: 4-day run. The category result should be 4.
        for dayOffset in 0..<2 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) ?? .now
            let completion = HabitCompletion(habit: read, xpAwarded: 10)
            completion.completedAt = date
            context.insert(completion)
        }
        for dayOffset in 0..<4 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) ?? .now
            let completion = HabitCompletion(habit: study, xpAwarded: 10)
            completion.completedAt = date
            context.insert(completion)
        }

        let streaks = StatsAggregator.longestStreakByCategory(habits: [read, study], calendar: calendar)
        let intStreak = try #require(streaks.first { $0.category == .intellect })
        #expect(intStreak.longest == 4)
    }

    @Test func longestStreakByCategoryIsZeroForUnusedCategories() {
        let streaks = StatsAggregator.longestStreakByCategory(habits: [])
        #expect(streaks.count == 5)
        #expect(streaks.allSatisfy { $0.longest == 0 })
    }

    // MARK: - Rank timeline

    @Test func rankTimelineSortsByAchievementDate() throws {
        let later = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let earlier = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))

        let achievements = [
            RankAchievement(rank: .maravan, achievedAt: later),
            RankAchievement(rank: .veera, achievedAt: earlier)
        ]
        let milestones = StatsAggregator.rankTimeline(achievements: achievements)

        #expect(milestones.first?.rank == .veera)
        #expect(milestones.last?.rank == .maravan)
    }

    @Test func recordRankDoesNotDuplicate() throws {
        let context = try makeContext()
        StatsAggregator.recordRankIfNeeded(.veera, in: context)
        StatsAggregator.recordRankIfNeeded(.veera, in: context)
        let descriptor = FetchDescriptor<RankAchievement>()
        let records = try context.fetch(descriptor)
        #expect(records.count == 1)
    }
}
