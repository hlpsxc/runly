import Foundation
import SwiftData

@MainActor
final class TaskService {
    private let modelContext: ModelContext
    private let launchd = LaunchdService()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [RunlyTask] {
        let descriptor = FetchDescriptor<RunlyTask>(
            sortBy: [SortDescriptor(\RunlyTask.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func create(_ draft: TaskDraft) throws -> RunlyTask {
        let task = draft.makeTask()
        task.nextRunAt = ScheduleCalculator.nextRunDate(
            type: task.scheduleType,
            expression: task.scheduleExpression,
            enabled: task.enabled
        )
        modelContext.insert(task)
        try modelContext.save()
        _ = launchd.sync(task: task)
        return task
    }

    func update(_ task: RunlyTask, with draft: TaskDraft) throws {
        draft.apply(to: task)
        task.updatedAt = .now
        task.nextRunAt = ScheduleCalculator.nextRunDate(
            type: task.scheduleType,
            expression: task.scheduleExpression,
            enabled: task.enabled
        )
        try modelContext.save()
        _ = launchd.reload(task: task)
    }

    func delete(_ task: RunlyTask) throws {
        let id = task.id
        launchd.remove(taskID: id)
        LogService().deleteLogs(for: id)
        modelContext.delete(task)
        try modelContext.save()
    }

    func setEnabled(_ task: RunlyTask, enabled: Bool) throws {
        task.enabled = enabled
        task.updatedAt = .now
        task.nextRunAt = ScheduleCalculator.nextRunDate(
            type: task.scheduleType,
            expression: task.scheduleExpression,
            enabled: task.enabled
        )
        try modelContext.save()
        _ = launchd.sync(task: task)
    }

    func delete(ids: Set<UUID>) throws {
        let all = try fetchAll()
        for task in all where ids.contains(task.id) {
            launchd.remove(taskID: task.id)
            LogService().deleteLogs(for: task.id)
            modelContext.delete(task)
        }
        try modelContext.save()
    }

    func refreshNextRun(_ task: RunlyTask) throws {
        task.nextRunAt = ScheduleCalculator.nextRunDate(
            type: task.scheduleType,
            expression: task.scheduleExpression,
            enabled: task.enabled
        )
        try modelContext.save()
    }

    var launchdService: LaunchdService { launchd }
}

/// Editable form state shared by Create / Edit flows.
struct TaskDraft: Equatable {
    var name: String = "New Task"
    var enabled: Bool = true
    var type: TaskType = .command
    var command: String = ""
    var arguments: String = ""
    var workingDirectory: String = ""
    var scheduleType: ScheduleType = .interval
    var scheduleExpression: String = "Every day"
    var environment: String = ""
    var proxyEnabled: Bool = false
    var httpProxy: String = ""
    var httpsProxy: String = ""
    var socksProxy: String = ""
    var noProxy: String = "localhost,127.0.0.1"
    var notificationEnabled: Bool = false
    var notificationCommand: String = ""
    var notificationTrigger: NotificationTrigger = .always
    var timeout: Int = 300
    var retryCount: Int = 0
    var agentProvider: AgentProvider = .claude
    var agentPrompt: String = ""

    static func from(_ task: RunlyTask) -> TaskDraft {
        TaskDraft(
            name: task.name,
            enabled: task.enabled,
            type: task.type,
            command: task.command,
            arguments: task.arguments,
            workingDirectory: task.workingDirectory,
            scheduleType: task.scheduleType,
            scheduleExpression: task.scheduleExpression,
            environment: task.environment,
            proxyEnabled: task.proxyEnabled,
            httpProxy: task.httpProxy,
            httpsProxy: task.httpsProxy,
            socksProxy: task.socksProxy,
            noProxy: task.noProxy,
            notificationEnabled: task.notificationEnabled,
            notificationCommand: task.notificationCommand,
            notificationTrigger: task.notificationTrigger,
            timeout: task.timeout,
            retryCount: task.retryCount,
            agentProvider: task.agentProvider,
            agentPrompt: task.agentPrompt
        )
    }

    mutating func applyAgentDefaultsIfNeeded() {
        guard type == .agent else { return }
        if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            command = agentProvider.defaultExecutable
        }
    }

    func makeTask() -> RunlyTask {
        var copy = self
        copy.applyAgentDefaultsIfNeeded()
        return RunlyTask(
            name: copy.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Untitled Task"
                : copy.name.trimmingCharacters(in: .whitespacesAndNewlines),
            enabled: copy.enabled,
            type: copy.type,
            command: copy.resolvedCommand,
            arguments: copy.resolvedArguments,
            workingDirectory: copy.workingDirectory,
            scheduleType: copy.scheduleType,
            scheduleExpression: copy.scheduleExpression,
            environment: copy.environment,
            proxyEnabled: copy.proxyEnabled,
            httpProxy: copy.httpProxy,
            httpsProxy: copy.httpsProxy,
            socksProxy: copy.socksProxy,
            noProxy: copy.noProxy,
            notificationEnabled: copy.notificationEnabled,
            notificationCommand: copy.notificationCommand,
            notificationTrigger: copy.notificationTrigger,
            timeout: max(0, copy.timeout),
            retryCount: max(0, copy.retryCount),
            agentProvider: copy.agentProvider,
            agentPrompt: copy.agentPrompt
        )
    }

    func apply(to task: RunlyTask) {
        var copy = self
        copy.applyAgentDefaultsIfNeeded()
        task.name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled Task"
            : copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
        task.enabled = copy.enabled
        task.type = copy.type
        task.command = copy.resolvedCommand
        task.arguments = copy.resolvedArguments
        task.workingDirectory = copy.workingDirectory
        task.scheduleType = copy.scheduleType
        task.scheduleExpression = copy.scheduleExpression
        task.environment = copy.environment
        task.proxyEnabled = copy.proxyEnabled
        task.httpProxy = copy.httpProxy
        task.httpsProxy = copy.httpsProxy
        task.socksProxy = copy.socksProxy
        task.noProxy = copy.noProxy
        task.notificationEnabled = copy.notificationEnabled
        task.notificationCommand = copy.notificationCommand
        task.notificationTrigger = copy.notificationTrigger
        task.timeout = max(0, copy.timeout)
        task.retryCount = max(0, copy.retryCount)
        task.agentProvider = copy.agentProvider
        task.agentPrompt = copy.agentPrompt
    }

    var resolvedCommand: String {
        if type == .agent {
            let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? agentProvider.defaultExecutable : trimmed
        }
        return command
    }

    var resolvedArguments: String {
        if type == .agent, !agentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let prompt = agentPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            // Prefer storing prompt separately; leave arguments empty so AgentService can expand defaults,
            // unless the user already provided explicit argv lines.
            if !arguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return arguments
            }
            _ = prompt
            return arguments
        }
        return arguments
    }

    var previewLine: String {
        do {
            let temp = makeTask()
            return try AgentService.resolve(temp).preview
        } catch {
            let cmd = resolvedCommand.isEmpty ? "<command>" : resolvedCommand
            let args = ArgumentParser.parse(resolvedArguments).joined(separator: " ")
            return args.isEmpty ? cmd : "\(cmd) \(args)"
        }
    }
}
