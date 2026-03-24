import AppKit
import EventKit

struct CalendarListInfo: Codable {

    let id: String
    let name: String
    let color: String?
    let type: String
}

extension CalendarListInfo {

    init(_ calendar: EKCalendar) {

        id = calendar.calendarIdentifier
        name = calendar.title
        color = calendar.color.hexString
        type = switch calendar.type {
        case .local: "local"
        case .calDAV: "calDAV"
        case .exchange: "exchange"
        case .subscription: "subscription"
        case .birthday: "birthday"
        @unknown default: "unknown"
        }
    }
}
