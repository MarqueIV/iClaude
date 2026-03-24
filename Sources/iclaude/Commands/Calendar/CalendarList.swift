import ArgumentParser
import EventKit
import Foundation

struct CalendarList: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List calendars, or events in a specific calendar."
    )

    @Argument(help: "Calendar name. Omit to see all calendars.")
    var calendarName: String?

    @Flag(name: .long, help: "Show events across all calendars.")
    var all: Bool = false

    @Flag(name: .long, help: "Show today's events.")
    var today: Bool = false

    @Flag(name: .long, help: "Show this week's events (next 7 days).")
    var week: Bool = false

    @Option(name: .long, help: "Start date for event range (ISO8601 or YYYY-MM-DD).")
    var from: String?

    @Option(name: .long, help: "End date for event range (ISO8601 or YYYY-MM-DD).")
    var to: String?

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestCalendarAccess()

            let wantsEvents = all || today || week || calendarName != nil || from != nil || to != nil

            if !wantsEvents {
                let calendars = ek.allCalendars().map { CalendarListInfo($0) }
                print(try OutputFormatter.json(calendars, pretty: global.pretty))
                return
            }

            let (start, end) = try resolveRange()

            let calendars: [EKCalendar]
            if let calendarName {
                calendars = [try ek.calendar(named: calendarName)]
            } else {
                calendars = ek.allCalendars()
            }

            let events = ek.events(in: calendars, from: start, to: end)
                .map { EventInfo($0) }
            print(try OutputFormatter.json(events, pretty: global.pretty))
        } catch {
            print(OutputFormatter.formatError(error, pretty: global.pretty))
            throw ExitCode.failure
        }
    }

    private func resolveRange() throws -> (Date, Date) {

        if today {
            let start = Foundation.Calendar.current.startOfDay(for: Date())
            let end = Foundation.Calendar.current.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        }

        if week {
            let start = Foundation.Calendar.current.startOfDay(for: Date())
            let end = Foundation.Calendar.current.date(byAdding: .day, value: 7, to: start)!
            return (start, end)
        }

        let start: Date
        let end: Date

        if let fromStr = from {
            guard let d = DateParser.parse(fromStr) else { throw CLIError.invalidDate(fromStr) }
            start = d
        } else {
            start = Foundation.Calendar.current.startOfDay(for: Date())
        }

        if let toStr = to {
            guard let d = DateParser.parse(toStr) else { throw CLIError.invalidDate(toStr) }
            end = d
        } else {
            end = Foundation.Calendar.current.date(byAdding: .day, value: 7, to: start)!
        }

        return (start, end)
    }
}
