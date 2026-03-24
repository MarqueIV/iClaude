# iClaude — Apple Reminders CLI

Swift CLI for managing Apple Reminders via EventKit. Designed to be called by AI agents.

## Build

```
swift build
```

## Running

Try direct execution first:
```
.build/debug/iclaude <command> [args]
```

If you get `{"error":"Access to Reminders denied..."}`, the parent process (e.g. VS Code)
lacks TCC permission for Reminders. Use `selfauth` (should be in PATH) to break the TCC chain:
```
selfauth .build/debug/iclaude <command> [args]
```

`selfauth` launches the command with its own macOS TCC identity, independent of the
parent process. stdout/stderr pipe through normally. First run may trigger a macOS
permission dialog. See: https://github.com/MarqueIV/selfauth

## Commands

| Command | Description |
|---------|-------------|
| `iclaude lists` | List all reminder lists |
| `iclaude list <list-name>` | List reminders in a specific list |
| `iclaude add <title> --list <list> [--due <date>] [--notes <text>] [--priority <0-9>]` | Create a reminder |
| `iclaude complete <title> --list <list>` | Mark a reminder as complete |
| `iclaude delete <title> --list <list>` | Delete a reminder |
| `iclaude edit <title> --list <list> [--title <new>] [--due <date>] [--notes <text>] [--priority <0-9>]` | Edit a reminder |

## Output

JSON by default. Add `--pretty` for pretty-printed JSON.

- Success (read ops): JSON array of objects
- Success (write ops): `{"success":true,"message":"..."}`
- Error: `{"error":"message"}`

## Date Formats

The `--due` flag accepts: `2024-01-15T10:00:00Z` (ISO8601), `2024-01-15`, or `2024-01-15 10:00`.
