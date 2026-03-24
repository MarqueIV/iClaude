import EventKit
import Foundation

struct EventInfo: Codable {

    let id: String
    let title: String
    let startDate: Date?
    let endDate: Date?
    let isAllDay: Bool
    let isRecurring: Bool
    let recurrenceOriginalStartDate: Date?
    let location: String?
    let notes: String?
    let calendarName: String
    let availability: String
}

extension EventInfo {

    init(_ event: EKEvent) {

        id = event.eventIdentifier
        title = event.title ?? ""
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        isRecurring = event.hasRecurrenceRules
        recurrenceOriginalStartDate = event.hasRecurrenceRules ? event.occurrenceDate : nil
        location = event.location
        notes = event.notes
        calendarName = event.calendar?.title ?? ""
        availability = switch event.availability {
        case .busy: "busy"
        case .free: "free"
        case .tentative: "tentative"
        case .unavailable: "unavailable"
        case .notSupported: "notSupported"
        @unknown default: "unknown"
        }
    }
}
