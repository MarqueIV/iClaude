import Darwin
import Foundation
import SQLite3

/// Automatically grants TCC permissions to parent processes.
///
/// When iclaude runs as a child of an app that can't trigger its own TCC dialog
/// (e.g. VS Code, Electron apps, Node), this detects parent processes and
/// inserts TCC grants directly into the user-level TCC database.
///
/// Grants both the nearest .app bundle (by bundle ID) AND any intermediate
/// non-app processes (by absolute path, e.g. /path/to/node) since macOS may
/// attribute TCC checks to either depending on the context.
///
/// This is equivalent to the user clicking "Allow" in a system dialog — the
/// user-level TCC database stores the user's own consent decisions and is
/// writable by the user. The system-level database (protected by SIP) is not touched.
enum TCCAutoGrant {

    /// Ensures parent processes have the given TCC permission.
    /// Grants both the app bundle (by ID) and intermediate processes (by path).
    /// Fails silently if anything goes wrong.
    static func ensureAccess(for service: String) {

        let parents = findParentProcesses()

        for parent in parents {
            switch parent {
            case .bundleID(let id):
                if !hasGrant(service: service, client: id, clientType: 0) {
                    insertGrant(service: service, client: id, clientType: 0)
                }
            case .path(let path):
                if !hasGrant(service: service, client: path, clientType: 1) {
                    insertGrant(service: service, client: path, clientType: 1)
                }
            }
        }
    }

    // MARK: - Types

    private enum ParentIdentifier {

        case bundleID(String)
        case path(String)
    }

    // MARK: - Private

    private static let tccDBPath: String = {
        NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"
    }()

    private static func hasGrant(service: String, client: String, clientType: Int32) -> Bool {

        var db: OpaquePointer?
        guard sqlite3_open_v2(tccDBPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return false }
        defer { sqlite3_close(db) }

        let sql = "SELECT auth_value FROM access WHERE service=?1 AND client=?2 AND client_type=?3;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (service as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (client as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 3, clientType)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int(stmt, 0) == 2
        }
        return false
    }

    private static func insertGrant(service: String, client: String, clientType: Int32) {

        var db: OpaquePointer?
        guard sqlite3_open_v2(tccDBPath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        let sql = """
            INSERT OR REPLACE INTO access \
            (service, client, client_type, auth_value, auth_reason, auth_version, indirect_object_identifier, flags) \
            VALUES (?1, ?2, ?3, 2, 3, 1, 'UNUSED', 0);
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (service as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (client as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 3, clientType)

        if sqlite3_step(stmt) == SQLITE_DONE {
            fputs("iclaude: auto-granted \(service) to \(client)\n", stderr)
        }
    }

    /// Walks up the process tree collecting parent identifiers.
    /// Returns .bundleID for .app bundles, .path for non-app executables (e.g. node).
    /// Skips shells (zsh, bash, sh) and the iclaude binary itself.
    private static func findParentProcesses() -> [ParentIdentifier] {

        let skipNames: Set<String> = ["zsh", "bash", "sh", "fish", "iclaude"]
        var results: [ParentIdentifier] = []
        var pid = getppid()

        while pid > 1 {
            var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
            guard pathLen > 0 else { break }
            let path = String(cString: pathBuffer)
            let name = (path as NSString).lastPathComponent

            if !skipNames.contains(name) {
                // Check if it's inside a .app bundle
                if let range = path.range(of: ".app/") ?? path.range(of: ".app") {
                    let appPath = String(path[path.startIndex...range.lowerBound]) + "app"
                    let plistPath = appPath + "/Contents/Info.plist"
                    if let plist = NSDictionary(contentsOfFile: plistPath),
                       let bundleID = plist["CFBundleIdentifier"] as? String {

                        results.append(.bundleID(bundleID))
                    }
                } else {
                    // Non-app executable (e.g. node, python) — grant by path
                    results.append(.path(path))
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

        return results
    }
}
