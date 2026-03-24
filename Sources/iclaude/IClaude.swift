import ArgumentParser

@main
struct IClaude: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "iclaude",
        abstract: "Manage Apple Reminders from the command line.",
        subcommands: [
            Lists.self,
            ListReminders.self,
            Add.self,
            Complete.self,
            Delete.self,
            Edit.self,
        ]
    )
}
