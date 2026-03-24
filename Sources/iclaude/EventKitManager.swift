import EventKit
import Foundation

final class EventKitManager {

    let store = EKEventStore()

    func requestAccess() async throws {

        let status = EKEventStore.authorizationStatus(for: .reminder)

        if status == .fullAccess { return }

        if status == .denied || status == .restricted {
            throw CLIError.accessDenied
        }

        try await store.requestFullAccessToReminders()

        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else {
            throw CLIError.accessDenied
        }
    }

    func allLists() -> [EKCalendar] {
        store.calendars(for: .reminder)
    }

    func list(named name: String) throws -> EKCalendar {

        guard let calendar = store.calendars(for: .reminder)
            .first(where: { $0.title.lowercased() == name.lowercased() })
        else {
            throw CLIError.listNotFound(name)
        }
        return calendar
    }

    func reminders(in calendar: EKCalendar) async throws -> [EKReminder] {

        try await withCheckedThrowingContinuation { continuation in
            let predicate = store.predicateForReminders(in: [calendar])
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    func reminder(titled title: String, in calendar: EKCalendar) async throws -> EKReminder {

        let all = try await reminders(in: calendar)
        let matches = all.filter { $0.title == title }

        switch matches.count {
        case 0:
            throw CLIError.reminderNotFound(title, calendar.title)
        case 1:
            return matches[0]
        default:
            // Prefer the first incomplete one; if all completed, error with count
            if let incomplete = matches.first(where: { !$0.isCompleted }) {
                return incomplete
            }
            throw CLIError.multipleRemindersFound(title, calendar.title, matches.count)
        }
    }

    func newReminder(in calendar: EKCalendar) -> EKReminder {

        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        return reminder
    }

    func save(_ reminder: EKReminder) throws {
        try store.save(reminder, commit: true)
    }

    func remove(_ reminder: EKReminder) throws {
        try store.remove(reminder, commit: true)
    }
}
