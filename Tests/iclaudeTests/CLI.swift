import Foundation
import XCTest

// Locates the built binary and runs it as a subprocess.
// The test runner itself never touches EventKit — only the CLI binary does,
// which means Reminders permission only needs to be granted once for that binary.
enum CLI {

    static let binaryURL: URL = {
        // #file → .../Tests/iclaudeTests/CLI.swift — walk up to package root
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build/debug/iclaude")
    }()

    struct Result {
        let stdout: String
        let stderr: String
        let exitCode: Int32

        var json: Any? { try? JSONSerialization.jsonObject(with: Data(stdout.utf8)) }
        var jsonArray: [[String: Any]]? { json as? [[String: Any]] }
        var jsonObject: [String: Any]? { json as? [String: Any] }
        var isSuccess: Bool { exitCode == 0 }
    }

    @discardableResult
    static func run(_ args: String...) throws -> Result {
        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            throw XCTSkip("Binary not found at \(binaryURL.path). Run `swift build` first.")
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = Array(args)

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError  = errPipe

        try process.run()
        process.waitUntilExit()

        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return Result(stdout: out, stderr: err, exitCode: process.terminationStatus)
    }
}
