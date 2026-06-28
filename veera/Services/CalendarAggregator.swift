import Foundation
import SwiftData

struct CalendarDateRange: Equatable {
    let start: Date
    let end: Date

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

struct CalendarDaySummary: Identifiable {
    let day: Date
    let habits: [Habit]
    let tasks: [TaskItem]
    let vows: [Vow]
    let xpEarned: Int
    let completionCount: Int

    var id: Date { day }
    var itemCount: Int { habits.count + tasks.count + vows.count }
}

struct HeatmapDay: Identifiable, Equatable {
    let day: Date
    let value: Int
    let intensity: Int

    var id: Date { day }
}

enum CalendarDisplayMode: String, CaseIterable, Hashable {
    case month = "Month"
    case week = "Week"
}

enum CalendarAggregator {
    static func visibleRange(
        containing date: Date,
        mode: CalendarDisplayMode,
        calendar: Calendar = .current
    ) -> CalendarDateRange {
        switch mode {
        case .month:
            return monthRange(containing: date, calendar: calendar)
        case .week:
            return weekRange(containing: date, calendar: calendar)
        }
    }

    static func monthRange(containing date: Date, calendar: Calendar = .current) -> CalendarDateRange {
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return CalendarDateRange(start: start, end: end)
    }

    static func weekRange(containing date: Date, calendar: Calendar = .current) -> CalendarDateRange {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return CalendarDateRange(start: start, end: end)
    }

    static func dayRange(containing date: Date, calendar: Calendar = .current) -> CalendarDateRange {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return CalendarDateRange(start: start, end: end)
    }

    static func days(in range: CalendarDateRange, calendar: Calendar = .current) -> [Date] {
        var result: [Date] = []
        var cursor = calendar.startOfDay(for: range.start)
        while cursor < range.end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    static func monthGridDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let month = monthRange(containing: date, calendar: calendar)
        let firstWeek = weekRange(containing: month.start, calendar: calendar).start
        let lastDay = calendar.date(byAdding: .day, value: -1, to: month.end) ?? month.start
        let lastWeekEnd = weekRange(containing: lastDay, calendar: calendar).end
        return days(in: CalendarDateRange(start: firstWeek, end: lastWeekEnd), calendar: calendar)
    }

    static func summaries(
        days: [Date],
        habits: [Habit],
        tasks: [TaskItem],
        vows: [Vow],
        completions: [HabitCompletion],
        calendar: Calendar = .current
    ) -> [CalendarDaySummary] {
        let normalizedDays = days.map { calendar.startOfDay(for: $0) }
        var xpByDay = Dictionary(uniqueKeysWithValues: normalizedDays.map { ($0, 0) })
        var completionsByDay = Dictionary(uniqueKeysWithValues: normalizedDays.map { ($0, 0) })

        for completion in completions {
            let day = calendar.startOfDay(for: completion.completedAt)
            guard xpByDay[day] != nil else { continue }
            xpByDay[day, default: 0] += completion.xpAwarded
            completionsByDay[day, default: 0] += 1
        }

        return normalizedDays.map { day in
            let dueHabits = habits.filter { habit in
                !habit.isArchived && habit.createdAt < nextDay(after: day, calendar: calendar) && habit.cadence.isDue(on: day, calendar: calendar)
            }
            let dueTasks = tasks.filter { task in
                guard let deadline = task.deadline else { return false }
                return calendar.isDate(deadline, inSameDayAs: day)
            }
            let endingVows = vows.filter { vow in
                calendar.isDate(vow.endDate, inSameDayAs: day)
            }
            return CalendarDaySummary(
                day: day,
                habits: dueHabits,
                tasks: dueTasks,
                vows: endingVows,
                xpEarned: xpByDay[day, default: 0],
                completionCount: completionsByDay[day, default: 0]
            )
        }
    }

    @MainActor
    static func fetchSummaries(
        for range: CalendarDateRange,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> [CalendarDaySummary] {
        let habits = fetchHabits(through: range.end, in: context)
        let tasks = fetchTasks(in: range, context: context)
        let vows = fetchVows(in: range, context: context)
        let completions = fetchCompletions(in: range, context: context)
        return summaries(
            days: days(in: range, calendar: calendar),
            habits: habits,
            tasks: tasks,
            vows: vows,
            completions: completions,
            calendar: calendar
        )
    }

    @MainActor
    static func fetchHeatmap(
        for range: CalendarDateRange,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> [HeatmapDay] {
        let completions = fetchCompletions(in: range, context: context)
        return heatmapDays(days: days(in: range, calendar: calendar), completions: completions, calendar: calendar)
    }

    static func heatmapDays(
        days: [Date],
        completions: [HabitCompletion],
        calendar: Calendar = .current
    ) -> [HeatmapDay] {
        let normalizedDays = days.map { calendar.startOfDay(for: $0) }
        var xpByDay = Dictionary(uniqueKeysWithValues: normalizedDays.map { ($0, 0) })
        for completion in completions {
            let day = calendar.startOfDay(for: completion.completedAt)
            guard xpByDay[day] != nil else { continue }
            xpByDay[day, default: 0] += completion.xpAwarded
        }
        let maxXP = max(1, xpByDay.values.max() ?? 0)
        return normalizedDays.map { day in
            let xp = xpByDay[day, default: 0]
            return HeatmapDay(day: day, value: xp, intensity: intensity(for: xp, maximum: maxXP))
        }
    }

    static func intensity(for value: Int, maximum: Int) -> Int {
        guard value > 0, maximum > 0 else { return 0 }
        let ratio = Double(value) / Double(maximum)
        switch ratio {
        case ..<0.25: return 1
        case ..<0.50: return 2
        case ..<0.75: return 3
        default: return 4
        }
    }

    // SwiftData's `#Predicate` macro is brittle: boolean negation, optional
    // unwraps, and Calendar/component math all trap at fetch time
    // (EXC_BREAKPOINT). Even simple `Date >= Date && Date < Date` forms have
    // tripped here. We deliberately keep all fetches predicate-free and apply
    // every filter (range, archived flag, optional deadline) in plain Swift
    // after the fetch. The volumes here are tiny (a single user's habits and
    // a month-window of completions), so the cost is negligible.

    @MainActor
    static func fetchCompletions(in range: CalendarDateRange, context: ModelContext) -> [HabitCompletion] {
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<HabitCompletion>(
            sortBy: [SortDescriptor(\HabitCompletion.completedAt, order: .forward)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.completedAt >= start && $0.completedAt < end }
    }

    @MainActor
    private static func fetchHabits(through end: Date, in context: ModelContext) -> [Habit] {
        let descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\Habit.createdAt, order: .forward)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { !$0.isArchived && $0.createdAt < end }
    }

    @MainActor
    private static func fetchTasks(in range: CalendarDateRange, context: ModelContext) -> [TaskItem] {
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<TaskItem>(
            sortBy: [SortDescriptor(\TaskItem.deadline, order: .forward)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { task in
            guard let deadline = task.deadline else { return false }
            return deadline >= start && deadline < end
        }
    }

    @MainActor
    private static func fetchVows(in range: CalendarDateRange, context: ModelContext) -> [Vow] {
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<Vow>(
            sortBy: [SortDescriptor(\Vow.endDate, order: .forward)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.endDate >= start && $0.endDate < end }
    }

    private static func nextDay(after day: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: 1, to: day) ?? day
    }
}
