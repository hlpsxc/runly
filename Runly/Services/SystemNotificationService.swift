import AppKit
import Foundation
import UserNotifications

@MainActor
final class SystemNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = SystemNotificationService()

    private weak var appState: AppState?

    func configure(appState: AppState) {
        self.appState = appState
        let center = UNUserNotificationCenter.current()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func postRunFinished(task: RunlyTask, run: TaskRun, status: RunStatus) async {
        let content = UNMutableNotificationContent()
        content.title = "Runly"
        content.subtitle = task.name

        switch status {
        case .success:
            let duration = run.duration.map { String(format: "%.0fs", $0) } ?? L10n.tr("em_dash")
            content.body = String(format: L10n.tr("notify.success_body"), duration)
        case .failed:
            let code = run.exitCode.map(String.init) ?? "?"
            content.body = String(format: L10n.tr("notify.failed_body"), code)
        case .timeout:
            content.body = L10n.tr("notify.timeout_body")
        case .cancelled:
            content.body = L10n.tr("notify.cancelled_body")
        case .running, .queued:
            return
        }

        content.sound = .default
        content.userInfo = [
            "taskID": task.id.uuidString,
            "runID": run.id.uuidString
        ]

        let request = UNNotificationRequest(
            identifier: "runly.run.\(run.id.uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let taskID = (info["taskID"] as? String).flatMap(UUID.init(uuidString:))
        let runID = (info["runID"] as? String).flatMap(UUID.init(uuidString:))

        Task { @MainActor in
            if let taskID, let runID {
                appState?.openRun(taskID: taskID, runID: runID)
            } else if let taskID {
                appState?.openTask(taskID)
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
