import ArgumentParser

struct GlobalOptions: ParsableArguments {

    @Flag(name: .long, help: "Human-readable pretty-printed output instead of compact JSON.")
    var pretty: Bool = false
}
