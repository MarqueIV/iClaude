import ArgumentParser
import Foundation

struct Edit: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Edit an existing reminder."
    )

    @Argument(help: "Current title of the reminder to edit.")
    var currentTitle: String

    @Option(name: .long, help: "Name of the reminder list.")
    var list: String

    @Option(name: .long, help: "New title.")
    var title: String?

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
            let calendar = try ek.list(named: list)
            let reminder = try await ek.reminder(titled: currentTitle, in: calendar)

            if let title { reminder.title = title }
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
            print(OutputFormatter.error(error.localizedDescription, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
