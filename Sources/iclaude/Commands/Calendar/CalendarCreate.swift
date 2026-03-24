import ArgumentParser
import EventKit
import Foundation

struct CalendarCreate: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new calendar event."
    )

    @Option(name: .customLong("new-title"), help: "Title of the event.")
    var newTitle: String

    @Option(name: .long, help: "Calendar name.")
    var calendar: String

    @Option(name: .long, help: "Start date/time (ISO8601, YYYY-MM-DD, or \"YYYY-MM-DD HH:MM\").")
    var start: String

    @Option(name: .long, help: "End date/time. Defaults to 1 hour after start.")
    var end: String?

    @Flag(name: .customLong("all-day"), help: "Create an all-day event.")
    var allDay: Bool = false

    @Option(name: .long, help: "Location of the event.")
    var location: String?

    @Option(name: .long, help: "Notes for the event.")
    var notes: String?

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestCalendarAccess()
            let cal = try ek.calendar(named: calendar)

            guard let startDate = DateParser.parse(start) else {
                throw CLIError.invalidDate(start)
            }

            let endDate: Date
            if let endStr = end {
                guard let d = DateParser.parse(endStr) else {
                    throw CLIError.invalidDate(endStr)
                }
                endDate = d
            } else if allDay {
                endDate = startDate
            } else {
                endDate = Foundation.Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!
            }

            let event = ek.newEvent(in: cal)
            event.title = newTitle
            event.startDate = startDate
            event.endDate = endDate
            event.isAllDay = allDay
            event.location = location
            event.notes = notes

            try ek.save(event)
            print(try OutputFormatter.json(EventInfo(event), pretty: global.pretty))
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
