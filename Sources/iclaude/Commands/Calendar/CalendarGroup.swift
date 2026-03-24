import ArgumentParser

struct CalendarGroup: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "calendar",
        abstract: "Manage Apple Calendar events.",
        subcommands: [
            CalendarList.self,
            CalendarShow.self,
            CalendarCreate.self,
            CalendarUpdate.self,
            CalendarDelete.self,
        ]
    )
}
