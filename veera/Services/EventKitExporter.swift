import EventKit
import Foundation
import SwiftData

// One-way push: Veera writes to Apple Calendar / Reminders, never reads back.
// Deleting a Veera record removes its mirror; deleting the Apple-side item
// does NOT affect Veera. See THREAT_MODEL.md M6.
//
// Requires NSCalendarsUsageDescription and NSRemindersUsageDescription in the
// app's Info.plist (Xcode UI step). Without them, requestAccess returns false
// and the exporter no-ops.
@MainActor
enum EventKitExporter {
    static let store = EKEventStore()
    private static let calendarName = "Veera"

    static let habitToggleKey = "veera.eventkit.habits"
    static let taskToggleKey = "veera.eventkit.tasks"

    static var habitMirroringOn: Bool { UserDefaults.standard.bool(forKey: habitToggleKey) }
    static var taskMirroringOn: Bool { UserDefaults.standard.bool(forKey: taskToggleKey) }

    // MARK: - Permission

    static func requestReminders() async -> Bool {
        do {
            return try await store.requestFullAccessToReminders()
        } catch {
            return false
        }
    }

    static func requestEvents() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    // MARK: - Public push API

    static func pushHabitReminder(_ habit: Habit) async throws {
        guard habitMirroringOn, await requestReminders() else { return }
        guard let calendar = ensureCalendar(for: .reminder) else { return }

        let existing = habit.eventKitIdentifier.flatMap { store.calendarItem(withIdentifier: $0) as? EKReminder }
        let reminder = existing ?? EKReminder(eventStore: store)
        reminder.calendar = calendar
        reminder.title = habit.name
        reminder.notes = habit.details

        if let hour = habit.reminderHour, let minute = habit.reminderMinute {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            reminder.recurrenceRules = [recurrenceForCadence(habit.cadence)].compactMap { $0 }
            let trigger = Foundation.Calendar.current.date(from: components)
            if let trigger {
                reminder.alarms = [EKAlarm(absoluteDate: trigger)]
            }
        }

        try store.save(reminder, commit: true)
        habit.eventKitIdentifier = reminder.calendarItemIdentifier
    }

    static func pushTaskDeadline(_ task: TaskItem) async throws {
        guard taskMirroringOn, let deadline = task.deadline, await requestEvents() else { return }
        guard let calendar = ensureCalendar(for: .event) else { return }

        let existing = task.eventKitIdentifier.flatMap { store.event(withIdentifier: $0) }
        let event = existing ?? EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = task.title
        event.notes = task.details
        event.startDate = deadline
        event.endDate = deadline.addingTimeInterval(60 * 30)
        // Alarm 1 hour before deadline.
        event.alarms = [EKAlarm(relativeOffset: -3600)]

        try store.save(event, span: .thisEvent, commit: true)
        task.eventKitIdentifier = event.eventIdentifier
    }

    static func pushStandaloneReminder(_ reminder: Reminder) async throws {
        guard habitMirroringOn, await requestReminders() else { return }
        guard let calendar = ensureCalendar(for: .reminder) else { return }

        let existing = reminder.eventKitIdentifier.flatMap {
            store.calendarItem(withIdentifier: $0) as? EKReminder
        }
        let ek = existing ?? EKReminder(eventStore: store)
        ek.calendar = calendar
        ek.title = reminder.title
        ek.notes = reminder.note
        ek.alarms = [EKAlarm(absoluteDate: reminder.fireAt)]

        try store.save(ek, commit: true)
        reminder.eventKitIdentifier = ek.calendarItemIdentifier
    }

    // MARK: - Removal

    static func remove(habit: Habit) {
        guard let identifier = habit.eventKitIdentifier,
              let item = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        try? store.remove(item, commit: true)
        habit.eventKitIdentifier = nil
    }

    static func remove(task: TaskItem) {
        guard let identifier = task.eventKitIdentifier,
              let event = store.event(withIdentifier: identifier) else { return }
        try? store.remove(event, span: .thisEvent, commit: true)
        task.eventKitIdentifier = nil
    }

    static func remove(reminder: Reminder) {
        guard let identifier = reminder.eventKitIdentifier,
              let item = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        try? store.remove(item, commit: true)
        reminder.eventKitIdentifier = nil
    }

    // MARK: - Re-sync everything

    static func resyncAll(in context: ModelContext) async {
        if habitMirroringOn {
            let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
            for habit in habits where !habit.isArchived {
                try? await pushHabitReminder(habit)
            }
            let reminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
            for reminder in reminders where reminder.isActive {
                try? await pushStandaloneReminder(reminder)
            }
        }
        if taskMirroringOn {
            let tasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
            for task in tasks where !task.isCompleted && task.deadline != nil {
                try? await pushTaskDeadline(task)
            }
        }
    }

    // MARK: - Helpers

    private enum CalendarKind { case event, reminder }

    private static func ensureCalendar(for kind: CalendarKind) -> EKCalendar? {
        let entityType: EKEntityType = kind == .event ? .event : .reminder
        let existing = store.calendars(for: entityType).first { $0.title == calendarName }
        if let existing { return existing }

        let calendar = EKCalendar(for: entityType, eventStore: store)
        calendar.title = calendarName
        calendar.cgColor = CGColor(red: 0xC9 / 255.0, green: 0xA2 / 255.0, blue: 0x4B / 255.0, alpha: 1.0)
        calendar.source = preferredSource(for: entityType)
        do {
            try store.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            return nil
        }
    }

    private static func preferredSource(for entityType: EKEntityType) -> EKSource? {
        // Prefer local (no iCloud) source; fall back to whatever's available.
        let sources = store.sources
        return sources.first { $0.sourceType == .local }
            ?? sources.first { entityType == .reminder ? $0.sourceType != .birthdays : true }
    }

    private static func recurrenceForCadence(_ cadence: Cadence) -> EKRecurrenceRule? {
        switch cadence {
        case .daily:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly:
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .customDays(let days):
            guard !days.isEmpty else { return nil }
            let weekdays = days.map { EKRecurrenceDayOfWeek(EKWeekday(rawValue: weekdayMap($0)) ?? .monday) }
            return EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: weekdays,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: nil
            )
        }
    }

    private static func weekdayMap(_ day: Weekday) -> Int {
        switch day {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
}
