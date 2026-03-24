# iClaude

Swift CLI for managing Apple iCloud data (Reminders, Calendar, and eventually Contacts).
Uses native Apple frameworks. Designed to be called by AI agents.

## Build

```
swift build
```

## Running

Always run through `selfauth` (in PATH) for reliable macOS permissions:
```
selfauth iclaude <module> <command> [args]
```

## Reminders Commands

### Read operations

```
selfauth iclaude reminders list                          # all lists
selfauth iclaude reminders list <list-name>              # reminders in a specific list
selfauth iclaude reminders list --all                    # all reminders across all lists
selfauth iclaude reminders show <id>                     # single reminder by ID
```

### Write operations (ID-first, --current-title fallback)

All mutating commands take a reminder ID as the primary identifier. Use `--current-title`
(with optional `--list` to narrow) as an alternative. If multiple match, the response
includes all matches with IDs for disambiguation.

```
selfauth iclaude reminders create --new-title <title> --list <list> [--due <date>] [--notes <text>] [--priority <0-9>]
selfauth iclaude reminders update <id> [--new-title <title>] [--due <date>] [--notes <text>] [--priority <0-9>]
selfauth iclaude reminders complete <id>
selfauth iclaude reminders delete <id>
```

## Calendar Commands

### Read operations

```
selfauth iclaude calendar list                           # all calendars
selfauth iclaude calendar list <calendar-name>           # events in a calendar (default: next 7 days)
selfauth iclaude calendar list --all                     # events across all calendars
selfauth iclaude calendar list --today                   # today's events
selfauth iclaude calendar list --week                    # next 7 days
selfauth iclaude calendar list --from <date> --to <date> # custom date range
selfauth iclaude calendar show <id>                      # single event by ID
```

### Write operations (ID-first, --current-title fallback)

```
selfauth iclaude calendar create --new-title <title> --calendar <cal> --start <datetime> [--end <datetime>] [--all-day] [--location <loc>] [--notes <text>]
selfauth iclaude calendar update <id> [--new-title <title>] [--start <datetime>] [--end <datetime>] [--location <loc>] [--notes <text>]
selfauth iclaude calendar delete <id>
```

## Output

JSON by default. Add `--pretty` for pretty-printed JSON.

- Success (read ops): JSON array or object
- Success (write ops): `{"success":true,"message":"..."}`
- Error: `{"error":"message"}`
- Disambiguation: `{"error":"Multiple ... match...","matches":[...]}`

### Errors and Warnings

**Always check for these fields in the response:**

- `"error"` — The operation failed. The message explains why and often includes
  the exact fix (e.g. a sqlite3 command to grant TCC permissions, or a `/grant-tcc`
  skill invocation). Follow the instructions in the error message.

- `"warning"` — The operation succeeded but something is degraded. Currently used
  when Full Disk Access is not granted, which means Reminder URLs added via the
  share sheet won't be visible. When you see a warning, relay it to the user —
  it contains the exact steps to fix the issue.

- `"altURL"` / `"altURLNote"` — A Reminder has two conflicting URLs: one set via
  the API (EventKit) and one set via the Reminders app share sheet (rich link).
  The `url` field shows what the user sees in the app. `altURL` is the hidden
  EventKit value. The `altURLNote` explains the discrepancy.

## Date Formats

All date flags accept: `2024-01-15T10:00:00Z` (ISO8601), `2024-01-15`, or `2024-01-15 10:00`.

## Event Model

Events include `isRecurring` and `recurrenceOriginalStartDate` fields — useful for
finding when a recurring event was originally created.
