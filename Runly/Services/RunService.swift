import Foundation
import SwiftData

@Observable
@MainActor
final class RunSession {
    var runID: UUID?
    var taskID: UUID?
    var status: RunStatus = .queued
    var liveOutput: String = ""
    var isRunning: Bool = false
    var errorMessage: String?
    var startedAt: Date?

    func reset() {
        runID = nil
        taskID = nil
        status = .queued
        liveOutput = ""
        isRunning = false
        errorMessage = nil
        startedAt = nil
    }
}

@MainActor
final class RunService {
    private let modelContext: ModelContext
    private let executor = CommandExecutor()
    private let logService: LogService
    private let session: RunSession

    /// Called after run lifecycle transitions so Menu Bar / Dashboard can refresh.
    var onStateChange: (() -> Void)?

    init(modelContext: ModelContext, logService: LogService, session: RunSession) {
        self.modelContext = modelContext
        self.logService = logService
        self.session = session
    }

    func fetchRuns(for taskID: UUID, limit: Int = 50) throws -> [TaskRun] {
        var descriptor = FetchDescriptor<TaskRun>(
            predicate: #Predicate { $0.taskID == taskID },
            sortBy: [SortDescriptor(\TaskRun.startAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func fetchRuns(descriptor: FetchDescriptor<TaskRun>) throws -> [TaskRun] {
        try modelContext.fetch(descriptor)
    }

    func stopCurrent() {
        guard session.isRunning else { return }
        executor.stop()
        appendLive("\n[runly] stop requested\n")
    }

    /// Mark DB rows stuck on `.running` as `.failed` when no live child / headless process exists.
    @discardableResult
    func reconcileOrphanedRuns() -> Int {
        var fixed = 0

        let allRuns = (try? modelContext.fetch(FetchDescriptor<TaskRun>())) ?? []
        let stuckRuns = allRuns.filter { $0.status == .running }

        for run in stuckRuns {
            let age = Date().timeIntervalSince(run.startAt)
            // Slow CLI startups (cursor-agent) need a wide grace window.
            if age < 60 {
                continue
            }

            if HeadlessProcessProbe.isRunning(taskID: run.taskID) {
                continue
            }

            // In-process execute() owns this row until it writes a final status.
            // iTerm runs often have no Foundation.Process child, so "PID gone"
            // must not flip a still-running GUI session to failed.
            if session.isRunning, session.runID == run.id {
                continue
            }

            finalizeOrphanedRun(run, status: .failed)
            fixed += 1
        }

        let tasks = (try? modelContext.fetch(FetchDescriptor<RunlyTask>())) ?? []
        for task in tasks where task.lastRunStatus == .running {
            if isActivelyExecuting(taskID: task.id) { continue }
            let stillOpen = allRuns.contains { $0.taskID == task.id && $0.status == .running }
            if stillOpen { continue }
            // Same grace: don't clear task-level running while a young run may still be starting.
            if let last = task.lastRunAt, Date().timeIntervalSince(last) < 60 {
                continue
            }
            task.lastRunStatus = .failed
            task.lastRunAt = task.lastRunAt ?? .now
            fixed += 1
        }

        if fixed > 0 {
            try? modelContext.save()
            NSLog("Runly reconciled %d orphaned running run(s)", fixed)
            onStateChange?()
        }
        return fixed
    }

    private func isActivelyExecuting(taskID: UUID) -> Bool {
        if session.isRunning, session.taskID == taskID {
            return true
        }
        if executor.hasLiveProcess, session.taskID == taskID {
            return true
        }
        return HeadlessProcessProbe.isRunning(taskID: taskID)
    }

    private func finalizeOrphanedRun(_ run: TaskRun, status: RunStatus) {
        guard run.status == .running else { return }
        let end = Date()
        run.status = status
        run.endAt = end
        run.duration = end.timeIntervalSince(run.startAt)
        if run.exitCode == nil {
            run.exitCode = status == .cancelled ? 15 : 1
        }

        let note = """

        [runly] process disappeared — marked \(status.rawValue)
        Duration: \(String(format: "%.1fs", run.duration ?? 0))
        ────────────────────────────────────
        """
        if let fileName = run.logFileName {
            let url = AppPaths.logsDirectory(for: run.taskID).appendingPathComponent(fileName)
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                if let data = note.data(using: .utf8) {
                    try? handle.write(contentsOf: data)
                }
            }
        }
        logService.endRunLog(runID: run.id)

        if session.runID == run.id {
            appendLive(note)
            session.status = status
            session.isRunning = false
            session.errorMessage = "Process disappeared"
        }

        let taskID = run.taskID
        if let task = try? modelContext.fetch(
            FetchDescriptor<RunlyTask>(predicate: #Predicate { $0.id == taskID })
        ).first, task.lastRunStatus == .running || task.lastRunStatus == nil {
            task.lastRunStatus = status
            task.lastRunDuration = run.duration
            task.lastRunAt = end
        }
    }

    func runNow(_ task: RunlyTask) async {
        guard !session.isRunning else {
            session.errorMessage = "Another task is already running."
            return
        }

        session.reset()
        session.isRunning = true
        session.taskID = task.id
        session.status = .running
        session.startedAt = .now
        session.liveOutput = ""
        onStateChange?()

        defer {
            session.isRunning = false
            onStateChange?()
        }

        do {
            let result = try await execute(task: task, attempt: 0)
            session.status = result
            task.lastRunStatus = result
            task.lastRunAt = .now
            task.nextRunAt = ScheduleCalculator.nextRunDate(
                type: task.scheduleType,
                expression: task.scheduleExpression,
                enabled: task.enabled
            )
            try modelContext.save()
        } catch {
            session.errorMessage = error.localizedDescription
            session.status = .failed
            task.lastRunStatus = .failed
            task.lastRunAt = .now
            try? modelContext.save()
            appendLive("\n[runly] error: \(error.localizedDescription)\n")
        }
    }

    /// Headless entry used by leftover `--run-task` invocations.
    func runHeadless(taskID: UUID) async throws {
        let id = taskID
        let descriptor = FetchDescriptor<RunlyTask>(predicate: #Predicate { $0.id == id })
        guard let task = try modelContext.fetch(descriptor).first else {
            throw CommandExecutorError.failedToStart("Task not found: \(taskID)")
        }
        guard task.enabled else { return }

        session.reset()
        session.isRunning = true
        session.taskID = task.id
        session.status = .running
        session.startedAt = .now
        defer { session.isRunning = false }

        _ = try await execute(task: task, attempt: 0)
        task.lastRunAt = .now
        task.nextRunAt = ScheduleCalculator.nextRunDate(
            type: task.scheduleType,
            expression: task.scheduleExpression,
            enabled: task.enabled
        )
        try modelContext.save()
    }

    /// CLI / agent “Run Now” — runs even when the task is disabled.
    func runFromCLI(taskID: UUID) async throws {
        let id = taskID
        let descriptor = FetchDescriptor<RunlyTask>(predicate: #Predicate { $0.id == id })
        guard let task = try modelContext.fetch(descriptor).first else {
            throw CommandExecutorError.failedToStart("Task not found: \(taskID)")
        }

        session.reset()
        session.isRunning = true
        session.taskID = task.id
        session.status = .running
        session.startedAt = .now
        defer {
            session.isRunning = false
            onStateChange?()
        }

        let result = try await execute(task: task, attempt: 0)
        session.status = result
        task.lastRunStatus = result
        task.lastRunAt = .now
        task.nextRunAt = ScheduleCalculator.nextRunDate(
            type: task.scheduleType,
            expression: task.scheduleExpression,
            enabled: task.enabled
        )
        try modelContext.save()
    }

    // MARK: - Core

    @discardableResult
    private func execute(task: RunlyTask, attempt: Int) async throws -> RunStatus {
        let run = TaskRun(taskID: task.id, status: .running)
        modelContext.insert(run)
        try modelContext.save()
        onStateChange?()

        session.runID = run.id
        session.status = .running
        if session.startedAt == nil {
            session.startedAt = run.startAt
        }

        let log = try logService.beginRunLog(taskID: task.id, runID: run.id, startedAt: run.startAt)
        run.logFileName = log.fileName
        run.stdoutFileName = log.stdoutFileName
        run.stderrFileName = log.stderrFileName
        try modelContext.save()

        let resolved = try AgentService.resolve(task)
        let header = """
        ────────────────────────────────────
        $ \(resolved.preview)
        cwd: \(resolved.workingDirectory?.path ?? "(default)")
        runtime: \(ITermRunSettings.isEnabled ? "iTerm" : "process")
        attempt: \(attempt + 1)/\(max(1, task.retryCount + 1))
        started: \(run.startAt.formatted(date: .abbreviated, time: .standard))

        """
        write(header, runID: run.id, stream: .meta)

        task.lastRunStatus = .running
        task.lastRunAt = run.startAt
        try modelContext.save()
        onStateChange?()

        let timeout = TimeInterval(max(0, task.timeout))
        let useITerm = ITermRunSettings.isEnabled
        let spec = CommandSpec(
            executableURL: resolved.executableURL,
            arguments: resolved.arguments,
            environment: resolved.environment,
            currentDirectoryURL: resolved.workingDirectory,
            timeout: timeout,
            runInITerm: useITerm
        )

        let result: CommandResult
        do {
            result = try await executor.run(
                spec,
                onStdout: { [weak self] text in
                    Task { @MainActor in
                        self?.write(text, runID: run.id, stream: .out)
                    }
                },
                onStderr: { [weak self] text in
                    Task { @MainActor in
                        self?.write(text, runID: run.id, stream: .err)
                    }
                }
            )
        } catch {
            logService.endRunLog(runID: run.id)
            run.status = .failed
            run.endAt = .now
            run.duration = Date().timeIntervalSince(run.startAt)
            try modelContext.save()
            onStateChange?()
            throw error
        }

        logService.endRunLog(runID: run.id)

        let status: RunStatus
        if result.cancelled {
            status = .cancelled
        } else if result.timedOut {
            status = .timeout
        } else if result.exitCode == 0 {
            status = .success
        } else {
            status = .failed
        }

        let footer = """

        Process exited with code \(result.exitCode)\(result.timedOut ? " (timeout)" : "")\(result.cancelled ? " (cancelled)" : "")
        Duration: \(String(format: "%.1fs", result.duration))
        ────────────────────────────────────
        """
        if let fileName = run.logFileName {
            let url = AppPaths.logsDirectory(for: task.id).appendingPathComponent(fileName)
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                if let data = footer.data(using: .utf8) {
                    try? handle.write(contentsOf: data)
                }
            }
            appendLive(footer)
        }

        run.status = status
        run.exitCode = Int(result.exitCode)
        run.endAt = .now
        run.duration = result.duration
        task.lastRunStatus = status
        task.lastRunDuration = result.duration
        try modelContext.save()
        onStateChange?()

        await SystemNotificationService.shared.postRunFinished(
            task: task,
            run: run,
            status: status
        )

        let templates = (try? modelContext.fetch(FetchDescriptor<NotificationTemplate>())) ?? []
        let commandTemplate = NotificationService.resolveCommandTemplate(task: task, templates: templates)
        await NotificationService.maybeNotify(
            task: task,
            status: status,
            exitCode: Int(result.exitCode),
            duration: result.duration,
            stdout: result.stdout,
            commandTemplate: commandTemplate
        )

        if status != .success, status != .cancelled, attempt < task.retryCount {
            write("\n[runly] retrying (\(attempt + 2)/\(task.retryCount + 1))…\n", runID: run.id, stream: .meta)
            return try await execute(task: task, attempt: attempt + 1)
        }

        return status
    }

    private func write(_ text: String, runID: UUID, stream: LogStream) {
        logService.append(runID: runID, stream: stream, text: text)
        appendLive(text)
    }

    private func appendLive(_ text: String) {
        session.liveOutput += text
        if session.liveOutput.count > 200_000 {
            session.liveOutput = String(session.liveOutput.suffix(150_000))
        }
    }
}
