import Foundation
import OSLog
import SwiftData
import UserNotifications

enum NotificationService {
    // Key shared with the @AppStorage toggle in Settings.
    // Reading via UserDefaults (not @AppStorage) so the service stays View-free.
    static let hideLockScreenContentKey = "veera.hideLockScreenContent"

    // Default ON — generic content on the lock screen, real content in userInfo.
    // This is the M4 mitigation per THREAT_MODEL.md.
    static var hideLockScreenContent: Bool {
        UserDefaults.standard.object(forKey: hideLockScreenContentKey) as? Bool ?? true
    }

    static func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
        } catch {
            AppLogger.notifications.error("Notification auth error: \(error.localizedDescription)")
        }
    }

    static func schedule(reminder: Reminder) async {
        guard reminder.isActive else { return }

        // Request authorization on first reminder creation rather than at app launch.
        // The system only prompts once — subsequent calls when status is determined are no-ops.
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            await requestAuthorization()
        }

        let content = UNMutableNotificationContent()
        let realTitle = reminder.title
        let realBody = reminder.note ?? "A quest awaits."

        if hideLockScreenContent {
            // Generic surface content — what shows up on the lock screen / notification list.
            content.title = "Veera"
            content.body = "A quest awaits."
            // Real content travels in userInfo so the app can reconstruct it
            // when handling delivery from foreground.
            content.userInfo = [
                "reminderId": reminder.id.uuidString,
                "realTitle": realTitle,
                "realBody": realBody
            ]
        } else {
            content.title = realTitle
            content.body = realBody
            content.userInfo = ["reminderId": reminder.id.uuidString]
        }
        content.sound = .default

        let trigger: UNNotificationTrigger
        switch reminder.repeatPattern {
        case .once:
            trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: reminder.fireAt
                ),
                repeats: false
            )
        case .daily:
            trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.hour, .minute], from: reminder.fireAt),
                repeats: true
            )
        case .weekly:
            trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.weekday, .hour, .minute],
                    from: reminder.fireAt
                ),
                repeats: true
            )
        }

        // UNUserNotificationCenter.add replaces any existing request with the same
        // identifier, so re-scheduling after a privacy-toggle change works without
        // an explicit cancel step.
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            AppLogger.questActions.info("reminder.scheduled id=\(reminder.id.uuidString, privacy: .public) pattern=\(reminder.repeatPattern.rawValue, privacy: .public)")
        } catch {
            AppLogger.notifications.error("Notification scheduling failed: \(error.localizedDescription)")
        }
    }

    static func cancel(reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [reminder.id.uuidString]
        )
        AppLogger.questActions.info("reminder.cancelled id=\(reminder.id.uuidString, privacy: .public)")
    }

    // Re-schedules every active reminder. Used when the lock-screen privacy
    // toggle changes — existing scheduled requests still carry the old content
    // until they're replaced.
    @MainActor
    static func rescheduleAll(in context: ModelContext) async {
        let descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.isActive })
        guard let reminders = try? context.fetch(descriptor) else { return }
        for reminder in reminders {
            await schedule(reminder: reminder)
        }
        AppLogger.notifications.info("Rescheduled \(reminders.count) active reminders after privacy toggle.")
    }
}

// MARK: - Delegate

// Handles foreground delivery so notifications still surface a banner while
// the app is open. Holds a strong reference via `.shared` since
// UNUserNotificationCenter.delegate is weak.
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {
        super.init()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Foreground delivery: let iOS display the system banner with whatever
        // content was scheduled. When `hideLockScreenContent` is on, that's the
        // generic "A quest awaits." — full content is in `userInfo`, and the
        // Quest list in-app shows every reminder by title anyway.
        [.banner, .sound, .list]
    }
}
