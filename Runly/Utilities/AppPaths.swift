import Foundation

enum AppPaths {
    static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let url = base.appendingPathComponent("Runly", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var logsRoot: URL {
        let url = applicationSupport.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func logsDirectory(for taskID: UUID) -> URL {
        let url = logsRoot.appendingPathComponent(taskID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var launchAgentsDirectory: URL {
        let url = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func launchAgentPlist(for taskID: UUID) -> URL {
        launchAgentsDirectory.appendingPathComponent("com.runly.task.\(taskID.uuidString).plist")
    }

    static var currentExecutableURL: URL {
        URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    }
}
