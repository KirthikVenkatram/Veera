import Foundation
import Testing
@testable import veera

struct StreakEngineTests {
    @Test func firstActivityStartsStreak() {
        let player = Player()
        let day = Date(timeIntervalSince1970: 1_800_000_000)

        StreakEngine.recordActivity(for: player, on: day)

        #expect(player.currentStreak == 1)
        #expect(player.longestStreak == 1)
    }

    @Test func consecutiveDaysIncrementStreak() throws {
        let player = Player()
        let calendar = Calendar(identifier: .gregorian)
        let first = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let second = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2)))

        StreakEngine.recordActivity(for: player, on: first, calendar: calendar)
        StreakEngine.recordActivity(for: player, on: second, calendar: calendar)

        #expect(player.currentStreak == 2)
        #expect(player.longestStreak == 2)
    }

    @Test func skippedDayRestartsStreak() throws {
        let player = Player()
        let calendar = Calendar(identifier: .gregorian)
        let first = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let third = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3)))

        StreakEngine.recordActivity(for: player, on: first, calendar: calendar)
        StreakEngine.recordActivity(for: player, on: third, calendar: calendar)

        #expect(player.currentStreak == 1)
        #expect(player.longestStreak == 1)
    }

    @Test func missedHabitYesterdayIsDetected() throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 4)))
        let habit = Habit(name: "Read", xpReward: 10, category: .intellect)

        let missed = StreakEngine.missedHabitsYesterday(
            habits: [habit],
            referenceDate: today,
            calendar: calendar
        )

        #expect(missed.count == 1)
    }

    @Test func missedDayPenaltyIsIdempotentSameDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let twoDaysAgo = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 3)))
        let today = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 5)))

        let player = Player(totalXP: 100, difficulty: .hard)
        player.lastActiveDate = twoDaysAgo

        let habit = Habit(name: "Read", xpReward: 10, category: .intellect)

        StreakEngine.applyMissedDayIfNeeded(for: player, habits: [habit], referenceDate: today, calendar: calendar)
        let xpAfterFirstCall = player.totalXP

        StreakEngine.applyMissedDayIfNeeded(for: player, habits: [habit], referenceDate: today, calendar: calendar)

        #expect(xpAfterFirstCall < 100, "first call should have deducted the hard-mode penalty")
        #expect(player.totalXP == xpAfterFirstCall, "a second same-day call must not penalize again")
    }

    @Test func computeStreakHandlesNoActivity() {
        let result = StreakEngine.computeStreak(activityDays: [])
        #expect(result.streak == 0)
        #expect(result.lastActive == nil)
    }

    @Test func computeStreakCountsConsecutiveDaysOnly() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = { (dayNumber: Int) in
            calendar.startOfDay(for: try #require(
                calendar.date(from: DateComponents(year: 2026, month: 6, day: dayNumber))
            ))
        }

        // Active days: Jun 3, 4, 5 (3 consecutive ending Jun 5) AND Jun 1 (isolated).
        // The streak should reflect only the most recent consecutive run.
        let activityDays: Set<Date> = try [day(1), day(3), day(4), day(5)]

        let result = StreakEngine.computeStreak(activityDays: activityDays, calendar: calendar)
        #expect(result.streak == 3)
        #expect(result.lastActive == (try day(5)))
    }
}
