import ArgumentParser

@main
struct IClaude: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "iclaude",
        abstract: "Manage Apple iCloud data from the command line.",
        discussion: """
            Output is JSON by default. Add --pretty for human-readable formatting.

            IMPORTANT — Always check responses for these fields:
              "error"   — Operation failed. Message includes fix instructions.
              "warning" — Operation succeeded but degraded (e.g. missing Full Disk Access \
            means Reminder URLs from share sheet won't be visible). Relay to the user.

            Errors for TCC permission denials include the exact sqlite3 command to fix them.
            """,
        subcommands: [
            Reminders.self,
            CalendarGroup.self,
        ]
    )
}
