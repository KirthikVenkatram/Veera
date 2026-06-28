import Foundation
import OSLog
import SwiftData

// Pure aggregations for the Stats tab. Views consume these structs and never
// touch SwiftData queries directly. The `@MainActor` entry points handle the
// ModelContext fetching; the inner pure helpers are testable without one.
enum StatsAggregator {
    struct WeeklyXP: Identifiable, Equatable {
        let weekStart: Date
        let totalXP: Int
        var id: Date { weekStart }
    }

    struct StatColumn: Identifiable, Equatable {
        let category: StatCategory
        let value: Int
        var id: StatCategory { category }
    }

    struct CategoryStreak: Identifiable, Equatable {
        let category: StatCategory
        let longest: Int
        var id: StatCategory { category }
    }

    struct RankMilestone: Identifiable, Equatable {
        let rank: Rank
        let achievedAt: Date
        var id: Rank { rank }
    }

    // MARK: - Weekly XP rollup

    // Sums xpAwarded across HabitCompletions, bucketed by the start of each week.
    // Returns the last `weeks` weeks in chronological order, with empty buckets
    // included so the chart axis stays continuous.
    static func weeklyXP(
        completions: [HabitCompletion],
        weeks: Int = 8,
        endingOn referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [WeeklyXP] {
        guard weeks > 0 else { return [] }
        let endWeekStart = startOfWeek(for: referenceDate, calendar: calendar)
        var buckets: [Date: Int] = [:]
        for offset in 0..<weeks {
            guard let date = calendar.date(byAdding: .weekOfYear, value: -offset, to: endWeekStart) else { continue }
            buckets[date] = 0
        }
        for completion in completions {
            let weekStart = startOfWeek(for: completion.completedAt, calendar: calendar)
            if buckets[weekStart] != nil {
                buckets[weekStart, default: 0] += completion.xpAwarded
            }
        }
        return buckets
            .sorted { $0.key < $1.key }
            .map { WeeklyXP(weekStart: $0.key, totalXP: $0.value) }
    }

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    // MARK: - Per-stat columns

    static func statColumns(player: Player) -> [StatColumn] {
        StatCategory.allCases.map { StatColumn(category: $0, value: player.points(for: $0)) }
    }

    // MARK: - Longest streak per category

    // For each stat category, find the longest streak across every non-archived
    // habit that feeds it. A category with no habits returns 0.
    static func longestStreakByCategory(
        habits: [Habit],
        calendar: Calendar = .current
    ) -> [CategoryStreak] {
        StatCategory.allCases.map { category in
            let inCategory = habits.filter { !$0.isArchived && $0.category == category }
            let longest = inCategory
                .map { $0.longestStreakEver(calendar: calendar) }
                .max() ?? 0
            return CategoryStreak(category: category, longest: longest)
        }
    }

    // MARK: - Rank-up timeline

    static func rankTimeline(achievements: [RankAchievement]) -> [RankMilestone] {
        achievements
            .sorted { $0.achievedAt < $1.achievedAt }
            .map { RankMilestone(rank: $0.rank, achievedAt: $0.achievedAt) }
    }

    // MARK: - Daily XP map (heatmap)

    // [start-of-day → XP earned that day] for the given calendar year.
    // Only days with XP are present — caller fills zeros for the rest.
    @MainActor
    static func dailyXPMap(forYear year: Int, in context: ModelContext, calendar: Calendar = .current) -> [Date: Int] {
        let completions = (try? context.fetch(FetchDescriptor<HabitCompletion>())) ?? []
        var map: [Date: Int] = [:]
        for completion in completions {
            let components = calendar.dateComponents([.year], from: completion.completedAt)
            guard components.year == year else { continue }
            let day = calendar.startOfDay(for: completion.completedAt)
            map[day, default: 0] += completion.xpAwarded
        }
        return map
    }

    // Current per-stat values, for the radar polygon.
    @MainActor
    static func statValues(in context: ModelContext) -> [StatCategory: Int] {
        guard let player = try? context.fetch(FetchDescriptor<Player>()).first else { return [:] }
        var result: [StatCategory: Int] = [:]
        for category in StatCategory.allCases {
            result[category] = player.points(for: category)
        }
        return result
    }

    // Records a rank achievement if one for that rank doesn't already exist.
    // Call after every XP award so we capture the moment the rank changed.
    @MainActor
    static func recordRankIfNeeded(_ rank: Rank, in context: ModelContext, at date: Date = .now) {
        let target = rank.rawValue
        var descriptor = FetchDescriptor<RankAchievement>(
            predicate: #Predicate { $0.rankRaw == target }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor), !existing.isEmpty { return }
        context.insert(RankAchievement(rank: rank, achievedAt: date))
        try? context.save()
        // Log the case identifier ("vendhan"), not the display title — secret rank
        // names must never leak into OSLog before the user has unlocked them.
        AppLogger.progression.info("rank.crossover case=\(rank.caseName, privacy: .public)")
    }
}
