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
    let altURL: String?
    let altURLNote: String?
    let warning: String?
    let creationDate: Date?
    let completionDate: Date?
    let listName: String
}

extension ReminderInfo {

    init(_ reminder: EKReminder, dbURL: String? = nil) {

        let eventKitURL = reminder.url?.absoluteString
        let richLink = dbURL ?? RemindersDatabaseReader.url(forReminderID: reminder.calendarItemIdentifier)

        id = reminder.calendarItemIdentifier
        title = reminder.title ?? ""
        isCompleted = reminder.isCompleted
        dueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        priority = reminder.priority
        notes = reminder.notes
        creationDate = reminder.creationDate
        completionDate = reminder.completionDate
        listName = reminder.calendar?.title ?? ""

        (url, altURL, altURLNote) = Self.resolveURLs(eventKit: eventKitURL, richLink: richLink)
        warning = Self.fdaWarning
    }

    /// Batch-enriched initializer — pass a pre-fetched URL map to avoid per-reminder DB lookups.
    init(_ reminder: EKReminder, urlMap: [String: String]) {

        let eventKitURL = reminder.url?.absoluteString
        let richLink = urlMap[reminder.calendarItemIdentifier]

        id = reminder.calendarItemIdentifier
        title = reminder.title ?? ""
        isCompleted = reminder.isCompleted
        dueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        priority = reminder.priority
        notes = reminder.notes
        creationDate = reminder.creationDate
        completionDate = reminder.completionDate
        listName = reminder.calendar?.title ?? ""

        (url, altURL, altURLNote) = Self.resolveURLs(eventKit: eventKitURL, richLink: richLink)
        warning = Self.fdaWarning
    }

    /// Resolves the URL fields based on what's available.
    /// - Both nil → all nil
    /// - Only one set → goes in `url`, no alt
    /// - Both set, matching → goes in `url`, no alt
    /// - Both set, different → rich link in `url` (matches what user sees),
    ///   EventKit property in `altURL` (hidden from UI, only visible via API)
    private static let fdaWarning: String? = {
        if !RemindersDatabaseReader.isDatabaseAccessible {
            return "Reminder URLs from share sheet are not visible — Full Disk Access not granted. " +
                "Ask the user to grant FDA in System Settings > Privacy & Security > Full Disk Access " +
                "for the parent app (e.g. Visual Studio Code, iTerm, Node)."
        }
        return nil
    }()

    private static func resolveURLs(
        eventKit: String?,
        richLink: String?
    ) -> (url: String?, altURL: String?, altURLNote: String?) {

        switch (eventKit, richLink) {
        case (nil, nil):
            return (nil, nil, nil)
        case (let ek?, nil):
            return (ek, nil, nil)
        case (nil, let rl?):
            return (rl, nil, nil)
        case (let ek?, let rl?) where ek == rl:
            return (ek, nil, nil)
        case (let ek?, let rl?):
            return (
                rl,
                ek,
                "EventKit URL property (writable via API, hidden from Reminders UI) differs from the rich link URL shown in the app"
            )
        }
    }
}
