import XCTest
import Foundation

// Integration tests that call the real CLI binary.
//
// IMPORTANT — permissions:
//   Run `.build/debug/iclaude reminders lists` manually once in Terminal to trigger
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

        let result = try CLI.run("reminders", "lists")

        guard result.isSuccess else {
            throw XCTSkip("iclaude returned non-zero. Is Reminders access granted? " +
                          "Run `.build/debug/iclaude reminders lists` manually first.")
        }

        guard let lists = result.jsonArray, !lists.isEmpty else {
            throw XCTSkip("No reminder lists found. Create one in Reminders.app.")
        }

        guard let name = lists.first?["name"] as? String else {
            throw XCTSkip("Could not read list name from JSON.")
        }

        testList = name
    }

    /// Helper: adds a test reminder and returns its ID.
    @discardableResult
    func addTestReminder(_ suffix: String) throws -> String {

        let title = "\(Self.prefix)\(suffix)"
        let r = try CLI.run("reminders", "add", "--new-title", title, "--list", testList)
        let obj = try XCTUnwrap(r.jsonObject)
        return try XCTUnwrap(obj["id"] as? String)
    }

    /// Helper: cleans up by ID (best-effort).
    func deleteByID(_ id: String) {
        try? CLI.run("reminders", "delete", id)
    }

    /// Helper: cleans up by title (best-effort).
    func deleteByTitle(_ title: String) {
        try? CLI.run("reminders", "delete", "--current-title", title, "--list", testList)
    }

    // MARK: - lists

    func test_lists_returnsJsonArray() throws {

        let r = try CLI.run("reminders", "lists")
        XCTAssertEqual(r.exitCode, 0)
        XCTAssertNotNil(r.jsonArray, "Expected a JSON array, got: \(r.stdout)")
    }

    func test_lists_eachEntryHasIdAndName() throws {

        let r = try CLI.run("reminders", "lists")
        let lists = try XCTUnwrap(r.jsonArray)
        for entry in lists {
            XCTAssertNotNil(entry["id"],   "Missing 'id' in: \(entry)")
            XCTAssertNotNil(entry["name"], "Missing 'name' in: \(entry)")
        }
    }

    func test_lists_prettyFlagProducesIndentedJson() throws {

        let compact = try CLI.run("reminders", "lists")
        let pretty  = try CLI.run("reminders", "lists", "--pretty")
        XCTAssertNotEqual(compact.stdout, pretty.stdout)
        XCTAssert(pretty.stdout.contains("  "), "Pretty output should be indented")
    }

    // MARK: - list (single list)

    func test_list_returnsJsonArray() throws {

        let r = try CLI.run("reminders", "list", testList)
        XCTAssertEqual(r.exitCode, 0, r.stdout)
        XCTAssertNotNil(r.jsonArray, "Expected a JSON array, got: \(r.stdout)")
    }

    func test_list_unknownList_returnsErrorJson() throws {

        let r = try CLI.run("reminders", "list", "__definitely_not_a_real_list_xyz__")
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject, "Expected JSON error object, got: \(r.stdout)")
        XCTAssertNotNil(obj["error"], "Expected 'error' key in: \(obj)")
    }

    // MARK: - add (--new-title)

    func test_add_createsReminder() throws {

        let title = "\(Self.prefix)_add"
        let id = try addTestReminder("_add")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "list", testList)
        let reminders = try XCTUnwrap(r.jsonArray)
        let match = reminders.first { ($0["id"] as? String) == id }
        let found = try XCTUnwrap(match)
        XCTAssertEqual(found["title"] as? String, title)
        XCTAssertEqual(found["isCompleted"] as? Bool, false)
    }

    func test_add_withDueDate_storesDueDate() throws {

        let title = "\(Self.prefix)_add_due"
        let r = try CLI.run("reminders", "add", "--new-title", title, "--list", testList, "--due", "2099-06-15")
        defer { deleteByTitle(title) }
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        let due = try XCTUnwrap(obj["dueDate"] as? String, "Expected dueDate in: \(obj)")
        XCTAssert(due.contains("2099"), "Due date should contain 2099, got: \(due)")
    }

    func test_add_withNotes_storesNotes() throws {

        let title = "\(Self.prefix)_add_notes"
        let r = try CLI.run("reminders", "add", "--new-title", title, "--list", testList, "--notes", "Hello from tests")
        defer { deleteByTitle(title) }
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["notes"] as? String, "Hello from tests")
    }

    func test_add_withPriority_storesPriority() throws {

        let title = "\(Self.prefix)_add_pri"
        let r = try CLI.run("reminders", "add", "--new-title", title, "--list", testList, "--priority", "1")
        defer { deleteByTitle(title) }
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["priority"] as? Int, 1)
    }

    func test_add_invalidDueDate_returnsErrorJson() throws {

        let r = try CLI.run("reminders", "add", "--new-title", "shouldfail", "--list", testList, "--due", "not-a-date")
        defer { deleteByTitle("shouldfail") }
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertNotNil(obj["error"])
    }

    // MARK: - complete (by ID and by --current-title)

    func test_complete_byID_marksReminderDone() throws {

        let id = try addTestReminder("_complete_id")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "complete", id)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["success"] as? Bool, true)
    }

    func test_complete_byTitle_marksReminderDone() throws {

        let title = "\(Self.prefix)_complete_title"
        let id = try addTestReminder("_complete_title")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "complete", "--current-title", title, "--list", testList)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["success"] as? Bool, true)
    }

    func test_complete_unknownID_returnsErrorJson() throws {

        let r = try CLI.run("reminders", "complete", "00000000-0000-0000-0000-000000000000")
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertNotNil(obj["error"])
    }

    // MARK: - edit (by ID, --new-title)

    func test_edit_byID_updatesTitle() throws {

        let original = "\(Self.prefix)_edit_orig"
        let renamed  = "\(Self.prefix)_edit_renamed"
        let id = try addTestReminder("_edit_orig")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "edit", id, "--new-title", renamed)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["title"] as? String, renamed)
    }

    func test_edit_byTitle_updatesDueDate() throws {

        let title = "\(Self.prefix)_edit_due"
        let id = try addTestReminder("_edit_due")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "edit", "--current-title", title, "--list", testList, "--due", "2099-12-31")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        let due = try XCTUnwrap(obj["dueDate"] as? String)
        XCTAssert(due.contains("2099"), "Expected 2099 in due date, got: \(due)")
    }

    func test_edit_updatesNotes() throws {

        let id = try addTestReminder("_edit_notes")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "edit", id, "--notes", "updated")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["notes"] as? String, "updated")
    }

    func test_edit_updatesPriority() throws {

        let id = try addTestReminder("_edit_pri")
        defer { deleteByID(id) }

        let r = try CLI.run("reminders", "edit", id, "--priority", "1")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["priority"] as? Int, 1)
    }

    // MARK: - delete (by ID and by --current-title)

    func test_delete_byID_removesReminder() throws {

        let id = try addTestReminder("_delete_id")

        let r = try CLI.run("reminders", "delete", id)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["success"] as? Bool, true)
    }

    func test_delete_byTitle_removesReminder() throws {

        let title = "\(Self.prefix)_delete_title"
        try addTestReminder("_delete_title")

        let r = try CLI.run("reminders", "delete", "--current-title", title, "--list", testList)
        XCTAssertEqual(r.exitCode, 0, r.stdout)
    }

    func test_delete_reminderGoneFromList() throws {

        let title = "\(Self.prefix)_delete_verify"
        let id = try addTestReminder("_delete_verify")

        try CLI.run("reminders", "delete", id)

        let r = try CLI.run("reminders", "list", testList)
        let reminders = try XCTUnwrap(r.jsonArray)
        let found = reminders.contains { ($0["title"] as? String) == title }
        XCTAssertFalse(found, "Reminder still present after deletion")
    }

    func test_delete_unknownID_returnsErrorJson() throws {

        let r = try CLI.run("reminders", "delete", "00000000-0000-0000-0000-000000000000")
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertNotNil(obj["error"])
    }

    // MARK: - missing identifier

    func test_complete_noIDNoTitle_returnsErrorJson() throws {

        let r = try CLI.run("reminders", "complete")
        XCTAssertNotEqual(r.exitCode, 0)
    }
}
