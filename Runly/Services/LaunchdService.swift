import Foundation

/// Thin façade used by TaskService / AppState.
final class LaunchdService {
    private let manager = LaunchdManager()
    private(set) var lastError: String?

    @discardableResult
    func sync(task: RunlyTask) -> Bool {
        do {
            try manager.sync(task: task)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            NSLog("Runly launchd sync failed: %@", error.localizedDescription)
            return false
        }
    }

    func remove(taskID: UUID) {
        do {
            try manager.uninstall(taskID: taskID)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func reload(task: RunlyTask) -> Bool {
        do {
            try manager.reload(task: task)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            NSLog("Runly launchd reload failed: %@", error.localizedDescription)
            return false
        }
    }

    func isLoaded(taskID: UUID) -> Bool {
        manager.isLoaded(taskID: taskID)
    }

    func isJobRunning(taskID: UUID) -> Bool {
        manager.isJobRunning(taskID: taskID)
    }

    @discardableResult
    func stopRunningJob(taskID: UUID) -> Bool {
        do {
            try manager.stopRunningJob(taskID: taskID)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
