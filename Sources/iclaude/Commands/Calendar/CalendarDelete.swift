import ArgumentParser
import Foundation

struct CalendarDelete: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a calendar event."
    )

    @Argument(help: "Event ID.")
    var id: String?

    @Option(name: .customLong("current-title"), help: "Find by title instead of ID.")
    var currentTitle: String?

    @Option(name: .long, help: "Calendar name (narrows search when using --current-title).")
    var calendar: String?

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestCalendarAccess()
            let event = try await ek.resolveEvent(
                id: id, currentTitle: currentTitle, calendarName: calendar,
                from: nil, to: nil
            )
            let title = event.title ?? ""
            try ek.remove(event)
            print(OutputFormatter.success(
                "Event '\(title)' deleted.",
                pretty: global.pretty
            ))
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
