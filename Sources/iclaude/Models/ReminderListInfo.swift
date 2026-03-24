import AppKit
import EventKit

struct ReminderListInfo: Codable {

    let id: String
    let name: String
    let color: String?
}

extension ReminderListInfo {

    init(_ calendar: EKCalendar) {

        id = calendar.calendarIdentifier
        name = calendar.title
        color = calendar.color.hexString
    }
}
