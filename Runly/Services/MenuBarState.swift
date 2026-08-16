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
            return "No tasks"
        }
        var parts: [String] = ["\(totalTasks) task\(totalTasks == 1 ? "" : "s")"]
        if runningCount > 0 {
            parts.append("\(runningCount) running")
        } else if failedCount > 0 {
            parts.append("\(failedCount) failed")
        } else if scheduledCount > 0 {
            parts.append("\(scheduledCount) scheduled")
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
