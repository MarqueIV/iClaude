import ArgumentParser
import EventKit
import Foundation

struct CalendarUpdate: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update an existing calendar event."
    )

    @Argument(help: "Event ID.")
    var id: String?

    @Option(name: .customLong("current-title"), help: "Find by title instead of ID.")
    var currentTitle: String?

    @Option(name: .long, help: "Calendar name (narrows search when using --current-title).")
    var calendar: String?

    @Option(name: .customLong("new-title"), help: "New title for the event.")
    var newTitle: String?

    @Option(name: .long, help: "New start date/time.")
    var start: String?

    @Option(name: .long, help: "New end date/time.")
    var end: String?

    @Option(name: .long, help: "New location.")
    var location: String?

    @Option(name: .long, help: "New notes (replaces existing).")
    var notes: String?

    @Flag(name: .long, help: "Apply changes to all future occurrences of a recurring event.")
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

            if let newTitle { event.title = newTitle }
            if let location { event.location = location }
            if let notes { event.notes = notes }

            if let startStr = start {
                guard let d = DateParser.parse(startStr) else { throw CLIError.invalidDate(startStr) }
                event.startDate = d
            }

            if let endStr = end {
                guard let d = DateParser.parse(endStr) else { throw CLIError.invalidDate(endStr) }
                event.endDate = d
            }

            let span: EKSpan = series ? .futureEvents : .thisEvent
            try ek.save(event, span: span)
            print(try OutputFormatter.json(EventInfo(event), pretty: global.pretty))
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
