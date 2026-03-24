import ArgumentParser

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
            try await ek.requestAccess()

            if all {
                let calendars = ek.allLists()
                let allReminders = try await ek.reminders(in: calendars)
                let output = allReminders.map { ReminderInfo($0) }
                print(try OutputFormatter.json(output, pretty: global.pretty))
            } else if let listName {
                let calendar = try ek.list(named: listName)
                let reminders = try await ek.reminders(in: calendar)
                let output = reminders.map { ReminderInfo($0) }
                print(try OutputFormatter.json(output, pretty: global.pretty))
            } else {
                let lists = ek.allLists().map { ReminderListInfo($0) }
                print(try OutputFormatter.json(lists, pretty: global.pretty))
            }
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
