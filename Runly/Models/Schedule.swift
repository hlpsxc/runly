import Foundation

enum ScheduleType: String, Codable, CaseIterable, Identifiable {
    case once
    case interval
    case daily
    case weekly
    case weekdays

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .once: L10n.tr("schedule.once")
        case .interval: L10n.tr("schedule.interval")
        case .daily: L10n.tr("schedule.daily")
        case .weekly: L10n.tr("schedule.weekly")
        case .weekdays: L10n.tr("schedule.weekdays")
        }
    }
}

enum NotificationTrigger: String, Codable, CaseIterable, Identifiable {
    case always
    case onSuccess
    case onFailure
    case onTimeout

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .always: L10n.tr("trigger.always")
        case .onSuccess: L10n.tr("trigger.on_success")
        case .onFailure: L10n.tr("trigger.on_failure")
        case .onTimeout: L10n.tr("trigger.on_timeout")
        }
    }
}

enum RunStatus: String, Codable, CaseIterable, Identifiable {
    case queued
    case running
    case success
    case failed
    case timeout
    case cancelled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .queued: L10n.tr("status.queued")
        case .running: L10n.tr("status.running")
        case .success: L10n.tr("status.success")
        case .failed: L10n.tr("status.failed")
        case .timeout: L10n.tr("status.timeout")
        case .cancelled: L10n.tr("status.cancelled")
        }
    }

    var systemImage: String {
        switch self {
        case .queued: "circle.dotted"
        case .running: "circle.fill"
        case .success: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .timeout: "clock.badge.exclamationmark"
        case .cancelled: "stop.circle.fill"
        }
    }
}

enum AgentProvider: String, Codable, CaseIterable, Identifiable {
    case claude
    case codex
    case openclaw
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: L10n.tr("agent.claude")
        case .codex: L10n.tr("agent.codex")
        case .openclaw: L10n.tr("agent.openclaw")
        case .custom: L10n.tr("agent.custom")
        }
    }

    var defaultExecutable: String {
        switch self {
        case .claude: "claude"
        case .codex: "codex"
        case .openclaw: "openclaw"
        case .custom: ""
        }
    }
}
