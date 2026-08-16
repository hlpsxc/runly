import Foundation
import SwiftData

/// Scheduled automation unit. Named `RunlyTask` to avoid clashing with Swift concurrency `Task`.
@Model
final class RunlyTask {
    @Attribute(.unique) var id: UUID
    var name: String
    var enabled: Bool

    var typeRaw: String
    var command: String
    var arguments: String

    var workingDirectory: String

    var scheduleTypeRaw: String
    /// Human / machine schedule expression, e.g. `every 3 days`, `23:00`, cron string.
    var scheduleExpression: String

    /// KEY=VALUE lines, one per line.
    var environment: String

    var proxyEnabled: Bool
    var httpProxy: String
    var httpsProxy: String
    var socksProxy: String
    var noProxy: String

    var notificationEnabled: Bool
    var notificationCommand: String
    var notificationTriggerRaw: String
    /// When set, notification command is resolved from the shared template.
    var notificationTemplateID: UUID?

    var timeout: Int
    var retryCount: Int

    var agentProviderRaw: String
    var agentPrompt: String

    var createdAt: Date
    var updatedAt: Date

    var lastRunAt: Date?
    var lastRunStatusRaw: String?
    var lastRunDuration: Double?
    var nextRunAt: Date?

    var type: TaskType {
        get { TaskType(rawValue: typeRaw) ?? .command }
        set { typeRaw = newValue.rawValue }
    }

    var scheduleType: ScheduleType {
        get { ScheduleType(rawValue: scheduleTypeRaw) ?? .once }
        set { scheduleTypeRaw = newValue.rawValue }
    }

    var notificationTrigger: NotificationTrigger {
        get { NotificationTrigger(rawValue: notificationTriggerRaw) ?? .always }
        set { notificationTriggerRaw = newValue.rawValue }
    }

    var agentProvider: AgentProvider {
        get { AgentProvider(rawValue: agentProviderRaw) ?? .custom }
        set { agentProviderRaw = newValue.rawValue }
    }

    var lastRunStatus: RunStatus? {
        get {
            guard let lastRunStatusRaw else { return nil }
            return RunStatus(rawValue: lastRunStatusRaw)
        }
        set { lastRunStatusRaw = newValue?.rawValue }
    }

    var scheduleSummary: String {
        switch scheduleType {
        case .once:
            return scheduleExpression.isEmpty ? "Once" : "Once · \(scheduleExpression)"
        case .interval:
            return scheduleExpression.isEmpty ? "Interval" : scheduleExpression
        case .daily:
            return scheduleExpression.isEmpty ? "Daily" : "Daily · \(scheduleExpression)"
        case .weekly:
            return scheduleExpression.isEmpty ? "Weekly" : "Weekly · \(scheduleExpression)"
        case .cron:
            return scheduleExpression.isEmpty ? "Cron" : "Cron · \(scheduleExpression)"
        }
    }

    var commandPreview: String {
        let args = argumentList.joined(separator: " ")
        if args.isEmpty {
            return command
        }
        return "\(command) \(args)"
    }

    /// One argument per line (spaces inside a line are preserved).
    var argumentList: [String] {
        ArgumentParser.parse(arguments)
    }

    init(
        id: UUID = UUID(),
        name: String = "New Task",
        enabled: Bool = true,
        type: TaskType = .command,
        command: String = "",
        arguments: String = "",
        workingDirectory: String = "",
        scheduleType: ScheduleType = .once,
        scheduleExpression: String = "",
        environment: String = "",
        proxyEnabled: Bool = false,
        httpProxy: String = "",
        httpsProxy: String = "",
        socksProxy: String = "",
        noProxy: String = "localhost,127.0.0.1",
        notificationEnabled: Bool = false,
        notificationCommand: String = "",
        notificationTrigger: NotificationTrigger = .always,
        notificationTemplateID: UUID? = nil,
        timeout: Int = 300,
        retryCount: Int = 0,
        agentProvider: AgentProvider = .custom,
        agentPrompt: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastRunAt: Date? = nil,
        lastRunStatus: RunStatus? = nil,
        lastRunDuration: Double? = nil,
        nextRunAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.typeRaw = type.rawValue
        self.command = command
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.scheduleTypeRaw = scheduleType.rawValue
        self.scheduleExpression = scheduleExpression
        self.environment = environment
        self.proxyEnabled = proxyEnabled
        self.httpProxy = httpProxy
        self.httpsProxy = httpsProxy
        self.socksProxy = socksProxy
        self.noProxy = noProxy
        self.notificationEnabled = notificationEnabled
        self.notificationCommand = notificationCommand
        self.notificationTriggerRaw = notificationTrigger.rawValue
        self.notificationTemplateID = notificationTemplateID
        self.timeout = timeout
        self.retryCount = retryCount
        self.agentProviderRaw = agentProvider.rawValue
        self.agentPrompt = agentPrompt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastRunAt = lastRunAt
        self.lastRunStatusRaw = lastRunStatus?.rawValue
        self.lastRunDuration = lastRunDuration
        self.nextRunAt = nextRunAt
    }
}
