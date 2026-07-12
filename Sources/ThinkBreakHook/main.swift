import Foundation
import ThinkBreakCore

let arguments = CommandLine.arguments
let environment = ProcessInfo.processInfo.environment
let stdin = FileHandle.standardInput.readDataToEndOfFile()
let eventName = arguments.count > 1 ? arguments[1] : ""
let hostName = arguments.count > 2 ? arguments[2] : "unknown"
let fallbackSessionID = environment["CODEX_THREAD_ID"] ?? environment["CLAUDE_SESSION_ID"]

func log(_ message: String) {
    let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
    let directory = ThinkBreakPaths.applicationSupportDirectory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    if !FileManager.default.fileExists(atPath: ThinkBreakPaths.logFile.path) {
        FileManager.default.createFile(atPath: ThinkBreakPaths.logFile.path, contents: nil)
    }
    if let handle = try? FileHandle(forWritingTo: ThinkBreakPaths.logFile) {
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
        try? handle.close()
    }
}

func launchApp() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-g", "-j", "-b", "com.tx0zero.ThinkBreak"]
    try? process.run()
    process.waitUntilExit()
}

do {
    let event = try HookInvocationParser.parse(
        eventName: eventName,
        hostName: hostName,
        stdin: stdin,
        fallbackSessionID: fallbackSessionID
    )
    do {
        try UnixSocketClient.send(event, to: ThinkBreakPaths.socketFile)
    } catch {
        launchApp()
        var delivered = false
        for _ in 0..<20 {
            Thread.sleep(forTimeInterval: 0.1)
            if (try? UnixSocketClient.send(event, to: ThinkBreakPaths.socketFile)) != nil {
                delivered = true
                break
            }
        }
        if !delivered { log("Could not deliver \(eventName) event: \(error.localizedDescription)") }
    }
} catch {
    log("Ignored malformed hook invocation: \(error.localizedDescription)")
}

// Hooks must never block or fail the agent host.
exit(0)
