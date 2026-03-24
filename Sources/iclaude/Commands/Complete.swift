import ArgumentParser

struct Complete: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Mark a reminder as complete."
    )

    @Argument(help: "Reminder ID.")
    var id: String?

    @Option(name: .customLong("current-title"), help: "Find by title instead of ID.")
    var currentTitle: String?

    @Option(name: .long, help: "List name (narrows search when using --current-title).")
    var list: String?

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestReminderAccess()
            let reminder = try await ek.resolveReminder(
                id: id, currentTitle: currentTitle, listName: list
            )
            reminder.isCompleted = true
            try ek.save(reminder)
            print(OutputFormatter.success(
                "Reminder '\(reminder.title ?? "")' marked complete.",
                pretty: global.pretty
            ))
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
