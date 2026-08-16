import Foundation

struct MenuBarRunningItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let startedAt: Date
}

struct MenuBarRecentItem: Identifiable, Equatable {
    let id: UUID
    let taskID: UUID
    let taskName: String
    let status: RunStatus
    let at: Date
    let exitCode: Int?
}

struct MenuBarUpcomingItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let nextRunAt: Date
}

struct MenuBarState: Equatable {
    var totalTasks: Int = 0
    var runningCount: Int = 0
    var failedCount: Int = 0
    var scheduledCount: Int = 0

    var runningTasks: [MenuBarRunningItem] = []
    var recentRuns: [MenuBarRecentItem] = []
    var upcomingTasks: [MenuBarUpcomingItem] = []
    var failedHighlights: [MenuBarRecentItem] = []

    var summaryLine: String {
        if totalTasks == 0 {
            return L10n.tr("mb.no_tasks")
        }
        let taskKey = totalTasks == 1 ? "mb.summary_tasks" : "mb.summary_tasks_plural"
        var parts: [String] = [String(format: L10n.tr(taskKey), totalTasks)]
        if runningCount > 0 {
            parts.append(String(format: L10n.tr("mb.summary_running"), runningCount))
        } else if failedCount > 0 {
            parts.append(String(format: L10n.tr("mb.summary_failed"), failedCount))
        } else if scheduledCount > 0 {
            parts.append(String(format: L10n.tr("mb.summary_scheduled"), scheduledCount))
        }
        return parts.joined(separator: " · ")
    }

    var iconSystemName: String {
        if failedCount > 0 || !failedHighlights.isEmpty {
            return "exclamationmark.triangle.fill"
        }
        if totalTasks == 0 {
            return "bolt"
        }
        return "bolt.fill"
    }

    static let empty = MenuBarState()
}
