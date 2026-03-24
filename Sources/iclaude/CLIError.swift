import Foundation

enum CLIError: Error, LocalizedError {

    case accessDenied
    case listNotFound(String)
    case reminderNotFoundByID(String)
    case reminderNotFoundByTitle(String, String?)
    case multipleRemindersFound(String, [ReminderInfo])
    case invalidDate(String)
    case missingIdentifier

    var errorDescription: String? {

        switch self {
        case .accessDenied:
            return "Access to Reminders denied. Grant access in System Settings > Privacy & Security > Reminders."
        case .listNotFound(let name):
            return "List '\(name)' not found."
        case .reminderNotFoundByID(let id):
            return "No reminder found with ID '\(id)'."
        case .reminderNotFoundByTitle(let title, let list):
            if let list {
                return "Reminder '\(title)' not found in list '\(list)'."
            }
            return "Reminder '\(title)' not found."
        case .multipleRemindersFound(let title, _):
            return "Multiple reminders match '\(title)'. Use the id from one of the matches below."
        case .invalidDate(let str):
            return "Invalid date '\(str)'. Use ISO8601 (e.g. 2024-01-15T10:00:00Z) or YYYY-MM-DD."
        case .missingIdentifier:
            return "Provide either an <id> argument or --current-title."
        }
    }
}
