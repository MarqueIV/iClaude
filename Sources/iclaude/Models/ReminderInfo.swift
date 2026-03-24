import EventKit
import Foundation

struct ReminderInfo: Codable {

    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let priority: Int
    let notes: String?
    let url: String?
    let creationDate: Date?
    let completionDate: Date?
    let listName: String
}

extension ReminderInfo {

    init(_ reminder: EKReminder, url: String? = nil) {

        id = reminder.calendarItemIdentifier
        title = reminder.title ?? ""
        isCompleted = reminder.isCompleted
        dueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        priority = reminder.priority
        notes = reminder.notes
        self.url = url ?? RemindersDatabaseReader.url(forReminderID: reminder.calendarItemIdentifier)
        creationDate = reminder.creationDate
        completionDate = reminder.completionDate
        listName = reminder.calendar?.title ?? ""
    }

    /// Batch-enriched initializer — pass a pre-fetched URL map to avoid per-reminder DB lookups.
    init(_ reminder: EKReminder, urlMap: [String: String]) {

        id = reminder.calendarItemIdentifier
        title = reminder.title ?? ""
        isCompleted = reminder.isCompleted
        dueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        priority = reminder.priority
        notes = reminder.notes
        url = urlMap[reminder.calendarItemIdentifier]
        creationDate = reminder.creationDate
        completionDate = reminder.completionDate
        listName = reminder.calendar?.title ?? ""
    }
}
