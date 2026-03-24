import ArgumentParser
import Foundation

struct Create: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Create a new reminder."
    )

    @Option(name: .customLong("new-title"), help: "Title of the new reminder.")
    var newTitle: String

    @Option(name: .long, help: "Name of the reminder list.")
    var list: String

    @Option(name: .long, help: "Due date — ISO8601 or YYYY-MM-DD or \"YYYY-MM-DD HH:MM\".")
    var due: String?

    @Option(name: .long, help: "Notes to attach to the reminder.")
    var notes: String?

    @Option(name: .long, help: "Priority 0–9 (0=none, 1=high, 5=medium, 9=low).")
    var priority: Int = 0

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestAccess()
            let calendar = try ek.list(named: list)
            let reminder = ek.newReminder(in: calendar)

            reminder.title = newTitle
            reminder.notes = notes
            reminder.priority = priority

            if let dueStr = due {
                guard let date = DateParser.parse(dueStr) else {
                    throw CLIError.invalidDate(dueStr)
                }
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: date
                )
            }

            try ek.save(reminder)
            print(try OutputFormatter.json(ReminderInfo(reminder), pretty: global.pretty))
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
