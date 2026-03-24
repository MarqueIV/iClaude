import Foundation

enum CLIError: Error, LocalizedError {

    // General
    case accessDenied
    case calendarAccessDenied
    case invalidDate(String)
    case missingIdentifier

    // Reminders
    case listNotFound(String)
    case reminderNotFoundByID(String)
    case reminderNotFoundByTitle(String, String?)
    case multipleRemindersFound(String, [ReminderInfo])

    // Calendar
    case calendarNotFound(String)
    case eventNotFoundByID(String)
    case eventNotFoundByTitle(String, String?)
    case multipleEventsFound(String, [EventInfo])

    var errorDescription: String? {

        switch self {
        case .accessDenied:
            return "Access to Reminders denied. Grant access in System Settings > Privacy & Security > Reminders."
        case .calendarAccessDenied:
            return "Access to Calendar denied. Grant access in System Settings > Privacy & Security > Calendars."
        case .invalidDate(let str):
            return "Invalid date '\(str)'. Use ISO8601 (e.g. 2024-01-15T10:00:00Z), YYYY-MM-DD, or \"YYYY-MM-DD HH:MM\"."
        case .missingIdentifier:
            return "Provide either an <id> argument or --current-title."
        case .listNotFound(let name):
            return "Reminder list '\(name)' not found."
        case .reminderNotFoundByID(let id):
            return "No reminder found with ID '\(id)'."
        case .reminderNotFoundByTitle(let title, let list):
            if let list {
                return "Reminder '\(title)' not found in list '\(list)'."
            }
            return "Reminder '\(title)' not found."
        case .multipleRemindersFound(let title, _):
            return "Multiple reminders match '\(title)'. Use the id from one of the matches below."
        case .calendarNotFound(let name):
            return "Calendar '\(name)' not found."
        case .eventNotFoundByID(let id):
            return "No event found with ID '\(id)'."
        case .eventNotFoundByTitle(let title, let cal):
            if let cal {
                return "Event '\(title)' not found in calendar '\(cal)'."
            }
            return "Event '\(title)' not found."
        case .multipleEventsFound(let title, _):
            return "Multiple events match '\(title)'. Use the id from one of the matches below."
        }
    }
}
