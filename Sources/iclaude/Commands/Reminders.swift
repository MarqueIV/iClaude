import ArgumentParser

struct Reminders: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Manage Apple Reminders.",
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
