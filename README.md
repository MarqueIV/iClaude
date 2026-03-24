# iClaude

A Swift CLI for managing Apple iCloud data from the command line. Designed to be called by AI agents like [Claude Code](https://claude.ai/claude-code), but works great as a standalone tool too.

Built with native Apple frameworks (EventKit, etc.) for fast, direct access — no AppleScript, no osascript, no JXA.

## Modules

### Reminders

Full CRUD access to Apple Reminders via EventKit.

**Read operations:**

```bash
iclaude reminders list                    # all lists
iclaude reminders list "Shopping"         # reminders in a specific list
iclaude reminders list --all              # all reminders across all lists
iclaude reminders show <id>              # single reminder by ID
```

**Write operations (ID-first):**

All mutating commands take a reminder ID as the primary identifier. Alternatively, use `--current-title` (with optional `--list`) to find by name. When multiple reminders match a title, the response includes all matches with their IDs for disambiguation.

```bash
# Create
iclaude reminders create --new-title "Buy milk" --list "Shopping"
iclaude reminders create --new-title "Call dentist" --list "Reminders" --due 2026-04-01 --priority 1

# Update (by ID or title)
iclaude reminders update 3E7C1731-... --new-title "Buy oat milk"
iclaude reminders update --current-title "Buy milk" --list "Shopping" --new-title "Buy oat milk"

# Complete / Delete (by ID or title)
iclaude reminders complete 3E7C1731-...
iclaude reminders delete --current-title "Buy milk" --list "Shopping"
```

### Calendar

Full CRUD access to Apple Calendar events via EventKit.

**Read operations:**

```bash
iclaude calendar list                     # all calendars
iclaude calendar list "Work"              # events in a calendar (default: next 7 days)
iclaude calendar list --today             # today's events across all calendars
iclaude calendar list --week              # next 7 days across all calendars
iclaude calendar list --from 2026-04-01 --to 2026-04-30   # custom date range
iclaude calendar show <id>              # single event by ID
```

**Write operations (ID-first):**

```bash
# Create
iclaude calendar create --new-title "Team standup" --calendar "Work" --start "2026-04-01 09:00" --end "2026-04-01 09:30"
iclaude calendar create --new-title "Vacation" --calendar "Personal" --start 2026-07-01 --end 2026-07-14 --all-day

# Update / Delete (by ID or title)
iclaude calendar update <id> --new-title "Renamed event" --start "2026-04-02 10:00"
iclaude calendar delete <id>
iclaude calendar delete --current-title "Team standup" --calendar "Work"
```

**Recurring events** include `isRecurring` and `recurrenceOriginalStartDate` fields — useful for finding when a recurring event was originally created.

### Planned

- **Contacts** — lookup, create, update

## Output

JSON by default. Add `--pretty` for pretty-printed JSON.

```bash
# Compact (default — for AI agents)
iclaude reminders list
# [{"name":"Reminders","id":"3E7C1731-...","color":"#5856D6"}]

# Pretty-printed (for humans)
iclaude reminders list --pretty
```

**Disambiguation** — when `--current-title` matches multiple items:
```json
{
  "error": "Multiple reminders match 'Buy milk'. Use the id from one of the matches below.",
  "matches": [
    {"id": "3E7C...", "title": "Buy milk", "listName": "Shopping"},
    {"id": "7F2A...", "title": "Buy milk", "listName": "Groceries"}
  ]
}
```

## Date Formats

All date flags accept:
- ISO8601: `2024-01-15T10:00:00Z`
- Date only: `2024-01-15`
- Date and time: `2024-01-15 10:00`

## Installation

### Build from source

```bash
swift build -c release
cp .build/release/iclaude /usr/local/bin/
```

## macOS Permissions

iClaude uses EventKit which requires Reminders and Calendar access. On first run, macOS will prompt you to grant permission.

If running from an Electron-based editor (VS Code, Cursor), macOS may silently deny the permission. Use [`selfauth`](https://github.com/MarqueIV/selfauth) to fix this:

```bash
selfauth iclaude reminders list
selfauth iclaude calendar list --today
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9 or later (for building from source)

## License

MIT
