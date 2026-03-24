import Foundation
import SQLite3

/// Reads URL/link data directly from the Reminders SQLite database.
/// This is a workaround for EventKit not exposing the URL field that
/// the Reminders app displays (rich links stored as entity type 26).
final class RemindersDatabaseReader {

    private static let storesPath = NSHomeDirectory()
        + "/Library/Group Containers/group.com.apple.reminders/Container_v1/Stores"

    /// Whether the Reminders database is accessible (requires Full Disk Access).
    static var isDatabaseAccessible: Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: storesPath)) != nil
    }

    /// Returns all database file paths in the Reminders container.
    private static func databasePaths() -> [String] {

        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: storesPath) else {
            return []
        }
        return contents
            .filter { $0.hasPrefix("Data-") && $0.hasSuffix(".sqlite") }
            .map { "\(storesPath)/\($0)" }
    }

    /// Looks up the URL for a reminder by its EventKit calendarItemIdentifier.
    /// Searches all database files (multiple accounts).
    static func url(forReminderID identifier: String) -> String? {

        for dbPath in databasePaths() {
            if let url = queryURL(dbPath: dbPath, identifier: identifier) {
                return url
            }
        }
        return nil
    }

    /// Batch lookup: returns a dictionary of [calendarItemIdentifier: URL]
    /// for all reminders that have URLs, scoped to the given identifiers.
    static func urls(forReminderIDs identifiers: [String]) -> [String: String] {

        var result: [String: String] = [:]
        let idSet = Set(identifiers)

        for dbPath in databasePaths() {
            let batch = queryAllURLs(dbPath: dbPath)
            for (id, url) in batch where idSet.contains(id) {
                result[id] = url
            }
        }
        return result
    }

    /// Batch lookup: returns ALL reminder URLs across all databases.
    static func allURLs() -> [String: String] {

        var result: [String: String] = [:]
        for dbPath in databasePaths() {
            let batch = queryAllURLs(dbPath: dbPath)
            result.merge(batch) { _, new in new }
        }
        return result
    }

    // MARK: - Private

    private static func queryURL(dbPath: String, identifier: String) -> String? {

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = """
            SELECT o.ZURL
            FROM ZREMCDOBJECT o
            JOIN ZREMCDREMINDER r ON o.ZREMINDER2 = r.Z_PK
            WHERE r.ZDACALENDARITEMUNIQUEIDENTIFIER = ?
              AND o.Z_ENT = 26
            LIMIT 1
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, identifier, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        guard let cString = sqlite3_column_text(stmt, 0) else {
            return nil
        }
        return String(cString: cString)
    }

    private static func queryAllURLs(dbPath: String) -> [String: String] {

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return [:]
        }
        defer { sqlite3_close(db) }

        let sql = """
            SELECT r.ZDACALENDARITEMUNIQUEIDENTIFIER, o.ZURL
            FROM ZREMCDOBJECT o
            JOIN ZREMCDREMINDER r ON o.ZREMINDER2 = r.Z_PK
            WHERE o.Z_ENT = 26
              AND o.ZURL IS NOT NULL
              AND r.ZDACALENDARITEMUNIQUEIDENTIFIER IS NOT NULL
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return [:]
        }
        defer { sqlite3_finalize(stmt) }

        var result: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idPtr = sqlite3_column_text(stmt, 0),
                  let urlPtr = sqlite3_column_text(stmt, 1)
            else { continue }
            result[String(cString: idPtr)] = String(cString: urlPtr)
        }
        return result
    }
}
