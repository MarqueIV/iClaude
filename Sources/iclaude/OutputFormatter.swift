import Foundation

enum OutputFormatter {

    private static let compactEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()

    private static let prettyEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    static func json<T: Encodable>(_ value: T, pretty: Bool) throws -> String {

        let data = try (pretty ? prettyEncoder : compactEncoder).encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func error(_ message: String, pretty: Bool) -> String {

        if pretty {
            return "Error: \(message)"
        }
        struct ErrorPayload: Encodable { let error: String }
        return (try? json(ErrorPayload(error: message), pretty: false))
            ?? #"{"error":"\#(message)"}"#
    }

    static func success(_ message: String? = nil, pretty: Bool) -> String {

        if pretty {
            return message.map { "Done: \($0)" } ?? "Done."
        }
        struct OkPayload: Encodable { let success: Bool; let message: String? }
        return (try? json(OkPayload(success: true, message: message), pretty: false))
            ?? #"{"success":true}"#
    }

    /// Formats any error for output. Handles disambiguation (multiple matches)
    /// by including the full match list in the JSON so the caller can retry with an ID.
    static func formatError(_ error: Error, pretty: Bool) -> String {

        if case .multipleRemindersFound(let title, let matches) = error as? CLIError {
            struct Payload: Encodable {

                let error: String
                let matches: [ReminderInfo]
            }
            let payload = Payload(
                error: "Multiple reminders match '\(title)'. Use the id from one of the matches below.",
                matches: matches
            )
            return (try? json(payload, pretty: pretty))
                ?? Self.error("Multiple reminders match '\(title)'.", pretty: pretty)
        }

        let message = (error as? CLIError)?.errorDescription ?? error.localizedDescription
        return Self.error(message, pretty: pretty)
    }
}
