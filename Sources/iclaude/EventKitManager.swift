import EventKit
import Foundation

final class EventKitManager {

    let store = EKEventStore()

    // MARK: - Authorization

    func requestReminderAccess() async throws {

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

    func requestCalendarAccess() async throws {

        let status = EKEventStore.authorizationStatus(for: .event)

        if status == .fullAccess { return }

        if status == .denied || status == .restricted {
            throw CLIError.calendarAccessDenied
        }

        try await store.requestFullAccessToEvents()

        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw CLIError.calendarAccessDenied
        }
    }

    // MARK: - Reminder Lists

    func allReminderLists() -> [EKCalendar] {
        store.calendars(for: .reminder)
    }

    func reminderList(named name: String) throws -> EKCalendar {

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
        try await reminders(in: [calendar])
    }

    func reminders(in calendars: [EKCalendar]) async throws -> [EKReminder] {

        try await withCheckedThrowingContinuation { continuation in
            let predicate = store.predicateForReminders(in: calendars)
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    /// Resolves a reminder by ID or by title. Returns exactly one match or throws.
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
            calendars = [try reminderList(named: listName)]
        } else {
            calendars = allReminderLists()
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

    // MARK: - Reminder mutations

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

    // MARK: - Calendars

    func allCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
    }

    func calendar(named name: String) throws -> EKCalendar {

        guard let calendar = store.calendars(for: .event)
            .first(where: { $0.title.lowercased() == name.lowercased() })
        else {
            throw CLIError.calendarNotFound(name)
        }
        return calendar
    }

    // MARK: - Event lookup

    func event(withID id: String) throws -> EKEvent {

        guard let event = store.event(withIdentifier: id) else {
            throw CLIError.eventNotFoundByID(id)
        }
        return event
    }

    func events(in calendars: [EKCalendar], from start: Date, to end: Date) -> [EKEvent] {

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate)
    }

    /// Resolves an event by ID or by title within a date range.
    func resolveEvent(
        id: String?,
        currentTitle: String?,
        calendarName: String?,
        from start: Date?,
        to end: Date?
    ) async throws -> EKEvent {

        if let id {
            return try event(withID: id)
        }

        guard let title = currentTitle else {
            throw CLIError.missingIdentifier
        }

        let calendars: [EKCalendar]
        if let calendarName {
            calendars = [try calendar(named: calendarName)]
        } else {
            calendars = allCalendars()
        }

        let searchStart = start ?? Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let searchEnd = end ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())!

        let allEvents = events(in: calendars, from: searchStart, to: searchEnd)
        let matches = allEvents.filter {
            ($0.title ?? "").lowercased() == title.lowercased()
        }

        switch matches.count {
        case 0:
            throw CLIError.eventNotFoundByTitle(title, calendarName)
        case 1:
            return matches[0]
        default:
            throw CLIError.multipleEventsFound(title, matches.map { EventInfo($0) })
        }
    }

    // MARK: - Event mutations

    func newEvent(in calendar: EKCalendar) -> EKEvent {

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        return event
    }

    func save(_ event: EKEvent, span: EKSpan = .thisEvent) throws {
        try store.save(event, span: span, commit: true)
    }

    func remove(_ event: EKEvent, span: EKSpan = .thisEvent) throws {
        try store.remove(event, span: span, commit: true)
    }
}
