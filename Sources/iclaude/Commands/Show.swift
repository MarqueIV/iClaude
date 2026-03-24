import ArgumentParser

struct Show: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Show a single reminder by ID."
    )

    @Argument(help: "Reminder ID.")
    var id: String

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestAccess()
            let reminder = try ek.reminder(withID: id)
            print(try OutputFormatter.json(ReminderInfo(reminder), pretty: global.pretty))
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
