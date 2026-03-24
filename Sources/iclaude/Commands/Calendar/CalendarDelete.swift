import ArgumentParser
import EventKit
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

    @Flag(name: .long, help: "Delete all future occurrences of a recurring event.")
    var series: Bool = false

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
            let span: EKSpan = series ? .futureEvents : .thisEvent
            try ek.remove(event, span: span)
            let msg = series
                ? "Event '\(title)' and all future occurrences deleted."
                : "Event '\(title)' deleted."
            print(OutputFormatter.success(msg, pretty: global.pretty))
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
