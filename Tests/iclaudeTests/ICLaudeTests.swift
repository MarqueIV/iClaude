import XCTest
import Foundation

// Integration tests that call the real CLI binary.
//
// IMPORTANT — permissions:
//   Run `.build/debug/iclaude reminders list` manually once in Terminal to trigger
//   the macOS Reminders access dialog. After granting, these tests run
//   unattended. Permission persists across rebuilds (same binary path).
//
// Run with:
//   swift build && swift test
//
final class ICLaudeTests: XCTestCase {

    // Unique prefix so test reminders never collide with real data.
    static let prefix = "__iclaude_test_\(Int(Date().timeIntervalSince1970))__"

    // Populated in setUp; tests skip if no lists exist.
    var testList: String = ""

    override func setUpWithError() throws {

        let result = try CLI.run("reminders", "list")

        guard result.isSuccess else {
            throw XCTSkip("iclaude returned non-zero. Is Reminders access granted? " +
                          "Run `.build/debug/iclaude reminders list` manually first.")
        }

        guard let lists = result.jsonArray, !lists.isEmpty else {
            throw XCTSkip("No reminder lists found. Create one in Reminders.app.")
        }

        guard let name = lists.first?["name"] as? String else {
            throw XCTSkip("Could not read list name from JSON.")
        }

        testList = name
    }

    /// Helper: creates a test reminder and returns its ID.
    @discardableResult
    func createTestReminder(_ suffix: String) throws -> String {

        let title = "\(Self.prefix)\(suffix)"
        let r = try CLI.run("reminders", "create", "--new-title", title, "--list", testList)
        let obj = try XCTUnwrap(r.jsonObject)
        return try XCTUnwrap(obj["id"] as? String)
    }

    /// Helper: cleans up by ID (best-effort).
    func deleteByID(_ id: String) {
        try? CLI.run("reminders", "delete", id)
    }

    // MARK: - list (no args = lists, with name = reminders, --all = everything)

    func test_list_noArgs_returnsAllLists() throws {

        let r = try CLI.run("reminders", "list")
        XCTAssertEqual(r.exitCode, 0)
        let lists = try XCTUnwrap(r.jsonArray)
        for entry in lists {
            XCTAssertNotNil(entry["id"],   "Missing 'id' in: \(entry)")
            XCTAssertNotNil(entry["name"], "Missing 'name' in: \(entry)")
        }
    }

    func test_list_withName_returnsReminders() throws {

        let r = try CLI.run("reminders", "list", testList)
        XCTAssertEqual(r.exitCode, 0, r.stdout)
        XCTAssertNotNil(r.jsonArray, "Expected a JSON array, got: \(r.stdout)")
    }

    func test_list_all_returnsReminders() throws {

        let r = try CLI.run("reminders", "list", "--all")
        XCTAssertEqual(r.exitCode, 0, r.stdout)
        XCTAssertNotNil(r.jsonArray, "Expected a JSON array, got: \(r.stdout)")
    }

