import ArgumentParser
import EventKit

struct ListReminders: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List reminder lists, or reminders in a specific list."
    )

    @Argument(help: "Name of a reminder list. Omit to see all lists.")
    var listName: String?

    @Flag(name: .long, help: "Show all reminders across all lists.")
    var all: Bool = false

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestReminderAccess()

            if all {
                let calendars = ek.allReminderLists()
                let allReminders = try await ek.reminders(in: calendars)
                let output = enrichWithURLs(allReminders)
                print(try OutputFormatter.json(output, pretty: global.pretty))
            } else if let listName {
                let calendar = try ek.reminderList(named: listName)
                let reminders = try await ek.reminders(in: calendar)
                let output = enrichWithURLs(reminders)
                print(try OutputFormatter.json(output, pretty: global.pretty))
            } else {
                let lists = ek.allReminderLists().map { ReminderListInfo($0) }
                print(try OutputFormatter.json(lists, pretty: global.pretty))
            }
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }

    /// Batch-enriches reminders with URLs from the SQLite database.
    private func enrichWithURLs(_ reminders: [EKReminder]) -> [ReminderInfo] {

        let ids = reminders.map { $0.calendarItemIdentifier }
        let urlMap = RemindersDatabaseReader.urls(forReminderIDs: ids)
        return reminders.map { ReminderInfo($0, urlMap: urlMap) }
    }
}
