import Foundation
import OSLog
import SwiftData
import UserNotifications

enum PersistenceController {
    // Ensures exactly one Player record exists in the database.
    // Called from veeraApp.swift on every launch — no-ops after first launch.
    //
    // We use a static function on an enum (rather than a class) to make it clear
    // this is stateless utility code, not a long-lived service.
    @MainActor
    static func bootstrapPlayerIfNeeded(in context: ModelContext) async {
        let descriptor = FetchDescriptor<Player>()
        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                let player = Player()
                context.insert(player)
                try context.save()
                AppLogger.persistence.info("Bootstrapped new Player: \(player.id.uuidString)")
            }
        } catch {
            AppLogger.persistence.error("Player bootstrap failed: \(error.localizedDescription)")
        }
    }

    // Fetches the singleton Player. Used by views via @Query, but this helper is
    // handy in services where you don't have a SwiftUI environment.
    @MainActor
    static func currentPlayer(in context: ModelContext) -> Player? {
        let descriptor = FetchDescriptor<Player>()
        return try? context.fetch(descriptor).first
    }

    // Wipes every user-owned record and re-bootstraps a fresh, empty Player.
    // Cancels pending notifications too so we don't leak alerts referring to deleted reminders.
    // Destructive — surface a confirmation in the UI before calling.
    @MainActor
    static func resetLocalData(in context: ModelContext) async {
        do {
            try context.delete(model: HabitCompletion.self)
            try context.delete(model: Habit.self)
            try context.delete(model: TaskItem.self)
            try context.delete(model: Reminder.self)
            try context.delete(model: Player.self)
            try context.save()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            AppLogger.persistence.info("Local data reset; re-bootstrapping Player.")
            await bootstrapPlayerIfNeeded(in: context)
        } catch {
            AppLogger.persistence.error("Local data reset failed: \(error.localizedDescription)")
        }
    }
}
