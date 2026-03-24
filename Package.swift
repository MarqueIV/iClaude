// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iclaude",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "iclaude",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/iclaude"
        ),
.testTarget(
            name: "iclaudeTests",
            path: "Tests/iclaudeTests"
        ),
    ]
)
