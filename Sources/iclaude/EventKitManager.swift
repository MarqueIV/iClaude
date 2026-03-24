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

    // MARK: - Lists

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

    // MARK: - Reminder lookup

    func reminder(withID id: String) throws -> EKReminder {

        guard let item = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw CLIError.reminderNotFoundByID(id)
        }
        return item
    }

    func reminders(in calendar: EKCalendar) async throws -> [EKReminder] {

        try await withCheckedThrowingContinuation { continuation in
            let predicate = store.predicateForReminders(in: [calendar])
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    /// Resolves a reminder by ID or by title. Returns exactly one match or throws.
    /// When multiple reminders match a title, throws `.multipleRemindersFound`
    /// with all matches so the caller can present them for disambiguation.
    func resolveReminder(
        id: String?,
        currentTitle: String?,
        listName: String?
    ) async throws -> EKReminder {

        if let id {
            return try reminder(withID: id)
        }

        guard let title = currentTitle else {
            throw CLIError.missingIdentifier
        }

        let calendars: [EKCalendar]
        if let listName {
            calendars = [try list(named: listName)]
        } else {
            calendars = allLists()
        }

        let allReminders: [EKReminder] = try await withCheckedThrowingContinuation { continuation in
            let predicate = store.predicateForReminders(in: calendars)
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        let matches = allReminders.filter {
            ($0.title ?? "").lowercased() == title.lowercased()
        }

        switch matches.count {
        case 0:
            throw CLIError.reminderNotFoundByTitle(title, listName)
        case 1:
            return matches[0]
        default:
            throw CLIError.multipleRemindersFound(title, matches.map { ReminderInfo($0) })
        }
    }

    // MARK: - Mutations

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
