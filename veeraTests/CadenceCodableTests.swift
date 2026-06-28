import Foundation
import Testing
@testable import veera

struct CadenceCodableTests {
    // MARK: - Round-trip

    @Test func dailyRoundTripsThroughCodable() throws {
        let original: Cadence = .daily
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Cadence.self, from: data)
        #expect(decoded == original)
    }

    @Test func weeklyRoundTripsThroughCodable() throws {
        let original: Cadence = .weekly
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Cadence.self, from: data)
        #expect(decoded == original)
    }

    @Test func customDaysRoundTripsThroughCodable() throws {
        let original: Cadence = .customDays([.monday, .wednesday, .friday])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Cadence.self, from: data)
        #expect(decoded == original)
    }

    @Test func emptyCustomDaysRoundTripsAndIsNeverDue() throws {
        let original: Cadence = .customDays([])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Cadence.self, from: data)
        #expect(decoded == original)

        // Empty set means no day matches — isDue should be false for every weekday.
        let calendar = Calendar(identifier: .gregorian)
        for dayNumber in 1...7 {
            let date = try #require(
                calendar.date(from: DateComponents(year: 2026, month: 6, day: dayNumber))
            )
            #expect(decoded.isDue(on: date, calendar: calendar) == false)
        }
    }

    // MARK: - isDue logic

    @Test func customDaysIsDueOnMatchingWeekday() throws {
        // 2026-06-01 is a Monday.
        let calendar = Calendar(identifier: .gregorian)
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))

        let mondayCadence: Cadence = .customDays([.monday])
        #expect(mondayCadence.isDue(on: monday, calendar: calendar) == true)

        let tuesdayCadence: Cadence = .customDays([.tuesday])
        #expect(tuesdayCadence.isDue(on: monday, calendar: calendar) == false)
    }

    @Test func dailyIsDueEveryDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        for dayNumber in 1...7 {
            let date = try #require(
                calendar.date(from: DateComponents(year: 2026, month: 6, day: dayNumber))
            )
            #expect(Cadence.daily.isDue(on: date, calendar: calendar) == true)
        }
    }
}
