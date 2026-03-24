import ArgumentParser

@main
struct IClaude: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "iclaude",
        abstract: "Manage Apple iCloud data from the command line.",
        subcommands: [
            Reminders.self,
        ]
    )
}
