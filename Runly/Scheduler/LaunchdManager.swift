import Foundation

enum LaunchdError: LocalizedError {
    case launchctlFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchctlFailed(let message):
            return message
        }
    }
}

final class LaunchdManager: @unchecked Sendable {
    private let domain: String = "gui://\(getuid())"

    func sync(task: RunlyTask) throws {
        if task.enabled, task.scheduleType != .once || hasFutureOnce(task) {
            try install(task: task)
        } else {
            try uninstall(taskID: task.id)
        }
    }

    func install(task: RunlyTask) throws {
        let job = try makeJob(for: task)
        let plistURL = AppPaths.launchAgentPlist(for: task.id)
        try job.writePlist(to: plistURL)

        _ = try? runLaunchctl(["bootout", domain, plistURL.path])
        let result = try runLaunchctl(["bootstrap", domain, plistURL.path])
        if result.exitCode != 0 {
            let legacy = try runLaunchctl(["load", "-w", plistURL.path])
            if legacy.exitCode != 0 {
                throw LaunchdError.launchctlFailed(
                    result.output.isEmpty ? legacy.output : result.output
                )
            }
        }
        _ = try? runLaunchctl(["enable", "\(domain)/\(job.label)"])
    }

    func uninstall(taskID: UUID) throws {
        let plistURL = AppPaths.launchAgentPlist(for: taskID)
        _ = try? runLaunchctl(["bootout", domain, plistURL.path])
        _ = try? runLaunchctl(["unload", "-w", plistURL.path])
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    func reload(task: RunlyTask) throws {
        try uninstall(taskID: task.id)
        if task.enabled {
            try install(task: task)
        }
    }

    func isLoaded(taskID: UUID) -> Bool {
        // Avoid spawning `launchctl` on the main/UI path — that can crash inside
        // SwiftUI layout when combined with other synchronous launchctl waits.
        FileManager.default.fileExists(atPath: AppPaths.launchAgentPlist(for: taskID).path)
    }

    /// True when launchd currently has a live PID for this agent (headless `--run-task`).
    func isJobRunning(taskID: UUID) -> Bool {
        HeadlessProcessProbe.isRunning(taskID: taskID)
    }

    /// Ask launchd to signal a running agent process (headless `--run-task`).
    func stopRunningJob(taskID: UUID) throws {
        let label = LaunchdJob.label(for: taskID)
        let result = try runLaunchctl(["kill", "SIGTERM", "\(domain)/\(label)"])
        if result.exitCode != 0 {
            throw LaunchdError.launchctlFailed(result.output.isEmpty ? "kill failed" : result.output)
        }
    }

    // MARK: - Job builder

    private func makeJob(for task: RunlyTask) throws -> LaunchdJob {
        let executable = AppPaths.currentExecutableURL.path
        var job = LaunchdJob(
            label: LaunchdJob.label(for: task.id),
            programArguments: [executable, "--run-task", task.id.uuidString],
            workingDirectory: nil,
            startInterval: nil,
            calendarYear: nil,
            calendarMonth: nil,
            calendarDay: nil,
            calendarHour: nil,
            calendarMinute: nil,
            calendarWeekday: nil,
            runAtLoad: false,
            disabled: !task.enabled
        )

        switch task.scheduleType {
        case .once:
            if let date = ScheduleCalculator.nextRunDate(
                type: .once,
                expression: task.scheduleExpression,
                enabled: true
            ) {
                let comps = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: date
                )
                job.calendarYear = comps.year
                job.calendarMonth = comps.month
                job.calendarDay = comps.day
                job.calendarHour = comps.hour
                job.calendarMinute = comps.minute
            }
        case .interval:
            let seconds = ScheduleCalculator.intervalSeconds(expression: task.scheduleExpression) ?? 86_400
            job.startInterval = max(60, seconds)
        case .daily:
            let time = ScheduleCalculator.parseDailyTime(
                task.scheduleExpression.isEmpty ? "09:00" : task.scheduleExpression
            ) ?? (9, 0)
            job.calendarHour = time.hour
            job.calendarMinute = time.minute
        case .weekly:
            if let weekly = ScheduleCalculator.parseWeekly(
                task.scheduleExpression.isEmpty ? "Mon 09:00" : task.scheduleExpression
            ) {
                job.calendarWeekday = weekly.weekday
                job.calendarHour = weekly.hour
                job.calendarMinute = weekly.minute
            } else {
                job.startInterval = 86_400
            }
        case .cron:
            applyCron(task.scheduleExpression, to: &job)
        }

        return job
    }

    private func applyCron(_ expression: String, to job: inout LaunchdJob) {
        // Best-effort 5-field cron: minute hour day-of-month month day-of-week
        let parts = expression.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count >= 5 else {
            job.startInterval = 3600
            return
        }

        if let minute = Int(parts[0]) { job.calendarMinute = minute }
        if let hour = Int(parts[1]) { job.calendarHour = hour }
        if parts[2] != "*", let day = Int(parts[2]) { job.calendarDay = day }
        if parts[3] != "*", let month = Int(parts[3]) { job.calendarMonth = month }
        if parts[4] != "*" {
            if let dow = Int(parts[4]) {
                job.calendarWeekday = dow == 7 ? 0 : dow
            }
        }

        // If nothing useful parsed, poll hourly.
        if job.calendarMinute == nil, job.calendarHour == nil {
            job.startInterval = 3600
        }
    }

    private func hasFutureOnce(_ task: RunlyTask) -> Bool {
        ScheduleCalculator.nextRunDate(
            type: .once,
            expression: task.scheduleExpression,
            enabled: true
        ) != nil
    }

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) throws -> (exitCode: Int32, output: String) {
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

/// Detects / stops a live `Runly --run-task <uuid>` process (launchd headless runner).
enum HeadlessProcessProbe {
    /// True when a live `Runly --run-task <uuid>` process exists.
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
        let needle = "--run-task \(taskID.uuidString)"
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
            return []
        }
        guard process.terminationStatus == 0 else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text
            .split(whereSeparator: \.isNewline)
            .compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 }
    }
}
