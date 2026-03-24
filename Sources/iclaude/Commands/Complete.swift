import ArgumentParser

struct Complete: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Mark a reminder as complete."
    )

    @Argument(help: "Title of the reminder to complete.")
    var title: String

    @Option(name: .long, help: "Name of the reminder list.")
    var list: String

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestAccess()
            let calendar = try ek.list(named: list)
            let reminder = try await ek.reminder(titled: title, in: calendar)
            reminder.isCompleted = true
            try ek.save(reminder)
            print(OutputFormatter.success("Reminder '\(title)' marked complete.", pretty: global.pretty))
        } catch {
            print(OutputFormatter.error(error.localizedDescription, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
