import Foundation

/// One-time removal of leftover LaunchAgents from the previous launchd scheduler.
enum LaunchdCleanup {
    static func uninstallAllRunlyAgents() {
        let fm = FileManager.default
        let agents = AppPaths.launchAgentsDirectory
        let domain = "gui/\(getuid())"
        let names = (try? fm.contentsOfDirectory(atPath: agents.path)) ?? []
        for name in names where name.hasPrefix("com.runly.") && name.hasSuffix(".plist") {
            let url = agents.appendingPathComponent(name)
            _ = try? runLaunchctl(["bootout", domain, url.path])
            _ = try? runLaunchctl(["unload", "-w", url.path])
            try? fm.removeItem(at: url)
        }
    }

    @discardableResult
    private static func runLaunchctl(_ arguments: [String]) throws -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }
}

/// Detects / stops a leftover `Runly --run-task <uuid>` process.
enum HeadlessProcessProbe {
    static func isRunning(taskID: UUID) -> Bool {
        !matchingPIDs(taskID: taskID).isEmpty
    }

    @discardableResult
    static func terminate(taskID: UUID) -> Bool {
        let pids = matchingPIDs(taskID: taskID)
        guard !pids.isEmpty else { return false }
        for pid in pids {
            kill(pid, SIGTERM)
        }
        return true
    }

    private static func matchingPIDs(taskID: UUID) -> [pid_t] {
        let uuid = taskID.uuidString
        let needles = [
            "--run-task \(uuid)",
            uuid
        ]
        var pids = Set<pid_t>()
        for needle in needles {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            process.arguments = ["-f", needle]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                continue
            }
            guard process.terminationStatus == 0 else { continue }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            for line in text.split(whereSeparator: \.isNewline) {
                if let pid = pid_t(line.trimmingCharacters(in: .whitespaces)), pid > 0 {
                    pids.insert(pid)
                }
            }
        }
        let selfPid = ProcessInfo.processInfo.processIdentifier
        pids.remove(selfPid)
        return Array(pids)
    }
}
