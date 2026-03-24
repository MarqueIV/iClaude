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
}
