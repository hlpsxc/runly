import Foundation

enum ScheduleType: String, Codable, CaseIterable, Identifiable {
    case once
    case interval
    case daily
    case weekly
    case cron

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .once: "Once"
        case .interval: "Interval"
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .cron: "Cron"
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
        case .always: "Always"
        case .onSuccess: "On Success"
        case .onFailure: "On Failure"
        case .onTimeout: "On Timeout"
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
        case .queued: "Queued"
        case .running: "Running"
        case .success: "Success"
        case .failed: "Failed"
        case .timeout: "Timeout"
        case .cancelled: "Cancelled"
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
        case .claude: "Claude"
        case .codex: "Codex"
        case .openclaw: "OpenClaw"
        case .custom: "Custom"
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
