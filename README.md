# iClaude

A Swift CLI for managing Apple iCloud data from the command line. Designed to be called by AI agents like [Claude Code](https://claude.ai/claude-code), but works great as a standalone tool too.

Built with native Apple frameworks (EventKit, etc.) for fast, direct access — no AppleScript, no osascript, no JXA.

## Current Modules

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
iclaude reminders update 3E7C1731-AC9C-4064-B9BD-E4E41E63A479 --new-title "Buy oat milk"
iclaude reminders update --current-title "Buy milk" --list "Shopping" --new-title "Buy oat milk"

# Complete (by ID or title)
iclaude reminders complete 3E7C1731-AC9C-4064-B9BD-E4E41E63A479
iclaude reminders complete --current-title "Buy milk" --list "Shopping"

# Delete (by ID or title)
iclaude reminders delete 3E7C1731-AC9C-4064-B9BD-E4E41E63A479
iclaude reminders delete --current-title "Buy milk" --list "Shopping"
```

### Planned

- **Calendar** — events, scheduling, availability
- **Contacts** — lookup, create, update
- **Notes** — search, create, append

## Output

JSON by default. Add `--pretty` for pretty-printed JSON.

```bash
# Compact (default — for AI agents)
iclaude reminders list
# [{"name":"Reminders","id":"3E7C1731-...","color":"#5856D6"}]

# Pretty-printed (for humans)
iclaude reminders list --pretty
```

**Disambiguation** — when `--current-title` matches multiple reminders:
```json
{
  "error": "Multiple reminders match 'Buy milk'. Use the id from one of the matches below.",
  "matches": [
    {"id": "3E7C...", "title": "Buy milk", "listName": "Shopping", "dueDate": "2026-04-01T10:00:00Z"},
    {"id": "7F2A...", "title": "Buy milk", "listName": "Groceries", "dueDate": null}
  ]
}
```

## Date Formats

The `--due` flag accepts:
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

iClaude uses EventKit which requires Reminders access. On first run, macOS will prompt you to grant permission.

If running from an Electron-based editor (VS Code, Cursor), macOS may silently deny the permission. Use [`selfauth`](https://github.com/MarqueIV/selfauth) to fix this:

```bash
selfauth iclaude reminders list
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9 or later (for building from source)

## License

MIT
