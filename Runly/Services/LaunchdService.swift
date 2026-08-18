import Foundation

/// Cleanup leftover LaunchAgents and leftover `--run-task` processes.
final class LaunchdService {
    @discardableResult
    func uninstallAllAgents() -> Bool {
        LaunchdCleanup.uninstallAllRunlyAgents()
        return true
    }

    func isJobRunning(taskID: UUID) -> Bool {
        HeadlessProcessProbe.isRunning(taskID: taskID)
    }

    @discardableResult
    func stopRunningJob(taskID: UUID) -> Bool {
        HeadlessProcessProbe.terminate(taskID: taskID)
    }
}
