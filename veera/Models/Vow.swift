import Foundation
import SwiftData

// A long-form commitment. Vows are intentionally outside the XP/streak loop —
// the weight is the vow itself, not the gamified reward.
@Model
final class Vow {
    var id: UUID
    var title: String
    var body: String
    var startDate: Date
    var endDate: Date
    var isBroken: Bool
    var brokenAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \VowCheckIn.vow)
    var checkIns: [VowCheckIn] = []

    init(
        title: String,
        body: String,
        startDate: Date = .now,
        durationDays: Int
    ) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.startDate = startDate
        self.endDate = Calendar.current.date(byAdding: .day, value: durationDays, to: startDate) ?? startDate
        self.isBroken = false
        self.brokenAt = nil
    }

    func checkIn(on date: Date = .now, calendar: Calendar = .current) -> VowCheckIn? {
        checkIns.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    var daysRemaining: Int {
        let days = Calendar.current.dateComponents([.day], from: .now, to: endDate).day ?? 0
        return max(0, days)
    }

    // Active = within duration window AND not yet expired by date.
    var isActive: Bool {
        Date.now <= endDate
    }
}

@Model
final class VowCheckIn {
    var id: UUID
    var vow: Vow?
    var date: Date
    var kept: Bool

    init(vow: Vow, date: Date = .now, kept: Bool) {
        self.id = UUID()
        self.vow = vow
        self.date = Calendar.current.startOfDay(for: date)
        self.kept = kept
    }
}
