import ArgumentParser

struct ListReminders: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List reminders in a specific list."
    )

    @Argument(help: "Name of the reminder list.")
    var listName: String

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestAccess()
            let calendar = try ek.list(named: listName)
            let reminders = try await ek.reminders(in: calendar)
            let output = reminders.map { ReminderInfo($0) }
            print(try OutputFormatter.json(output, pretty: global.pretty))
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
