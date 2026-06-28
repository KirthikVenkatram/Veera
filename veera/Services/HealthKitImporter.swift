import Foundation
import HealthKit
import SwiftData

// Reads day-level Health summaries and grants XP. Read-only, never writes
// to HealthKit. Idempotency via HealthImportLedger so repeat foreground/BG
// passes don't double-grant.
//
// The HealthKit capability and NSHealthShareUsageDescription must be added in
// Xcode (Signing & Capabilities → +Capability → HealthKit). Without them
// `isAvailable` returns false and every importer is a no-op.
@MainActor
enum HealthKitImporter {
    static let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // Tunable in Settings later; defaults below.
    static let xpPer1000Steps = 1
    static let stepsDailyCapXP = 15
    static let sleepFullXP = 5
    static let sleepPartialXP = 2
    static let xpPer10MindfulMinutes = 1
    static let mindfulnessDailyCapXP = 10
    static let xpPerWorkout = 10
    static let workoutsDailyCapXP = 30

    private static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) { types.insert(mindful) }
        return types
    }

    static let stepsToggleKey = "veera.health.steps"
    static let sleepToggleKey = "veera.health.sleep"
    static let mindfulToggleKey = "veera.health.mindfulness"
    static let workoutsToggleKey = "veera.health.workouts"

    static func requestPermissions() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // Runs every enabled importer once. Called from app foreground.
    static func runEnabled(in context: ModelContext) async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: stepsToggleKey) {
            await importStepsXP(in: context)
        }
        if defaults.bool(forKey: sleepToggleKey) {
            await importSleepXP(in: context)
        }
        if defaults.bool(forKey: mindfulToggleKey) {
            await importMindfulnessXP(in: context)
        }
        if defaults.bool(forKey: workoutsToggleKey) {
            await importWorkoutsXP(in: context)
        }
    }

    // MARK: - Per-source importers

    static func importStepsXP(in context: ModelContext) async {
        guard isAvailable else { return }
        let today = Calendar.current.startOfDay(for: .now)
        guard !alreadyImported(.steps, day: today, in: context) else { return }
        let steps = await sumQuantity(.stepCount, unit: .count(), since: today)
        let xp = min(stepsDailyCapXP, Int(steps / 1000) * xpPer1000Steps)
        award(xp: xp, to: .strength, source: .steps, day: today, in: context)
    }

    static func importSleepXP(in context: ModelContext) async {
        guard isAvailable else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard !alreadyImported(.sleep, day: today, in: context) else { return }
        let hours = await sleepHoursLastNight()
        let xp: Int
        if hours >= 7 {
            xp = sleepFullXP
        } else if hours >= 5 {
            xp = sleepPartialXP
        } else {
            xp = 0
        }
        award(xp: xp, to: .vitality, source: .sleep, day: today, in: context)
    }

    static func importMindfulnessXP(in context: ModelContext) async {
        guard isAvailable, let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return }
        let today = Calendar.current.startOfDay(for: .now)
        guard !alreadyImported(.mindfulness, day: today, in: context) else { return }
        let minutes = await sumMindfulMinutes(type: type, since: today)
        let xp = min(mindfulnessDailyCapXP, Int(minutes / 10) * xpPer10MindfulMinutes)
        award(xp: xp, to: .discipline, source: .mindfulness, day: today, in: context)
    }

    static func importWorkoutsXP(in context: ModelContext) async {
        guard isAvailable else { return }
        let today = Calendar.current.startOfDay(for: .now)
        guard !alreadyImported(.workouts, day: today, in: context) else { return }
        let count = await workoutsCountSince(today)
        let xp = min(workoutsDailyCapXP, count * xpPerWorkout)
        // Workouts grant equally to STR and VIT.
        award(xp: xp / 2, to: .strength, source: .workouts, day: today, in: context)
        award(xp: xp - xp / 2, to: .vitality, source: .workouts, day: today, in: context, skipLedger: true)
    }

    // MARK: - Ledger + award helpers

    private static func alreadyImported(_ source: HealthSource, day: Date, in context: ModelContext) -> Bool {
        let raw = source.rawValue
        let descriptor = FetchDescriptor<HealthImportLedger>(
            predicate: #Predicate { $0.sourceRaw == raw && $0.day == day }
        )
        return (try? context.fetch(descriptor).first) != nil
    }

    private static func award(
        xp: Int,
        to category: StatCategory,
        source: HealthSource,
        day: Date,
        in context: ModelContext,
        skipLedger: Bool = false
    ) {
        guard xp > 0 else {
            if !skipLedger {
                context.insert(HealthImportLedger(source: source, day: day))
                try? context.save()
            }
            return
        }
        let descriptor = FetchDescriptor<Player>()
        if let player = try? context.fetch(descriptor).first {
            player.addXP(xp, to: category)
        }
        if !skipLedger {
            context.insert(HealthImportLedger(source: source, day: day))
        }
        try? context.save()
    }

    // MARK: - HealthKit queries

    private static func sumQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        since start: Date
    ) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum
            ) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(query)
        }
    }

    private static func sleepHoursLastNight() async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let calendar = Calendar.current
        // Window: yesterday 6pm → today noon. Captures the previous night.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now
        let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday) ?? yesterday
        let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                ]
                let seconds = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: seconds / 3600.0)
            }
            store.execute(query)
        }
    }

    private static func sumMindfulMinutes(type: HKCategoryType, since start: Date) async -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                let seconds = (samples ?? [])
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: seconds / 60.0)
            }
            store.execute(query)
        }
    }

    private static func workoutsCountSince(_ start: Date) async -> Int {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(), predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.count ?? 0)
            }
            store.execute(query)
        }
    }
}
