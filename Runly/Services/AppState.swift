import Foundation
import ServiceManagement
import SwiftData
import SwiftUI

@Observable
@MainActor
final class AppState {
    let container: ModelContainer
    let session: RunSession
    let logService: LogService
    let taskService: TaskService
    let runService: RunService

    var menuBarState = MenuBarState.empty
    var editorRoute: EditorRoute?
    var pendingOpenMain = false
    var pendingFocusTaskID: UUID?
    var pendingFocusRunID: UUID?
    var dismissedFailedRunIDs: Set<UUID> = []
    var errorMessage: String?
    var launchdErrorMessage: String?

    private(set) var allTasks: [RunlyTask] = []

    init(container: ModelContainer) {
        self.container = container
        let context = ModelContext(container)
        let session = RunSession()
        let logService = LogService()
        self.session = session
        self.logService = logService
        self.taskService = TaskService(modelContext: context)
        self.runService = RunService(
            modelContext: context,
            logService: logService,
            session: session
        )
        self.runService.onStateChange = { [weak self] in
            self?.refresh()
        }
    }

    func bootstrap() {
        SystemNotificationService.shared.configure(appState: self)
        SystemNotificationService.shared.requestAuthorizationIfNeeded()
        refresh()
    }

    func refresh() {
        do {
            allTasks = try taskService.fetchAll()
            menuBarState = buildMenuBarState(tasks: allTasks)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runTask(_ task: RunlyTask) {
        Task {
            await runService.runNow(task)
            refresh()
        }
    }

    func runTask(id: UUID) {
        guard let task = allTasks.first(where: { $0.id == id }) else { return }
        runTask(task)
    }

    func stopRunning() {
        runService.stopCurrent()
        // Also try to stop a launchd-spawned headless run for the active task.
        if let taskID = session.taskID {
            _ = taskService.launchdService.stopRunningJob(taskID: taskID)
        } else if let running = menuBarState.runningTasks.first {
            _ = taskService.launchdService.stopRunningJob(taskID: running.id)
        }
        if let err = taskService.launchdService.lastError {
            // Non-fatal when the in-process stop already worked.
            launchdErrorMessage = err
        }
        refresh()
    }

    func task(id: UUID) -> RunlyTask? {
        allTasks.first { $0.id == id }
    }

    func createTask(_ draft: TaskDraft) throws -> RunlyTask {
        let task = try taskService.create(draft)
        launchdErrorMessage = taskService.launchdService.lastError
        refresh()
        return task
    }

    func updateTask(_ task: RunlyTask, with draft: TaskDraft) throws {
        try taskService.update(task, with: draft)
        launchdErrorMessage = taskService.launchdService.lastError
        refresh()
    }

    func requestNewTask() {
        editorRoute = .create
        pendingOpenMain = true
    }

    func openDashboard() {
        pendingOpenMain = true
    }

    func openTask(_ taskID: UUID) {
        pendingFocusTaskID = taskID
        pendingOpenMain = true
    }

    func openRun(taskID: UUID, runID: UUID) {
        pendingFocusTaskID = taskID
        pendingFocusRunID = runID
        pendingOpenMain = true
    }

    func dismissFailed(runID: UUID) {
        dismissedFailedRunIDs.insert(runID)
        refresh()
    }

    func deleteTask(_ task: RunlyTask) {
        do {
            try taskService.delete(task)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setEnabled(_ task: RunlyTask, enabled: Bool) {
        do {
            try taskService.setEnabled(task, enabled: enabled)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Menu Bar State

    private func buildMenuBarState(tasks: [RunlyTask]) -> MenuBarState {
        let names = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.name) })

        var running: [MenuBarRunningItem] = []
        if session.isRunning, let taskID = session.taskID {
            running.append(
                MenuBarRunningItem(
                    id: taskID,
                    name: names[taskID] ?? "Task",
                    startedAt: session.startedAt ?? .now
                )
            )
        }
        for task in tasks where task.lastRunStatus == .running {
            if running.contains(where: { $0.id == task.id }) { continue }
            running.append(
                MenuBarRunningItem(
                    id: task.id,
                    name: task.name,
                    startedAt: task.lastRunAt ?? .now
                )
            )
        }

        let recentRuns = (try? fetchRecentRuns(limit: 10)) ?? []
        let recentItems: [MenuBarRecentItem] = recentRuns.compactMap { run in
            guard run.status != .running, run.status != .queued else { return nil }
            return MenuBarRecentItem(
                id: run.id,
                taskID: run.taskID,
                taskName: names[run.taskID] ?? "Task",
                status: run.status,
                at: run.endAt ?? run.startAt,
                exitCode: run.exitCode
            )
        }

        let failedHighlights = recentItems
            .filter {
                ($0.status == .failed || $0.status == .timeout)
                    && !dismissedFailedRunIDs.contains($0.id)
            }
            .prefix(3)
            .map { $0 }

        let upcoming = tasks
            .compactMap { task -> MenuBarUpcomingItem? in
                guard task.enabled, let next = task.nextRunAt else { return nil }
                return MenuBarUpcomingItem(id: task.id, name: task.name, nextRunAt: next)
            }
            .sorted { $0.nextRunAt < $1.nextRunAt }
            .prefix(5)
            .map { $0 }

        return MenuBarState(
            totalTasks: tasks.count,
            runningCount: running.count,
            failedCount: tasks.filter {
                $0.lastRunStatus == .failed || $0.lastRunStatus == .timeout
            }.count,
            scheduledCount: tasks.filter { $0.enabled && $0.scheduleType != .once }.count,
            runningTasks: running,
            recentRuns: Array(recentItems.prefix(5)),
            upcomingTasks: Array(upcoming),
            failedHighlights: Array(failedHighlights)
        )
    }

    private func fetchRecentRuns(limit: Int) throws -> [TaskRun] {
        var descriptor = FetchDescriptor<TaskRun>(
            sortBy: [SortDescriptor(\TaskRun.startAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try runService.fetchRuns(descriptor: descriptor)
    }
}

enum LoginItemService {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
