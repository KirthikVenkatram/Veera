import Foundation
import SwiftData

// Tracks which (HealthKit source, calendar day) pairs we've already imported,
// so an app foreground / background refresh can run repeatedly without
// granting XP twice for the same day's reading.
@Model
final class HealthImportLedger {
    var id: UUID
    var sourceRaw: String
    var day: Date

    var source: HealthSource {
        get { HealthSource(rawValue: sourceRaw) ?? .steps }
        set { sourceRaw = newValue.rawValue }
    }

    init(source: HealthSource, day: Date) {
        self.id = UUID()
        self.sourceRaw = source.rawValue
        self.day = day
    }
}

nonisolated enum HealthSource: String, Codable, CaseIterable, Sendable {
    case steps
    case sleep
    case mindfulness
    case workouts
}
