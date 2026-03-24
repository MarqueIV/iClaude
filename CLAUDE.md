# iClaude

Swift CLI for managing Apple iCloud data (Reminders, and eventually Calendar, Contacts,
Notes). Uses native Apple frameworks. Designed to be called by AI agents.

## Build

```
swift build
```

## Running

Try direct execution first:
```
iclaude <module> <command> [args]
```

If you get `{"error":"Access to Reminders denied..."}`, use `selfauth` (should be in PATH):
```
selfauth iclaude <module> <command> [args]
```

See: https://github.com/MarqueIV/selfauth

## Reminders Commands

### Read operations

```
iclaude reminders list                          # all lists
iclaude reminders list <list-name>              # reminders in a specific list
iclaude reminders list --all                    # all reminders across all lists
iclaude reminders show <id>                     # single reminder by ID
```

### Write operations (ID-first, --current-title fallback)

All mutating commands take a reminder ID as the primary identifier. Use `--current-title`
(with optional `--list` to narrow) as an alternative. If multiple reminders match a title,
the response includes all matches with their IDs for disambiguation.

```
iclaude reminders create --new-title <title> --list <list> [--due <date>] [--notes <text>] [--priority <0-9>]
iclaude reminders update <id> [--new-title <title>] [--due <date>] [--notes <text>] [--priority <0-9>]
iclaude reminders update --current-title <title> [--list <list>] [--new-title <title>] [--due <date>]
iclaude reminders complete <id>
iclaude reminders complete --current-title <title> [--list <list>]
iclaude reminders delete <id>
iclaude reminders delete --current-title <title> [--list <list>]
```

## Output

JSON by default. Add `--pretty` for pretty-printed JSON.

- Success (read ops): JSON array or object
- Success (write ops): `{"success":true,"message":"..."}`
- Error: `{"error":"message"}`
- Disambiguation: `{"error":"Multiple reminders match...","matches":[...]}`

## Date Formats

The `--due` flag accepts: `2024-01-15T10:00:00Z` (ISO8601), `2024-01-15`, or `2024-01-15 10:00`.
