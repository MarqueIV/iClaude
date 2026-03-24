import ArgumentParser

struct Lists: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "List all reminder lists."
    )

    @OptionGroup var global: GlobalOptions

    mutating func run() async throws {

        let ek = EventKitManager()
        do {
            try await ek.requestAccess()
            let lists = ek.allLists().map { ReminderListInfo($0) }
            print(try OutputFormatter.json(lists, pretty: global.pretty))
        } catch {
            print(OutputFormatter.error(error.localizedDescription, pretty: global.pretty))
            throw ExitCode.failure
        }
    }
}
