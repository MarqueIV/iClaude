import ArgumentParser

struct CalendarShow: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show a single event by ID."
    )

    @Argument(help: "Event ID.")
    var id: String

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestCalendarAccess()
            let event = try ek.event(withID: id)
            print(try OutputFormatter.json(EventInfo(event), pretty: global.pretty))
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
