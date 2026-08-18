import AppKit
import Foundation
import UserNotifications

/// Best-effort permission preflight for task create / edit.
///
/// macOS TCC cannot grant Screen Recording / Accessibility / Automation to *child*
/// binaries (`agent`, Chromium, etc.) from Runly. We can only:
/// 1. Detect likely needs from the command line
/// 2. Prompt for permissions that apply to Runly itself
/// 3. Jump to System Settings so the user can enable the real executables
enum PermissionPreflight {
    enum Need: String, CaseIterable, Identifiable, Hashable {
        case notifications
        case screenRecording
        case accessibility
        case automation
        case fullDiskAccess
        case launchAtLogin

        var id: String { rawValue }

        var settingsURL: URL? {
            // Ventura+ Privacy & Security deep links (best-effort; fall back is ignored).
            let suffix: String
            switch self {
            case .notifications: suffix = "Privacy_Notifications"
            case .screenRecording: suffix = "Privacy_ScreenCapture"
            case .accessibility: suffix = "Privacy_Accessibility"
            case .automation: suffix = "Privacy_Automation"
            case .fullDiskAccess: suffix = "Privacy_AllFiles"
            case .launchAtLogin: suffix = "General"
            }
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(suffix)")
        }
    }

    static func detect(draft: TaskDraft) -> [Need] {
        var needs: Set<Need> = []
        let blob = [
            draft.command,
            draft.arguments,
            draft.agentPrompt,
            draft.notificationCommand,
            draft.workingDirectory
        ]
        .joined(separator: " ")
        .lowercased()

        if draft.notificationEnabled {
            needs.insert(.notifications)
        }

        let screenHints = [
            "agent-browser", "playwright", "puppeteer", "chromium", "chrome",
            "screencapture", "screenshot", "cgwindow", "page.screenshot", "全页截图", "截图"
        ]
        if screenHints.contains(where: { blob.contains($0) }) {
            needs.insert(.screenRecording)
            needs.insert(.accessibility)
        }

        let autoHints = ["osascript", "automator", "system events", "tell application", "appleevent"]
        if autoHints.contains(where: { blob.contains($0) }) {
            needs.insert(.automation)
            needs.insert(.accessibility)
        }

        let diskHints = [
            "/library/", "full disk", "tcc.db",
            "desktop/", "documents/", "downloads/", "~/desktop", "~/documents", "~/downloads"
        ]
        if diskHints.contains(where: { blob.contains($0) }) {
            needs.insert(.fullDiskAccess)
        }

        // Scheduled tasks are useless if Runly / scheduler is not around after reboot.
        if draft.enabled, draft.scheduleType != .once {
            needs.insert(.launchAtLogin)
        }

        // Agent CLIs commonly need browser + notifications for delivery skills.
        if draft.type == .agent || blob.contains("agent") || blob.contains("lark-cli") {
            needs.insert(.notifications)
        }

        if ITermRunSettings.isEnabled {
            needs.insert(.automation)
        }

        return Need.allCases.filter { needs.contains($0) }
    }

    @MainActor
    static func requestWhatWeCan(needs: [Need]) async {
        if needs.contains(.notifications) {
            await requestNotifications()
        }
    }

    static func openSettings(for need: Need) {
        if let url = need.settingsURL {
            NSWorkspace.shared.open(url)
        }
    }

    static func openPrivacyAndSecurity() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Probes (Runly.app identity only)

    private static func requestNotifications() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
}
