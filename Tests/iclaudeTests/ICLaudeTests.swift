import XCTest
import Foundation

// Integration tests that call the real CLI binary.
//
// IMPORTANT — permissions:
//   Run `.build/debug/iclaude lists` manually once in Terminal to trigger
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
        let result = try CLI.run("lists")

        guard result.isSuccess else {
            throw XCTSkip("iclaude returned non-zero. Is Reminders access granted? " +
                          "Run `.build/debug/iclaude lists` manually first.")
        }

        guard let lists = result.jsonArray, !lists.isEmpty else {
            throw XCTSkip("No reminder lists found. Create one in Reminders.app.")
        }

        guard let name = lists.first?["name"] as? String else {
            throw XCTSkip("Could not read list name from JSON.")
        }

        testList = name
    }

    // MARK: - lists

    func test_lists_returnsJsonArray() throws {
        let r = try CLI.run("lists")
        XCTAssertEqual(r.exitCode, 0)
        XCTAssertNotNil(r.jsonArray, "Expected a JSON array, got: \(r.stdout)")
    }

    func test_lists_eachEntryHasIdAndName() throws {
        let r = try CLI.run("lists")
        let lists = try XCTUnwrap(r.jsonArray)
        for entry in lists {
            XCTAssertNotNil(entry["id"],   "Missing 'id' in: \(entry)")
            XCTAssertNotNil(entry["name"], "Missing 'name' in: \(entry)")
        }
    }

    func test_lists_prettyFlagProducesIndentedJson() throws {
        let compact = try CLI.run("lists")
        let pretty  = try CLI.run("lists", "--pretty")
        XCTAssertNotEqual(compact.stdout, pretty.stdout)
        XCTAssert(pretty.stdout.contains("  "), "Pretty output should be indented")
    }

    // MARK: - list (single list)

    func test_list_returnsJsonArray() throws {
        let r = try CLI.run("list", testList)
        XCTAssertEqual(r.exitCode, 0, r.stdout)
        XCTAssertNotNil(r.jsonArray, "Expected a JSON array, got: \(r.stdout)")
    }

    func test_list_unknownList_returnsErrorJson() throws {
        let r = try CLI.run("list", "__definitely_not_a_real_list_xyz__")
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject, "Expected JSON error object, got: \(r.stdout)")
        XCTAssertNotNil(obj["error"], "Expected 'error' key in: \(obj)")
    }

    // MARK: - add

    func test_add_createsReminder() throws {
        let title = "\(Self.prefix)_add"
        defer { try? CLI.run("delete", title, "--list", testList) }

        let r = try CLI.run("add", title, "--list", testList)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject, "Expected reminder JSON, got: \(r.stdout)")
        XCTAssertEqual(obj["title"] as? String, title)
        XCTAssertEqual(obj["isCompleted"] as? Bool, false)
        XCTAssertEqual(obj["listName"] as? String, testList)
    }

    func test_add_withDueDate_storesDueDate() throws {
        let title = "\(Self.prefix)_add_due"
        defer { try? CLI.run("delete", title, "--list", testList) }

        let r = try CLI.run("add", title, "--list", testList, "--due", "2099-06-15")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        let due = try XCTUnwrap(obj["dueDate"] as? String, "Expected dueDate in: \(obj)")
        XCTAssert(due.contains("2099"), "Due date should contain 2099, got: \(due)")
    }

    func test_add_withNotes_storesNotes() throws {
        let title = "\(Self.prefix)_add_notes"
        defer { try? CLI.run("delete", title, "--list", testList) }

        let r = try CLI.run("add", title, "--list", testList, "--notes", "Hello from tests")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["notes"] as? String, "Hello from tests")
    }

    func test_add_withPriority_storesPriority() throws {
        let title = "\(Self.prefix)_add_pri"
        defer { try? CLI.run("delete", title, "--list", testList) }

        let r = try CLI.run("add", title, "--list", testList, "--priority", "1")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["priority"] as? Int, 1)
    }

    func test_add_invalidDueDate_returnsErrorJson() throws {
        let r = try CLI.run("add", "shouldfail", "--list", testList, "--due", "not-a-date")
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertNotNil(obj["error"])
    }

    func test_add_appearsInList() throws {
        let title = "\(Self.prefix)_appears"
        defer { try? CLI.run("delete", title, "--list", testList) }

        try CLI.run("add", title, "--list", testList)

        let r = try CLI.run("list", testList)
        let reminders = try XCTUnwrap(r.jsonArray)
        let found = reminders.contains { ($0["title"] as? String) == title }
        XCTAssertTrue(found, "Added reminder not found in list")
    }

    // MARK: - complete

    func test_complete_marksReminderDone() throws {
        let title = "\(Self.prefix)_complete"
        defer { try? CLI.run("delete", title, "--list", testList) }

        try CLI.run("add", title, "--list", testList)

        let r = try CLI.run("complete", title, "--list", testList)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["success"] as? Bool, true)
    }

    func test_complete_reminderAppearsCompleted() throws {
        let title = "\(Self.prefix)_complete_check"
        defer { try? CLI.run("delete", title, "--list", testList) }

        try CLI.run("add", title, "--list", testList)
        try CLI.run("complete", title, "--list", testList)

        let r = try CLI.run("list", testList)
        let reminders = try XCTUnwrap(r.jsonArray)
        let match = reminders.first { ($0["title"] as? String) == title }
        let completed = try XCTUnwrap(match, "Reminder not found after completing")
        XCTAssertEqual(completed["isCompleted"] as? Bool, true)
    }

    func test_complete_unknownReminder_returnsErrorJson() throws {
        let r = try CLI.run("complete", "__nope_does_not_exist__", "--list", testList)
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertNotNil(obj["error"])
    }

    // MARK: - edit

    func test_edit_updatesTitle() throws {
        let original = "\(Self.prefix)_edit_orig"
        let renamed  = "\(Self.prefix)_edit_renamed"
        defer {
            try? CLI.run("delete", original, "--list", testList)
            try? CLI.run("delete", renamed,  "--list", testList)
        }

        try CLI.run("add", original, "--list", testList)

        let r = try CLI.run("edit", original, "--list", testList, "--title", renamed)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["title"] as? String, renamed)
    }

    func test_edit_updatesDueDate() throws {
        let title = "\(Self.prefix)_edit_due"
        defer { try? CLI.run("delete", title, "--list", testList) }

        try CLI.run("add", title, "--list", testList)

        let r = try CLI.run("edit", title, "--list", testList, "--due", "2099-12-31")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        let due = try XCTUnwrap(obj["dueDate"] as? String)
        XCTAssert(due.contains("2099"), "Expected 2099 in due date, got: \(due)")
    }

    func test_edit_updatesNotes() throws {
        let title = "\(Self.prefix)_edit_notes"
        defer { _ = try? CLI.run("delete", title, "--list", testList) }

        try CLI.run("add", title, "--list", testList, "--notes", "original")

        let r = try CLI.run("edit", title, "--list", testList, "--notes", "updated")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["notes"] as? String, "updated")
    }

    func test_edit_updatesPriority() throws {
        let title = "\(Self.prefix)_edit_pri"
        defer { _ = try? CLI.run("delete", title, "--list", testList) }

        try CLI.run("add", title, "--list", testList, "--priority", "9")

        let r = try CLI.run("edit", title, "--list", testList, "--priority", "1")
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["priority"] as? Int, 1)
    }

    // MARK: - delete

    func test_delete_removesReminder() throws {
        let title = "\(Self.prefix)_delete"

        try CLI.run("add", title, "--list", testList)

        let r = try CLI.run("delete", title, "--list", testList)
        XCTAssertEqual(r.exitCode, 0, r.stdout)

        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertEqual(obj["success"] as? Bool, true)
    }

    func test_delete_reminderGoneFromList() throws {
        let title = "\(Self.prefix)_delete_verify"

        try CLI.run("add", title, "--list", testList)
        try CLI.run("delete", title, "--list", testList)

        let r = try CLI.run("list", testList)
        let reminders = try XCTUnwrap(r.jsonArray)
        let found = reminders.contains { ($0["title"] as? String) == title }
        XCTAssertFalse(found, "Reminder still present after deletion")
    }

    func test_delete_unknownReminder_returnsErrorJson() throws {
        let r = try CLI.run("delete", "__nope_does_not_exist__", "--list", testList)
        XCTAssertNotEqual(r.exitCode, 0)
        let obj = try XCTUnwrap(r.jsonObject)
        XCTAssertNotNil(obj["error"])
    }
}
