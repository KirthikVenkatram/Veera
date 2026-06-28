import Foundation
import SwiftData

// Owns the ModelContainer used by both the main app and the widget extension.
// Stores the SwiftData SQLite file inside the App Group container
// (`group.com.kv.veera.shared`) so the widget process can read/write the
// same store as the app.
//
// Falls back to the default SwiftData location when the App Group entitlement
// hasn't been added yet (the build setting requires an Xcode UI change). This
// lets the codebase build before the capability is wired up; once the
// entitlement is in place, both processes start pointing at the shared file.
enum SharedPersistence {
    static let appGroupID = "group.com.kv.veera.shared"

    static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("veera.store")
    }

    static func makeContainer() throws -> ModelContainer {
        // Build the Schema from SchemaV1.models so the live store and the
        // versioned baseline can never drift apart.
        let schema = Schema(versionedSchema: SchemaV1.self)

        if let storeURL {
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(
                for: schema,
                migrationPlan: VeeraMigrationPlan.self,
                configurations: configuration
            )
        }
        // Fallback — App Group not yet provisioned. Default location.
        return try ModelContainer(
            for: schema,
            migrationPlan: VeeraMigrationPlan.self
        )
    }
}

// MARK: - Versioned schema

// Baseline schema (1.0.0). Its `models` array is the single source of truth for
// which @Model types the store persists. Future schema changes add a SchemaV2,
// SchemaV3, … and a migration stage between them.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Player.self, Habit.self, HabitCompletion.self,
            TaskItem.self, Reminder.self, RankAchievement.self,
            HealthImportLedger.self, Vow.self, VowCheckIn.self
        ]
    }
}

// Migration plan. Empty stages for now — SchemaV1 is the baseline, so there's
// nothing to migrate from. Add stages here when SchemaV2 lands.
enum VeeraMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
