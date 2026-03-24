import EventKit
import Foundation

struct ReminderInfo: Codable {

    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let priority: Int
    let notes: String?
    let creationDate: Date?
    let completionDate: Date?
    let listName: String
}

extension ReminderInfo {

    init(_ reminder: EKReminder) {

        id = reminder.calendarItemIdentifier
        title = reminder.title ?? ""
        isCompleted = reminder.isCompleted
        dueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        priority = reminder.priority
        notes = reminder.notes
        creationDate = reminder.creationDate
        completionDate = reminder.completionDate
        listName = reminder.calendar?.title ?? ""
    }
}