    func test_list_unknownList_returnsErrorJson() throws {

        let r = try CLI.run("reminders", "list", "__definitely_not_a_real_list_xyz__")
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject, "Expected JSON error object, got: \(r.stdout)")
        XCTAssertNotNil(obj["error"])
    }

    func test_list_prettyFlag() throws {

        let compact = try CLI.run("reminders", "list")
        let pretty  = try CLI.run("reminders", "list", "--pretty")
        XCTAssertNotEqual(compact.stdout, pretty.stdout)
        XCTAssert(pretty.stdout.contains("  "), "Pretty output should be indented")
    }

    // MARK: - show

    func test_show_byID_returnsReminder() throws {

        let id = try createTestReminder("_show")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "show", id)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["id"] as? String, id)
    }

    func test_show_unknownID_returnsError() throws {

        let r = try CLI.run("reminders", "show", "00000000-0000-0000-0000-000000000000")
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertNotNil(obj["error"])
    }

    // MARK: - create

    func test_create_returnsReminderWithID() throws {

        let title = "\(Self.prefix)_create"
        let r = try CLI.run("reminders", "create", "--new-title", title, "--list", testList)
        let obj = try XCTUnwrap(r.jsonObject)
        let id = try XCTUnwrap(obj["id"] as? String)
        defer { deleteByID(id) }

        XCTAssertEqual(r.exitCode, 0, r.stdout)
        XCTAssertEqual(obj["title"] as? String, title)
        XCTAssertEqual(obj["isCompleted"] as? Bool, false)
        XCTAssertEqual(obj["listName"] as? String, testList)
    }

    func test_create_withDueDate() throws {

        let title = "\(Self.prefix)_create_due"
        let r = try CLI.run("reminders", "create", "--new-title", title, "--list", testList, "--due", "2099-06-15")
        let obj = try XCTUnwrap(r.jsonObject)
        let id = try XCTUnwrap(obj["id"] as? String)
        defer { deleteByID(id) }

        XCTAssertEqual(r.exitCode, 0, r.stdout)
        let due = try XCTUnwrap(obj["dueDate"] as? String)
        XCTAssert(due.contains("2099"), "Due date should contain 2099, got: \(due)")
    }

    func test_create_withNotesAndPriority() throws {

        let title = "\(Self.prefix)_create_opts"
        let r = try CLI.run("reminders", "create", "--new-title", title, "--list", testList,
                            "--notes", "Hello", "--priority", "1")
        let obj = try XCTUnwrap(r.jsonObject)
        let id = try XCTUnwrap(obj["id"] as? String)
        defer { deleteByID(id) }

        XCTAssertEqual(r.exitCode, 0, r.stdout)
        XCTAssertEqual(obj["notes"] as? String, "Hello")
        XCTAssertEqual(obj["priority"] as? Int, 1)
    }

    func test_create_invalidDueDate_returnsError() throws {

        let r = try CLI.run("reminders", "create", "--new-title", "shouldfail", "--list", testList, "--due", "not-a-date")
        if r.exitCode == 0 {
            let obj = r.jsonObject
            if let id = obj?["id"] as? String { deleteByID(id) }
        }
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertNotNil(obj["error"])
    }

    // MARK: - complete (by ID and by --current-title)

    func test_complete_byID() throws {

        let id = try createTestReminder("_complete_id")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "complete", id)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["success"] as? Bool, true)
    }

    func test_complete_byTitle() throws {

        let title = "\(Self.prefix)_complete_title"
        let id = try createTestReminder("_complete_title")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "complete", "--current-title", title, "--list", testList)
        XCTAssertEqual(r.exitCode, 0, r.stdout)
    }

    func test_complete_unknownID_returnsError() throws {

        let r = try CLI.run("reminders", "complete", "00000000-0000-0000-0000-000000000000")
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertNotNil(obj["error"])
    }

    // MARK: - update (by ID, --new-title)

    func test_update_byID_changesTitle() throws {

        let renamed = "\(Self.prefix)_update_renamed"
        let id = try createTestReminder("_update_orig")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "update", id, "--new-title", renamed)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["title"] as? String, renamed)
    }

    func test_update_byTitle_changesDueDate() throws {

        let title = "\(Self.prefix)_update_due"
        let id = try createTestReminder("_update_due")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "update", "--current-title", title, "--list", testList, "--due", "2099-12-31")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        let due = try XCTUnwrap(obj["dueDate"] as? String)
        XCTAssert(due.contains("2099"))
    }

    func test_update_changesNotes() throws {

        let id = try createTestReminder("_update_notes")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "update", id, "--notes", "updated")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["notes"] as? String, "updated")
    }

    func test_update_changesPriority() throws {

        let id = try createTestReminder("_update_pri")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "update", id, "--priority", "1")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["priority"] as? Int, 1)
    }

    // MARK: - delete (by ID and by --current-title)

    func test_delete_byID() throws {

        let id = try createTestReminder("_delete_id")

        let r = try CLI.run("reminders", "delete", id)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["success"] as? Bool, true)
    }

    func test_delete_byTitle() throws {

        let title = "\(Self.prefix)_delete_title"
        try createTestReminder("_delete_title")

        let r = try CLI.run("reminders", "delete", "--current-title", title, "--list", testList)
        XCTAssertEqual(r.exitCode, 0, r.stdout)
    }

    func test_delete_verifyGone() throws {

        let title = "\(Self.prefix)_delete_verify"
        let id = try createTestReminder("_delete_verify")

        try CLI.run("reminders", "delete", id)

        let r = try CLI.run("reminders", "list", testList)
        let reminders = try XCTUnwrap(r.jsonArray)
        let found = reminders.contains { ($0["title"] as? String) == title }
        XCTAssertFalse(found, "Reminder still present after deletion")
    }

    func test_delete_unknownID_returnsError() throws {

        let r = try CLI.run("reminders", "delete", "00000000-0000-0000-0000-000000000000")
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertNotNil(obj["error"])
    }

    // MARK: - missing identifier

    func test_complete_noIDNoTitle_returnsError() throws {

        let r = try CLI.run("reminders", "complete")
        XCTAssertNotEqual(r.exitCode, 0)
    }
}
