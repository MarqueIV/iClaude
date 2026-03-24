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
            return """
                Access to Reminders denied. The parent process may not have TCC permission. \
                To fix, run: sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" \
                "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, indirect_object_identifier, flags) \
                VALUES ('kTCCServiceReminders', '<PARENT_BUNDLE_ID>', 0, 2, 3, 1, 'UNUSED', 0);" \
                — Replace <PARENT_BUNDLE_ID> with the parent app's bundle ID \
                (e.g. com.microsoft.VSCode). Find it with: osascript -e 'id of app "<AppName>"'. \
                Or use: /grant-tcc reminders "<AppName>"
                """
        case .calendarAccessDenied:
            return """
                Access to Calendar denied. The parent process may not have TCC permission. \
                To fix, run: sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" \
                "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, indirect_object_identifier, flags) \
                VALUES ('kTCCServiceCalendar', '<PARENT_BUNDLE_ID>', 0, 2, 3, 1, 'UNUSED', 0);" \
                — Replace <PARENT_BUNDLE_ID> with the parent app's bundle ID \
                (e.g. com.microsoft.VSCode). Find it with: osascript -e 'id of app "<AppName>"'. \
                Or use: /grant-tcc calendar "<AppName>"
                """
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
