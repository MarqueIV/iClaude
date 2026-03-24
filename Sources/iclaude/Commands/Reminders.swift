import ArgumentParser

struct Reminders: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Manage Apple Reminders.",
        subcommands: [
            ListReminders.self,
            Show.self,
            Create.self,
            Update.self,
            Complete.self,
            Delete.self,
        ]
    )
}
