import Foundation
import SwiftData
import SwiftUI

enum SidebarFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case running
    case scheduled
    case failed
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Tasks"
        case .running: "Running"
        case .scheduled: "Scheduled"
        case .failed: "Failed"
        case .disabled: "Disabled"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.stack.3d.up"
        case .running: "circle.fill"
        case .scheduled: "calendar"
        case .failed: "xmark.circle"
        case .disabled: "pause.circle"
        }
    }

    func matches(_ task: RunlyTask) -> Bool {
        switch self {
        case .all:
            return true
        case .running:
            return task.lastRunStatus == .running
        case .scheduled:
            return task.enabled && task.scheduleType != .once
        case .failed:
            return task.lastRunStatus == .failed || task.lastRunStatus == .timeout
        case .disabled:
            return !task.enabled
        }
    }
}

@Observable
@MainActor
final class DashboardViewModel {
    private(set) var tasks: [RunlyTask] = []
    var filter: SidebarFilter = .all
    var selectedTaskID: UUID?
    var searchText: String = ""
    var errorMessage: String?

    private weak var appState: AppState?

    var filteredTasks: [RunlyTask] {
        tasks.filter { task in
            filter.matches(task) && matchesSearch(task)
        }
    }

    var selectedTask: RunlyTask? {
        guard let selectedTaskID else { return nil }
        return tasks.first { $0.id == selectedTaskID }
    }

    func bind(appState: AppState) {
        self.appState = appState
        refresh()
    }

    func refresh() {
        guard let appState else { return }
        appState.refresh()
        tasks = appState.allTasks
        if let selectedTaskID, !tasks.contains(where: { $0.id == selectedTaskID }) {
            self.selectedTaskID = filteredTasks.first?.id
        }
        errorMessage = appState.errorMessage
    }

    func select(_ task: RunlyTask?) {
        selectedTaskID = task?.id
    }

    func delete(_ task: RunlyTask) {
        appState?.deleteTask(task)
        if selectedTaskID == task.id {
            selectedTaskID = nil
        }
        refresh()
    }

    func toggleEnabled(_ task: RunlyTask) {
        appState?.setEnabled(task, enabled: !task.enabled)
        refresh()
    }

    func runNow(_ task: RunlyTask) {
        appState?.runTask(task)
    }

    func count(for filter: SidebarFilter) -> Int {
        tasks.filter { filter.matches($0) }.count
    }

    private func matchesSearch(_ task: RunlyTask) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return task.name.localizedCaseInsensitiveContains(query)
            || task.command.localizedCaseInsensitiveContains(query)
            || task.scheduleSummary.localizedCaseInsensitiveContains(query)
    }
}
