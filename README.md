# iClaude

A Swift CLI for managing Apple iCloud data from the command line. Designed to be called by AI agents like [Claude Code](https://claude.ai/claude-code), but works great as a standalone tool too.

Built with native Apple frameworks (EventKit, etc.) for fast, direct access — no AppleScript, no osascript, no JXA.

## Current Modules

### Reminders

Full CRUD access to Apple Reminders via EventKit.

| Command | Description |
|---------|-------------|
| `iclaude lists` | List all reminder lists |
| `iclaude list <list-name>` | List reminders in a specific list |
| `iclaude add <title> --list <list> [--due <date>] [--notes <text>] [--priority <0-9>]` | Create a reminder |
| `iclaude complete <title> --list <list>` | Mark a reminder as complete |
| `iclaude delete <title> --list <list>` | Delete a reminder |
| `iclaude edit <title> --list <list> [--title <new>] [--due <date>] [--notes <text>] [--priority <0-9>]` | Edit a reminder |

### Planned

- **Calendar** — events, scheduling, availability
- **Contacts** — lookup, create, update
- **Notes** — search, create, append

## Output

JSON by default. Add `--pretty` for pretty-printed JSON.

```bash
# Compact (default — for AI agents)
iclaude lists
# [{"name":"Reminders","id":"3E7C1731-...","color":"#5856D6"}]

# Pretty-printed (for humans)
iclaude lists --pretty
```

Errors return `{"error":"message"}` with a non-zero exit code.

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

### Or add to your PATH

```bash
cp .build/release/iclaude ~/path/to/your/bin/
```

## macOS Permissions

iClaude uses EventKit which requires Reminders access. On first run, macOS will prompt you to grant permission.

If running from an Electron-based editor (VS Code, Cursor), macOS may silently deny the permission. Use [`selfauth`](https://github.com/MarqueIV/selfauth) to fix this:

```bash
selfauth iclaude lists
```

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9 or later (for building from source)

## License

MIT
