import Darwin
import Foundation
import SQLite3

/// Automatically grants TCC permissions to the parent application.
///
/// When iclaude runs as a child of an app that can't trigger its own TCC dialog
/// (e.g. VS Code, Electron apps), this detects the parent app's bundle ID and
/// inserts the TCC grant directly into the user-level TCC database.
///
/// This is equivalent to the user clicking "Allow" in a system dialog — the
/// user-level TCC database stores the user's own consent decisions and is
/// writable by the user. The system-level database (protected by SIP) is not touched.
enum TCCAutoGrant {

    /// Ensures the responsible parent app has the given TCC permission.
    /// Fails silently if anything goes wrong (can't find parent, DB not writable, etc.).
    static func ensureAccess(for service: String) {

        guard let bundleID = findResponsibleAppBundleID() else { return }
        guard !hasGrant(service: service, client: bundleID) else { return }
        insertGrant(service: service, client: bundleID)
    }

    // MARK: - Private

    private static let tccDBPath: String = {
        NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"
    }()

    private static func hasGrant(service: String, client: String) -> Bool {

        var db: OpaquePointer?
        guard sqlite3_open_v2(tccDBPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return false }
        defer { sqlite3_close(db) }

        let sql = "SELECT auth_value FROM access WHERE service=?1 AND client=?2;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (service as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (client as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int(stmt, 0) == 2
        }
        return false
    }

    private static func insertGrant(service: String, client: String) {

        var db: OpaquePointer?
        guard sqlite3_open_v2(tccDBPath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        let sql = """
            INSERT OR REPLACE INTO access \
            (service, client, client_type, auth_value, auth_reason, auth_version, indirect_object_identifier, flags) \
            VALUES (?1, ?2, 0, 2, 3, 1, 'UNUSED', 0);
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (service as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (client as NSString).utf8String, -1, nil)

        if sqlite3_step(stmt) == SQLITE_DONE {
            fputs("iclaude: auto-granted \(service) access to \(client)\n", stderr)
        }
    }

    /// Walks up the process tree to find the nearest .app bundle and returns its bundle ID.
    private static func findResponsibleAppBundleID() -> String? {

        var pid = getppid()

        while pid > 1 {
            var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
            guard pathLen > 0 else { break }
            let path = String(cString: pathBuffer)

            // Look for a .app bundle in the path
            if let range = path.range(of: ".app/") ?? path.range(of: ".app") {
                let appPath = String(path[path.startIndex...range.lowerBound]) + "app"
                let plistPath = appPath + "/Contents/Info.plist"
                if let plist = NSDictionary(contentsOfFile: plistPath),
                   let bundleID = plist["CFBundleIdentifier"] as? String {

                    return bundleID
                }
            }

            // Move to parent process
            var info = kinfo_proc()
            var size = MemoryLayout<kinfo_proc>.size
            var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
            guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { break }
            let parentPid = info.kp_eproc.e_ppid
            if parentPid == pid { break }
            pid = parentPid
        }

        return nil
    }
}
