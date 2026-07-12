import Foundation

public enum ThinkBreakPaths {
    public static var applicationSupportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ThinkBreak", isDirectory: true)
    }

    public static var settingsFile: URL { applicationSupportDirectory.appendingPathComponent("settings.json") }
    public static var socketFile: URL { applicationSupportDirectory.appendingPathComponent("thinkbreak.sock") }
    public static var logFile: URL { applicationSupportDirectory.appendingPathComponent("thinkbreak.log") }
}

public struct FileSettingsRepository {
    public let directory: URL
    public init(directory: URL = ThinkBreakPaths.applicationSupportDirectory) {
        self.directory = directory
    }

    public func load() throws -> ThinkBreakSettings {
        let file = directory.appendingPathComponent("settings.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return .default }
        return try JSONDecoder().decode(ThinkBreakSettings.self, from: Data(contentsOf: file))
    }

    public func save(_ settings: ThinkBreakSettings) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: directory.appendingPathComponent("settings.json"), options: .atomic)
    }
}
