# iClaude

A Swift command-line tool for managing Apple Reminders and Calendar from the terminal. Built on Apple's native EventKit framework -- no AppleScript, no osascript, no JXA. Designed to be called by AI agents (Claude Code, LLM tool-use pipelines, etc.) but works just as well from a shell script or cron job.

Output is machine-readable JSON by default. Every response is structured, predictable, and parseable. Errors include actionable fix instructions, not just descriptions.

## Installation

Requires macOS 14 (Sonoma) or later and Swift 5.9+.

```bash
git clone https://github.com/MarqueIV/iClaude.git
cd iClaude
swift build -c release
cp .build/release/iclaude /usr/local/bin/
```

### Running with selfauth

When called from inside apps like VS Code, Electron-based editors, or Claude Desktop, macOS may silently deny access to Reminders and Calendar because it attributes the privacy request to the parent process rather than to `iclaude` itself.

[**selfauth**](https://github.com/MarqueIV/selfauth) is a companion utility that solves this by disclaiming the parent process's TCC identity. It is transparent -- stdin/stdout/stderr and exit codes pass through unchanged:

```bash
selfauth iclaude reminders list
selfauth iclaude calendar list --today
```

`selfauth` is recommended as a fallback for environments where `iclaude`'s built-in TCC auto-grant (described below) cannot work.

---

## Reminders

Full CRUD access to Apple Reminders via EventKit.

### List all reminder lists

```bash
iclaude reminders list
```

```json
[
  {"id": "3E7C1731-...", "name": "Reminders", "color": "#5856D6"},
  {"id": "A1B2C3D4-...", "name": "Shopping", "color": "#34C759"}
]
```

### List reminders in a specific list

```bash
iclaude reminders list "Shopping"
```

### List all reminders across all lists

```bash
iclaude reminders list --all
```

### Show a single reminder

```bash
iclaude reminders show <id>
```

### Create a reminder

```bash
iclaude reminders create \
  --new-title "Buy milk" \
  --list "Shopping" \
  --due "2025-01-15 09:00" \
  --notes "Whole milk, not skim" \
  --priority 5
```

Priority values: `0` = none, `1` = high, `5` = medium, `9` = low.

### Update a reminder

```bash
# By ID (preferred)
iclaude reminders update <id> --new-title "Buy oat milk" --priority 1

# By title (with optional --list to narrow the search)
iclaude reminders update --current-title "Buy milk" --list "Shopping" --new-title "Buy oat milk"
```

### Complete a reminder

```bash
iclaude reminders complete <id>
iclaude reminders complete --current-title "Buy milk"
```

### Delete a reminder

```bash
iclaude reminders delete <id>
iclaude reminders delete --current-title "Buy milk" --list "Shopping"
```

---

## Calendar

Full CRUD access to Apple Calendar events via EventKit.

### List all calendars

```bash
iclaude calendar list
```

```json
[
  {"id": "ABC123-...", "name": "Work", "color": "#FF3B30", "type": "calDAV"},
  {"id": "DEF456-...", "name": "Personal", "color": "#007AFF", "type": "calDAV"},
  {"id": "GHI789-...", "name": "Birthdays", "color": "#5856D6", "type": "birthday"}
]
```

### List events

```bash
iclaude calendar list "Work"                              # next 7 days (default)
iclaude calendar list --today                             # today only
iclaude calendar list --week                              # next 7 days
iclaude calendar list --all                               # all calendars, next 7 days
iclaude calendar list --from 2025-01-01 --to 2025-06-30  # custom date range
```

### Show a single event

```bash
iclaude calendar show <id>
```

### Create an event

```bash
iclaude calendar create \
  --new-title "Team standup" \
  --calendar "Work" \
  --start "2025-01-15 09:00" \
  --end "2025-01-15 09:30" \
  --location "Conference Room B" \
  --notes "Weekly sync"

# All-day event (end defaults to same day)
iclaude calendar create \
  --new-title "Company holiday" \
  --calendar "Work" \
  --start 2025-12-25 \
  --all-day
```

If `--end` is omitted and `--all-day` is not set, the event defaults to 1 hour.

### Update an event

```bash
iclaude calendar update <id> --new-title "Renamed meeting" --start "2025-01-15 10:00"

# By title
iclaude calendar update --current-title "Team standup" --calendar "Work" --location "Room A"

# Update all future occurrences of a recurring event
iclaude calendar update <id> --series --location "New room"
```

### Delete an event

```bash
iclaude calendar delete <id>

# Delete an entire recurring series
iclaude calendar delete <id> --series
```

---

## Output Format

All output is JSON by default. Add `--pretty` to any command for human-readable formatting.

```bash
iclaude reminders list                # compact JSON (for machines / AI agents)
iclaude reminders list --pretty       # pretty-printed JSON (for humans)
```

### Success (read operations)

Returns the requested data as a JSON object or array:

```json
{
  "id": "ABC123-...",
  "title": "Buy milk",
  "isCompleted": false,
  "dueDate": "2025-01-15T09:00:00Z",
  "priority": 5,
  "notes": "Whole milk, not skim",
  "url": "https://example.com/shopping",
  "altURL": null,
  "altURLNote": null,
  "warning": null,
  "creationDate": "2025-01-10T12:00:00Z",
  "completionDate": null,
  "listName": "Shopping"
}
```

### Success (write operations)

Create and update return the full object. Complete and delete return:

```json
{"success": true, "message": "Reminder 'Buy milk' marked complete."}
```

### Errors

```json
{"error": "Reminder list 'Groceries' not found."}
```

Error messages are designed to be actionable. TCC permission errors include the exact `sqlite3` command to run as a fix.

### Disambiguation

When `--current-title` matches multiple items, the response includes all matches so the caller can retry with a specific ID:

```json
{
  "error": "Multiple reminders match 'Buy milk'. Use the id from one of the matches below.",
  "matches": [
    {"id": "3E7C...", "title": "Buy milk", "listName": "Shopping"},
    {"id": "7F2A...", "title": "Buy milk", "listName": "Groceries"}
  ]
}
```

### Special Response Fields

Always check for these fields when parsing responses:

| Field | Meaning |
|---|---|
| `error` | Operation failed. Message includes fix instructions. |
| `warning` | Operation succeeded but degraded (e.g., Full Disk Access not granted). |
| `altURL` | A hidden EventKit URL that conflicts with the visible rich-link URL. |
| `altURLNote` | Explanation of why `url` and `altURL` differ. |

---

## ID-first API Design

All mutating commands (update, complete, delete) accept an item ID as the primary argument. This is the preferred approach because IDs are unambiguous.

For convenience, `--current-title` is accepted as an alternative. If the title matches exactly one item, it works. If it matches multiple, the command returns all matches with their IDs so the caller can retry with the correct one.

Use `--list` (reminders) or `--calendar` (events) alongside `--current-title` to narrow the search scope.

---

## Date Formats

All date flags accept these formats:

| Format | Example |
|---|---|
| ISO 8601 | `2025-01-15T10:00:00Z` |
| ISO 8601 with fractional seconds | `2025-01-15T10:00:00.000Z` |
| Date only | `2025-01-15` |
| Date and time | `2025-01-15 10:00` |

---

## How It Works

### Architecture

iClaude is a single-binary CLI built with [Swift Argument Parser](https://github.com/apple/swift-argument-parser). It has two top-level subcommand groups (`reminders` and `calendar`), each with their own CRUD subcommands.

All data access goes through `EventKitManager`, a thin wrapper around Apple's `EKEventStore`. The manager handles authorization, item resolution (by ID or by title with disambiguation), and date-range chunking.

The output layer (`OutputFormatter`) encodes everything as JSON using `Codable` model structs (`ReminderInfo`, `EventInfo`, `ReminderListInfo`, `CalendarListInfo`). Dates are ISO 8601. Calendar and list colors are included as hex strings (e.g., `#FF5733`).

```
iclaude
  reminders
    list / show / create / update / complete / delete
  calendar
    list / show / create / update / delete
```

### TCC Auto-Grant

macOS uses Transparency, Consent, and Control (TCC) to gate access to Reminders and Calendar. Normally, the first time an app accesses this data, macOS shows a permission dialog. But when `iclaude` runs as a child of an Electron app (VS Code, Cursor, Claude Desktop) or a bare process like `node`, macOS attributes the permission check to the parent -- and these apps often cannot trigger the consent dialog.

iClaude solves this automatically. On every launch, before requesting EventKit access, it:

1. **Walks the process tree** using `getppid()` and `sysctl`, collecting parent process identifiers
2. **Skips shells** (`zsh`, `bash`, `sh`, `fish`) and its own binary
3. **Detects `.app` bundles** by finding `.app/` in a parent's executable path, then reads the bundle's `Info.plist` to extract the bundle ID (e.g., `com.microsoft.VSCode`)
4. **Detects non-app processes** (like `/usr/local/bin/node`) and records them by absolute path
5. **Checks the user-level TCC database** (`~/Library/Application Support/com.apple.TCC/TCC.db`) for existing grants
6. **Inserts missing grants** via direct SQLite writes -- equivalent to the user clicking "Allow" in a system dialog

This only modifies the **user-level** TCC database, which stores the user's own consent decisions and is writable without elevated privileges. The system-level database (protected by SIP) is never touched.

If auto-grant fails or the TCC schema changes, error messages include the exact `sqlite3` command to run manually:

```
sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" \
  "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, indirect_object_identifier, flags) \
  VALUES ('kTCCServiceReminders', 'com.microsoft.VSCode', 0, 2, 3, 1, 'UNUSED', 0);"
```

### Reminder URL Hack

Apple's Reminders app displays URLs for reminders -- both manually entered URLs and rich links from the iOS/macOS share sheet. However, EventKit's `EKReminder` API does not expose these URLs. The `.url` property on `EKReminder` is a separate, API-only field that the Reminders app ignores entirely.

iClaude works around this by reading the Reminders SQLite database directly:

```
~/Library/Group Containers/group.com.apple.reminders/Container_v1/Stores/Data-*.sqlite
```

It queries the `ZREMCDOBJECT` table for entity type 26 (rich links), joining against reminders by their `ZDACALENDARITEMUNIQUEIDENTIFIER` (which maps to EventKit's `calendarItemIdentifier`).

This requires **Full Disk Access** (FDA) for the parent app. When FDA is not granted, iClaude still works for everything else -- it just cannot read reminder URLs from the database. In this case, every reminder response includes a `warning` field:

```json
{
  "warning": "Reminder URLs from share sheet are not visible — Full Disk Access not granted. ..."
}
```

When both the EventKit `.url` property and the database rich link exist but differ, iClaude reports both:

| Field | Description |
|---|---|
| `url` | The URL the user sees in the Reminders app (rich link from database) |
| `altURL` | The hidden EventKit API URL (only visible programmatically) |
| `altURLNote` | Explanation of why the two values differ |

For batch operations (listing reminders), URLs are fetched in a single query per database file rather than per-reminder, keeping performance reasonable even for large lists.

### EventKit 4-Year Limit Workaround

EventKit silently truncates event query results to approximately 4 years from the start date. iClaude works around this by splitting date ranges into 1-year chunks and merging the results. This is transparent to callers -- you can query any date range and get complete results.

### Recurring Events

Events include `isRecurring` (boolean) and `recurrenceOriginalStartDate` (the date the recurring series was first created). Use the `--series` flag on `update` and `delete` to affect all future occurrences rather than just a single instance.

---

## Data Models

### Reminder

| Field | Type | Notes |
|---|---|---|
| `id` | string | EventKit `calendarItemIdentifier` |
| `title` | string | |
| `isCompleted` | bool | |
| `dueDate` | string / null | ISO 8601 |
| `priority` | int | 0=none, 1=high, 5=medium, 9=low |
| `notes` | string / null | |
| `url` | string / null | Rich link or EventKit URL (see URL Hack above) |
| `altURL` | string / null | Present only when two conflicting URLs exist |
| `altURLNote` | string / null | Explains the conflict |
| `warning` | string / null | Degradation notice (e.g., missing FDA) |
| `creationDate` | string / null | ISO 8601 |
| `completionDate` | string / null | ISO 8601 |
| `listName` | string | Parent reminder list name |

### Event

| Field | Type | Notes |
|---|---|---|
| `id` | string | EventKit `eventIdentifier` |
| `title` | string | |
| `startDate` | string / null | ISO 8601 |
| `endDate` | string / null | ISO 8601 |
| `isAllDay` | bool | |
| `isRecurring` | bool | |
| `recurrenceOriginalStartDate` | string / null | Series origin date |
| `location` | string / null | |
| `url` | string / null | |
| `notes` | string / null | |
| `calendarName` | string | Parent calendar name |
| `availability` | string | busy, free, tentative, unavailable, notSupported |

### Reminder List

| Field | Type | Notes |
|---|---|---|
| `id` | string | Calendar identifier |
| `name` | string | Display name |
| `color` | string / null | Hex (e.g., `#5856D6`) |

### Calendar

| Field | Type | Notes |
|---|---|---|
| `id` | string | Calendar identifier |
| `name` | string | Display name |
| `color` | string / null | Hex (e.g., `#FF3B30`) |
| `type` | string | local, calDAV, exchange, subscription, birthday |

---

## Troubleshooting

### "Access to Reminders denied" / "Access to Calendar denied"

The parent process does not have TCC permission. iClaude attempts to auto-grant this on startup, but if it fails, the error message includes the exact `sqlite3` command to fix it. You can also use [selfauth](https://github.com/MarqueIV/selfauth) to bypass the issue entirely.

### Reminder URLs are null when they should have values

Check the `warning` field in the response. It will say Full Disk Access is not granted. Fix: **System Settings > Privacy & Security > Full Disk Access**, then enable it for your terminal or editor app.

### Calendar queries return fewer events than expected

This is the EventKit 4-year truncation issue. iClaude handles it automatically with 1-year chunking, but if you still see gaps, file an issue.

---

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+ (for building from source)
- Reminders and/or Calendar access (auto-granted or via [selfauth](https://github.com/MarqueIV/selfauth))
- Full Disk Access (optional -- only needed for reading reminder URLs from the database)

## License

MIT
