// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThinkBreak",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ThinkBreakCore", targets: ["ThinkBreakCore"]),
        .executable(name: "ThinkBreak", targets: ["ThinkBreakApp"]),
        .executable(name: "thinkbreak-hook", targets: ["ThinkBreakHook"]),
        .executable(name: "ThinkBreakTests", targets: ["ThinkBreakCoreTests"]),
    ],
    targets: [
        .target(name: "ThinkBreakCore"),
        .executableTarget(name: "ThinkBreakApp", dependencies: ["ThinkBreakCore"]),
        .executableTarget(name: "ThinkBreakHook", dependencies: ["ThinkBreakCore"]),
        .executableTarget(name: "ThinkBreakCoreTests", dependencies: ["ThinkBreakCore"], path: "Tests/ThinkBreakCoreTests"),
    ]
)
