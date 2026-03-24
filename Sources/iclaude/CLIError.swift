import Foundation

enum CLIError: Error, LocalizedError {

    case accessDenied
    case listNotFound(String)
    case reminderNotFound(String, String)
    case multipleRemindersFound(String, String, Int)
    case invalidDate(String)

    var errorDescription: String? {

        switch self {
        case .accessDenied:
            return "Access to Reminders denied. Grant access in System Settings > Privacy & Security > Reminders."
        case .listNotFound(let name):
            return "List '\(name)' not found."
        case .reminderNotFound(let title, let list):
            return "Reminder '\(title)' not found in list '\(list)'."
        case .multipleRemindersFound(let title, let list, let count):
            return "Found \(count) reminders titled '\(title)' in '\(list)'. Use --list with a more specific title."
        case .invalidDate(let str):
            return "Invalid date '\(str)'. Use ISO8601 (e.g. 2024-01-15T10:00:00Z) or YYYY-MM-DD."
        }
    }
}
