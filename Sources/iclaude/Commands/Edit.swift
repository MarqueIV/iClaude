import ArgumentParser
import Foundation

struct Edit: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Edit an existing reminder."
    )

    @Argument(help: "Reminder ID.")
    var id: String?

    @Option(name: .customLong("current-title"), help: "Find by title instead of ID.")
    var currentTitle: String?

    @Option(name: .long, help: "List name (narrows search when using --current-title).")
    var list: String?

    @Option(name: .customLong("new-title"), help: "New title for the reminder.")
    var newTitle: String?

    @Option(name: .long, help: "New due date — ISO8601 or YYYY-MM-DD or \"YYYY-MM-DD HH:MM\".")
    var due: String?

    @Option(name: .long, help: "New notes (replaces existing notes).")
    var notes: String?

    @Option(name: .long, help: "New priority 0–9 (0=none, 1=high, 5=medium, 9=low).")
    var priority: Int?

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestAccess()
            let reminder = try await ek.resolveReminder(
                id: id, currentTitle: currentTitle, listName: list
            )

            if let newTitle { reminder.title = newTitle }
            if let notes { reminder.notes = notes }
            if let priority { reminder.priority = priority }

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
