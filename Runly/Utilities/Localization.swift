import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case english
    case chinese

    var id: String { rawValue }

    /// Label shown in the language picker (bilingual so it’s always understandable).
    var pickerLabel: String {
        switch self {
        case .system: "System / 跟随系统"
        case .english: "English"
        case .chinese: "中文"
        }
    }

    var resolvedCode: String {
        switch self {
        case .system:
            let id = Locale.current.language.languageCode?.identifier ?? "en"
            return id.hasPrefix("zh") ? "zh-Hans" : "en"
        case .english:
            return "en"
        case .chinese:
            return "zh-Hans"
        }
    }

    var locale: Locale {
        Locale(identifier: resolvedCode)
    }
}

@Observable
@MainActor
final class LocalizationStore {
    static let shared = LocalizationStore()
    static let storageKey = "runly.appLanguage"

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    /// Bumps when language changes so views refresh.
    private(set) var revision: Int = 0

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let value = AppLanguage(rawValue: raw) {
            language = value
        } else {
            language = .system
        }
    }

    func setLanguage(_ language: AppLanguage) {
        self.language = language
        revision &+= 1
    }

    func tr(_ key: String) -> String {
        L10n.tr(key, language: language)
    }

    func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = L10n.tr(key, language: language)
        return String(format: format, locale: language.locale, arguments: args)
    }
}

enum L10n {
    /// Prefer passing `language` from `LocalizationStore` in views; defaults read UserDefaults
    /// so call sites outside `@MainActor` stay nonisolated.
    nonisolated static func tr(_ key: String, language: AppLanguage? = nil) -> String {
        let resolved = language ?? languageFromDefaults()
        let code = resolved.resolvedCode
        if let value = tables[code]?[key] {
            return value
        }
        return tables["en"]?[key] ?? key
    }

    nonisolated static var locale: Locale {
        languageFromDefaults().locale
    }

    nonisolated private static func languageFromDefaults() -> AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: LocalizationStore.storageKey),
           let value = AppLanguage(rawValue: raw) {
            return value
        }
        return .system
    }

    private static let tables: [String: [String: String]] = [
        "en": en,
        "zh-Hans": zhHans
    ]

    // MARK: - English

    private static let en: [String: String] = [
        // General
        "app.name": "Runly",
        "app.tagline": "Run anything. Automatically.",
        "ok": "OK",
        "cancel": "Cancel",
        "save": "Save",
        "edit": "Edit",
        "delete": "Delete",
        "enable": "Enable",
        "disable": "Disable",
        "enabled": "Enabled",
        "disabled": "Disabled",
        "settings": "Settings",
        "search": "Search…",
        "search_tasks": "Search tasks",
        "default": "(default)",
        "none": "(none)",
        "em_dash": "—",

        // Language
        "language": "Language",
        "language.footer": "Overrides the system language for Runly’s interface.",

        // Types
        "type.command": "Command",
        "type.script": "Script",
        "type.agent": "Agent",
        "schedule.once": "Once",
        "schedule.interval": "Interval",
        "schedule.daily": "Daily",
        "schedule.weekly": "Weekly",
        "schedule.weekdays": "Weekdays",
        "trigger.always": "Always",
        "trigger.on_success": "On Success",
        "trigger.on_failure": "On Failure",
        "trigger.on_timeout": "On Timeout",
        "status.queued": "Queued",
        "status.running": "Running",
        "status.success": "Success",
        "status.failed": "Failed",
        "status.timeout": "Timeout",
        "status.cancelled": "Cancelled",
        "status.ready": "Ready",
        "agent.claude": "Claude",
        "agent.codex": "Codex",
        "agent.openclaw": "OpenClaw",
        "agent.custom": "Custom",

        // Sidebar / filters
        "filter.all": "All Tasks",
        "filter.running": "Running",
        "filter.scheduled": "Scheduled",
        "filter.failed": "Failed",
        "filter.disabled": "Disabled",
        "library": "Library",

        // Dashboard / content
        "new_task": "New Task",
        "edit_task": "Edit Task",
        "no_tasks": "No Tasks",
        "no_tasks.desc": "Create a task to schedule commands, scripts, or AI agents.\nRun anything. Automatically.",
        "select_task": "Select a Task",
        "select_task.desc": "Choose a task from the list to inspect details.",
        "no_matching": "No Matching Tasks",
        "no_matching.desc": "Try another filter or create a new task.",
        "not_run_yet": "Not run yet",
        "something_wrong": "Something went wrong",

        // Detail
        "run_now": "Run Now",
        "stop": "Stop",
        "stop.hint": "This task is running. Press Stop to cancel it.",
        "reload_schedule": "Reload Schedule",
        "overview": "Overview",
        "section": "Section",
        "runs": "Runs",
        "logs": "Logs",
        "run": "Run",
        "exit": "Exit",
        "started": "Started",
        "next_run": "Next Run",
        "last_run": "Last Run",
        "status": "Status",
        "duration": "Duration",
        "timeout": "Timeout",
        "retry": "Retry",
        "command": "Command",
        "working_directory": "Working Directory",
        "agent_provider": "Agent Provider",
        "prompt": "Prompt",
        "schedule": "Schedule",
        "type": "Type",
        "expression": "Expression",
        "launchd_job": "launchd Job",
        "launchd.loaded": "Loaded",
        "launchd.not_loaded": "Not loaded",
        "environment": "Environment",
        "env.empty": "No custom environment variables",
        "proxy": "Proxy",
        "notifications": "Notifications",
        "yes": "Yes",
        "no": "No",
        "http": "HTTP",
        "https": "HTTPS",
        "socks": "SOCKS / ALL_PROXY",
        "no_proxy": "NO_PROXY",
        "trigger": "Trigger",
        "notification_command": "Command",
        "notification.default": "Default osascript",
        "no_runs": "No Runs Yet",
        "no_runs.desc": "Press Run Now to execute this task.",
        "live_output": "Live output",
        "waiting_output": "Waiting for output…",
        "no_logs": "No Logs",
        "no_logs.desc": "Run the task to capture stdout and stderr.",
        "exit_code_fmt": "exit %d",
        "logs.disk_hint": "Also on disk: .out.log / .err.log beside the combined log.",

        // Notification templates
        "notif_template.section": "Notification Templates",
        "notif_template.footer": "Shared across tasks. Editing a template updates every task that uses it.",
        "notif_template.empty": "No templates yet. Add one to reuse Feishu / webhook / custom commands.",
        "notif_template.add": "Add Template",
        "notif_template.edit": "Edit Template",
        "notif_template.untitled": "Untitled Template",
        "notif_template.picker": "Template",
        "notif_template.source.system": "System notification",
        "notif_template.source.custom": "Custom command",
        "notif_template.source.system_hint": "Uses the built-in macOS notification.",
        "notif_template.source.template_hint": "Managed in Settings · changes apply to all tasks using this template.",
        "notif_template.missing": "Template missing — pick another or use Custom.",
        "notif_template.command_hint": "Leave command empty to send the built-in macOS notification.",

        // Editor
        "basics": "Basics",
        "name": "Name",
        "paste_cli": "Paste Command Line",
        "paste_cli.placeholder": "Paste full CLI here (supports \\ line breaks & quotes)",
        "parse": "Parse",
        "paste_cli.example": "Example: agent -p --force --output-format text \\\n  \"…\"",
        "parse.failed": "Could not parse command line",
        "parse.ok": "Parsed → %@ + %d arg(s)",
        "parse.unbalanced_single": "Unclosed single quote (')",
        "parse.unbalanced_double": "Unclosed double quote (\")",
        "parse.trailing_escape": "Line ends with an unfinished backslash escape",
        "parse.no_executable": "No executable found in the pasted command",
        "validate.name_empty": "Task name is empty — will save as “Untitled Task”.",
        "validate.command_empty": "Command / executable is required.",
        "validate.command_not_found": "“%@” was not found on PATH (may still work at runtime).",
        "validate.script_missing": "Script path not found: %@",
        "validate.agent_prompt_empty": "Agent prompt / arguments are empty.",
        "validate.unbalanced_single": "Arguments: unclosed single quote (').",
        "validate.unbalanced_double": "Arguments: unclosed double quote (\").",
        "validate.env_line": "Environment line must be KEY=VALUE: %@",
        "validate.env_key_empty": "Environment variable name is empty.",
        "validate.cwd_missing": "Working directory does not exist: %@",
        "validate.schedule_empty": "Schedule expression is empty.",
        "validate.schedule_once_invalid": "Use a date and time to the minute, e.g. 2026-08-20 09:30.",
        "validate.schedule_once_past": "This one-shot time is in the past — it will not run until you pick a future time.",
        "validate.schedule_daily_invalid": "Daily time must be HH:mm (to the minute), e.g. 23:05.",
        "validate.schedule_weekly_invalid": "Weekly format: Mon 09:30 (weekday + time to the minute).",
        "validate.schedule_interval_invalid": "Interval examples: Every 5 minutes · Every 3 hours · Every 2 days.",
        "validate.timeout_negative": "Timeout cannot be negative.",
        "validate.retry_negative": "Retry count cannot be negative.",
        "validate.proxy_empty": "Proxy is enabled but no proxy URL is set.",
        "validate.fix_title": "Please fix the highlighted issues",
        "validate.has_input": "Using your input below.",
        "provider": "Provider",
        "executable": "Executable",
        "extra_args": "Extra Arguments (one per line, optional)",
        "templates.hint": "Templates: {{date}} {{time}} {{task_name}} {{working_directory}} {{prompt}}",
        "script_path": "Script Path",
        "arguments": "Arguments (one per line)",
        "script.hint": "Runs the file directly if executable; otherwise picks python3/node/zsh/… from the extension.",
        "command.hint": "Supports items, claude, python3, … — resolved via PATH (+ Homebrew).",
        "schedule.datetime": "Date & Time",
        "schedule.time": "Time",
        "schedule.weekday": "Weekday",
        "schedule.hint": "Once: pick a date & time · Interval: Every 5 minutes · Daily / Weekly / Weekdays: time to the minute",
        "schedule.hint.once": "Pick a specific date and time (minute precision).",
        "schedule.hint.interval": "Examples: Every 5 minutes · Every 3 hours · Every 2 days",
        "schedule.hint.daily": "Runs every day at this time (minute precision).",
        "schedule.hint.weekly": "Runs once a week on the selected day and time.",
        "schedule.hint.weekdays": "Runs Monday–Friday at this time (Beijing).",
        "schedule.timezone_hint": "All schedule times use Beijing time (UTC+8).",
        "env.placeholder": "KEY=VALUE per line",
        "notification.cmd_placeholder": "Command (empty = macOS notification)",
        "notification.vars": "Vars: {{task_name}} {{status}} {{exit_code}} {{duration}} {{stdout}}",
        "limits": "Limits",
        "timeout_seconds": "Timeout (seconds)",
        "retry_count": "Retry Count",
        "command_preview": "Command Preview",
        "path_tail": "PATH (tail)",
        "test_run": "Test Run",
        "testing": "Testing…",
        "could_not_save": "Could not save",
        "test.cannot_resolve": "Cannot resolve command. Check executable / script path.",
        "test.running": "Running test…\n$ %@\n",

        // Menu bar
        "mb.running_section": "RUNNING",
        "mb.recent_section": "RECENT",
        "mb.up_next_section": "UP NEXT",
        "mb.failed_section": "FAILED",
        "mb.stop": "Stop",
        "mb.view_logs": "View Logs",
        "mb.run_again": "Run Again",
        "mb.dismiss": "Dismiss",
        "mb.exit_code": "Exit Code: %d",
        "mb.running_elapsed": "Running · %@",
        "mb.view_all": "View All Tasks →",
        "mb.empty_title": "No scheduled agents yet",
        "mb.empty_desc": "Create a task to run commands or AI agents from the menu bar.",
        "mb.run_task": "Run Task",
        "mb.open_runly": "Open Runly",
        "mb.quit": "Quit Runly",
        "mb.no_tasks": "No tasks",
        "mb.summary_tasks": "%d task",
        "mb.summary_tasks_plural": "%d tasks",
        "mb.summary_running": "%d running",
        "mb.summary_failed": "%d failed",
        "mb.summary_scheduled": "%d scheduled",
        "mb.today": "Today · %@",
        "mb.tomorrow": "Tomorrow · %@",

        // Settings
        "settings.general": "General",
        "settings.launch_at_login": "Launch Runly at login",
        "settings.launch_at_login.footer": "Needed for schedules after reboot — Runly must stay running.",
        "settings.due_watch_interval": "Check due tasks every %d seconds",
        "settings.due_watch_interval.footer": "The app process looks for due tasks on this interval. Default 20 seconds.",
        "settings.merge_shell_env": "Merge login shell environment",
        "settings.merge_shell_env.footer": "Load exports from ~/.zshrc (and profile) so API keys work for menu bar and scheduled runs. Task Environment still overrides.",
        "settings.run_in_iterm": "Run tasks in iTerm",
        "settings.run_in_iterm.footer": "Opens an iTerm window so agent / browser inherit iTerm’s Screen Recording and Accessibility grants. First run asks to allow Runly to control iTerm. Notification commands still run in the background.",
        "settings.run_in_iterm.missing": "Install iTerm2 to run tasks with iTerm’s permissions. Until then, commands spawn as Runly child processes.",
        "settings.about": "About",
        "settings.mode": "Mode",
        "settings.mode.value": "Menu Bar First",
        "settings.tasks": "Tasks",
        "settings.last_launched": "Last launched",
        "settings.paths": "Paths",
        "settings.support": "Support",
        "settings.logs": "Logs",

        // Notifications
        "notify.finished": "Task {{task_name}} finished: {{status}}",
        "notify.success_body": "Task completed successfully.\nDuration: %@",
        "notify.failed_body": "Task failed.\nExit Code: %@",
        "notify.timeout_body": "Task timed out.",
        "notify.cancelled_body": "Task cancelled.",

        // Permission preflight
        "perm.title": "Permissions Before First Run",
        "perm.intro": "macOS grants privacy permissions to the process that asks — usually agent / the browser, not Runly. Grant them now while you are at the Mac; headless schedules cannot click dialogs.",
        "perm.limit": "With “Run tasks in iTerm” on, screenshot tools usually inherit iTerm’s grants. Runly still only prompts for notifications, plus Automation to control iTerm.",
        "perm.request_runly": "Prompt Notifications",
        "perm.open_all": "Open Privacy Settings",
        "perm.open_one": "Open",
        "perm.continue_save": "Save Task",
        "perm.skip": "Not Now",
        "perm.need.notifications": "Notifications",
        "perm.need.notifications.hint": "Status alerts when a run finishes.",
        "perm.need.screenRecording": "Screen Recording",
        "perm.need.screenRecording.hint": "Needed by the child tool that takes screenshots (browser / agent-browser), not by Runly. Enable that binary in System Settings.",
        "perm.need.accessibility": "Accessibility",
        "perm.need.accessibility.hint": "Browser automation and UI control.",
        "perm.need.automation": "Automation",
        "perm.need.automation.hint": "Allow Runly to control iTerm (and any AppleScript your task runs).",
        "perm.need.fullDiskAccess": "Full Disk Access",
        "perm.need.fullDiskAccess.hint": "Reading protected paths (Desktop / Documents / system files).",
        "perm.need.launchAtLogin": "Open at Login",
        "perm.need.launchAtLogin.hint": "Keeps Runly running after reboot so the in-app scheduler can fire."
    ]

    // MARK: - Chinese

    private static let zhHans: [String: String] = [
        "app.name": "Runly",
        "app.tagline": "任何命令，自动运行。",
        "ok": "好",
        "cancel": "取消",
        "save": "保存",
        "edit": "编辑",
        "delete": "删除",
        "enable": "启用",
        "disable": "禁用",
        "enabled": "已启用",
        "disabled": "已禁用",
        "settings": "设置",
        "search": "搜索…",
        "search_tasks": "搜索任务",
        "default": "（默认）",
        "none": "（无）",
        "em_dash": "—",

        "language": "语言",
        "language.footer": "覆盖系统语言，仅影响 Runly 界面。",

        "type.command": "命令",
        "type.script": "脚本",
        "type.agent": "Agent",
        "schedule.once": "一次性",
        "schedule.interval": "间隔",
        "schedule.daily": "每天",
        "schedule.weekly": "每周",
        "schedule.weekdays": "工作日",
        "trigger.always": "总是",
        "trigger.on_success": "成功时",
        "trigger.on_failure": "失败时",
        "trigger.on_timeout": "超时时",
        "status.queued": "排队中",
        "status.running": "运行中",
        "status.success": "成功",
        "status.failed": "失败",
        "status.timeout": "超时",
        "status.cancelled": "已取消",
        "status.ready": "就绪",
        "agent.claude": "Claude",
        "agent.codex": "Codex",
        "agent.openclaw": "OpenClaw",
        "agent.custom": "自定义",

        "filter.all": "全部任务",
        "filter.running": "运行中",
        "filter.scheduled": "已计划",
        "filter.failed": "失败",
        "filter.disabled": "已禁用",
        "library": "资源库",

        "new_task": "新建任务",
        "edit_task": "编辑任务",
        "no_tasks": "暂无任务",
        "no_tasks.desc": "创建任务以调度命令、脚本或 AI Agent。\n任何命令，自动运行。",
        "select_task": "选择任务",
        "select_task.desc": "从列表中选择任务以查看详情。",
        "no_matching": "无匹配任务",
        "no_matching.desc": "试试其他筛选，或新建一个任务。",
        "not_run_yet": "尚未运行",
        "something_wrong": "出错了",

        "run_now": "立即运行",
        "stop": "停止",
        "stop.hint": "任务正在运行，可点击停止取消。",
        "reload_schedule": "重新加载日程",
        "overview": "概览",
        "section": "分区",
        "runs": "运行记录",
        "logs": "日志",
        "run": "运行",
        "exit": "退出码",
        "started": "开始时间",
        "next_run": "下次运行",
        "last_run": "上次运行",
        "status": "状态",
        "duration": "耗时",
        "timeout": "超时",
        "retry": "重试",
        "command": "命令",
        "working_directory": "工作目录",
        "agent_provider": "Agent 提供方",
        "prompt": "提示词",
        "schedule": "日程",
        "type": "类型",
        "expression": "表达式",
        "launchd_job": "launchd 任务",
        "launchd.loaded": "已加载",
        "launchd.not_loaded": "未加载",
        "environment": "环境变量",
        "env.empty": "未设置自定义环境变量",
        "proxy": "代理",
        "notifications": "通知",
        "yes": "是",
        "no": "否",
        "http": "HTTP",
        "https": "HTTPS",
        "socks": "SOCKS / ALL_PROXY",
        "no_proxy": "NO_PROXY",
        "trigger": "触发条件",
        "notification_command": "命令",
        "notification.default": "默认系统通知",
        "no_runs": "尚无运行记录",
        "no_runs.desc": "点击「立即运行」执行此任务。",
        "live_output": "实时输出",
        "waiting_output": "等待输出…",
        "no_logs": "暂无日志",
        "no_logs.desc": "运行任务后可查看 stdout / stderr。",
        "exit_code_fmt": "退出码 %d",
        "logs.disk_hint": "磁盘上还有同目录的 .out.log / .err.log。",

        // Notification templates
        "notif_template.section": "通知模板",
        "notif_template.footer": "可在多个任务间复用。修改模板后，引用它的任务会同步生效。",
        "notif_template.empty": "还没有模板。可添加飞书 / Webhook / 自定义命令以便复用。",
        "notif_template.add": "添加模板",
        "notif_template.edit": "编辑模板",
        "notif_template.untitled": "未命名模板",
        "notif_template.picker": "模板",
        "notif_template.source.system": "系统通知",
        "notif_template.source.custom": "自定义命令",
        "notif_template.source.system_hint": "使用内置 macOS 通知。",
        "notif_template.source.template_hint": "在设置中管理；修改后对所有引用该模板的任务生效。",
        "notif_template.missing": "模板已不存在，请另选或改用自定义。",
        "notif_template.command_hint": "命令留空则发送内置 macOS 通知。",

        "basics": "基本信息",
        "name": "名称",
        "paste_cli": "粘贴命令行",
        "paste_cli.placeholder": "在此粘贴完整 CLI（支持 \\ 换行与引号）",
        "parse": "解析",
        "paste_cli.example": "示例：agent -p --force --output-format text \\\n  \"…\"",
        "parse.failed": "无法解析命令行",
        "parse.ok": "已解析 → %@ + %d 个参数",
        "parse.unbalanced_single": "单引号未闭合 (')",
        "parse.unbalanced_double": "双引号未闭合 (\")",
        "parse.trailing_escape": "行末反斜杠转义不完整",
        "parse.no_executable": "粘贴内容中未找到可执行命令",
        "validate.name_empty": "任务名称为空 — 将保存为「未命名任务」。",
        "validate.command_empty": "必须填写命令 / 可执行文件。",
        "validate.command_not_found": "PATH 中未找到 “%@”（运行时仍可能可用）。",
        "validate.script_missing": "脚本路径不存在：%@",
        "validate.agent_prompt_empty": "Agent 提示词 / 参数为空。",
        "validate.unbalanced_single": "参数中有未闭合的单引号 (')。",
        "validate.unbalanced_double": "参数中有未闭合的双引号 (\")。",
        "validate.env_line": "环境变量须为 KEY=VALUE：%@",
        "validate.env_key_empty": "环境变量名为空。",
        "validate.cwd_missing": "工作目录不存在：%@",
        "validate.schedule_empty": "日程表达式为空。",
        "validate.schedule_once_invalid": "请填写精确到分钟的日期时间，例如 2026-08-20 09:30。",
        "validate.schedule_once_past": "该一次性时间已过期 — 请选择未来的时间才会运行。",
        "validate.schedule_daily_invalid": "每天时间须为 HH:mm（精确到分钟），例如 23:05。",
        "validate.schedule_weekly_invalid": "每周格式：Mon 09:30（星期 + 精确到分钟的时间）。",
        "validate.schedule_interval_invalid": "间隔示例：Every 5 minutes · Every 3 hours · Every 2 days。",
        "validate.timeout_negative": "超时时间不能为负数。",
        "validate.retry_negative": "重试次数不能为负数。",
        "validate.proxy_empty": "已启用代理但未填写代理地址。",
        "validate.fix_title": "请先修正标出的问题",
        "validate.has_input": "已使用下方输入内容。",
        "provider": "提供方",
        "executable": "可执行文件",
        "extra_args": "额外参数（每行一个，可选）",
        "templates.hint": "模板：{{date}} {{time}} {{task_name}} {{working_directory}} {{prompt}}",
        "script_path": "脚本路径",
        "arguments": "参数（每行一个）",
        "script.hint": "若脚本可执行则直接运行；否则按扩展名选择 python3/node/zsh…",
        "command.hint": "支持 items、claude、python3 等，通过 PATH（含 Homebrew）解析。",
        "schedule.datetime": "日期与时间",
        "schedule.time": "时间",
        "schedule.weekday": "星期",
        "schedule.hint": "一次性：选择日期与时间 · 间隔：Every 5 minutes · 每天/每周/工作日：精确到分钟",
        "schedule.hint.once": "选择具体的日期与时间（精确到分钟）。",
        "schedule.hint.interval": "示例：Every 5 minutes · Every 3 hours · Every 2 days",
        "schedule.hint.daily": "每天在该时刻运行（精确到分钟）。",
        "schedule.hint.weekly": "每周在选定的星期与时间运行。",
        "schedule.hint.weekdays": "周一至周五在该时刻运行（北京时间）。",
        "schedule.timezone_hint": "所有定时时间均为北京时间（UTC+8）。",
        "env.placeholder": "每行一个 KEY=VALUE",
        "notification.cmd_placeholder": "命令（留空 = 系统通知）",
        "notification.vars": "变量：{{task_name}} {{status}} {{exit_code}} {{duration}} {{stdout}}",
        "limits": "限制",
        "timeout_seconds": "超时（秒）",
        "retry_count": "重试次数",
        "command_preview": "命令预览",
        "path_tail": "PATH（末尾）",
        "test_run": "试运行",
        "testing": "测试中…",
        "could_not_save": "无法保存",
        "test.cannot_resolve": "无法解析命令，请检查可执行文件 / 脚本路径。",
        "test.running": "正在试运行…\n$ %@\n",

        "mb.running_section": "运行中",
        "mb.recent_section": "最近",
        "mb.up_next_section": "即将执行",
        "mb.failed_section": "失败",
        "mb.stop": "停止",
        "mb.view_logs": "查看日志",
        "mb.run_again": "再次运行",
        "mb.dismiss": "忽略",
        "mb.exit_code": "退出码：%d",
        "mb.running_elapsed": "运行中 · %@",
        "mb.view_all": "查看全部任务 →",
        "mb.empty_title": "还没有计划任务",
        "mb.empty_desc": "从菜单栏创建任务，运行命令或 AI Agent。",
        "mb.run_task": "运行任务",
        "mb.open_runly": "打开 Runly",
        "mb.quit": "退出 Runly",
        "mb.no_tasks": "暂无任务",
        "mb.summary_tasks": "%d 个任务",
        "mb.summary_tasks_plural": "%d 个任务",
        "mb.summary_running": "%d 个运行中",
        "mb.summary_failed": "%d 个失败",
        "mb.summary_scheduled": "%d 个已计划",
        "mb.today": "今天 · %@",
        "mb.tomorrow": "明天 · %@",

        "settings.general": "通用",
        "settings.launch_at_login": "登录时启动 Runly",
        "settings.launch_at_login.footer": "定时任务需要 Runly 保持运行；重启后请打开「登录时启动」。",
        "settings.due_watch_interval": "每 %d 秒检查到期任务",
        "settings.due_watch_interval.footer": "由 Runly 进程自己轮询到期任务。默认 20 秒。",
        "settings.merge_shell_env": "合并登录 Shell 环境变量",
        "settings.merge_shell_env.footer": "加载 ~/.zshrc（及 profile）中的 export，使菜单栏与定时任务也能用到 API Key。任务内 Environment 仍优先。",
        "settings.run_in_iterm": "在 iTerm 中执行任务",
        "settings.run_in_iterm.footer": "打开 iTerm 窗口运行，让 agent / 浏览器沿用 iTerm 已授权的屏幕录制和辅助功能。首次会请求允许 Runly 控制 iTerm。通知命令仍在后台执行。",
        "settings.run_in_iterm.missing": "未检测到 iTerm2。安装后即可用 iTerm 的权限跑任务；此前仍由 Runly 直接拉起子进程。",
        "settings.about": "关于",
        "settings.mode": "模式",
        "settings.mode.value": "菜单栏优先",
        "settings.tasks": "任务",
        "settings.last_launched": "最近启动",
        "settings.paths": "路径",
        "settings.support": "支持目录",
        "settings.logs": "日志",

        "notify.finished": "任务 {{task_name}} 已结束：{{status}}",
        "notify.success_body": "任务执行成功。\n耗时：%@",
        "notify.failed_body": "任务失败。\n退出码：%@",
        "notify.timeout_body": "任务超时。",
        "notify.cancelled_body": "任务已取消。",

        "perm.title": "首次运行前的权限",
        "perm.intro": "macOS 隐私权限会授给真正发起请求的进程（通常是 agent / 浏览器），而不是 Runly。请趁人在电脑前先开好；定时 headless 启动时点不了弹窗。",
        "perm.limit": "若开启「在 iTerm 中执行任务」，截图工具通常会沿用 iTerm 的授权。Runly 仍只申请通知，外加控制 iTerm 的自动化权限。",
        "perm.request_runly": "申请通知权限",
        "perm.open_all": "打开隐私设置",
        "perm.open_one": "打开",
        "perm.continue_save": "保存任务",
        "perm.skip": "先不处理",
        "perm.need.notifications": "通知",
        "perm.need.notifications.hint": "运行结束时的状态提醒。",
        "perm.need.screenRecording": "屏幕录制",
        "perm.need.screenRecording.hint": "截图是子进程（浏览器 / agent-browser）的事，Runly 不需要。请在系统设置里勾选那个二进制。",
        "perm.need.accessibility": "辅助功能",
        "perm.need.accessibility.hint": "浏览器自动化与 UI 控制。",
        "perm.need.automation": "自动化",
        "perm.need.automation.hint": "允许 Runly 控制 iTerm（以及任务里的 AppleScript）。",
        "perm.need.fullDiskAccess": "完全磁盘访问",
        "perm.need.fullDiskAccess.hint": "读取受保护路径（桌面 / 文稿 / 系统文件）。",
        "perm.need.launchAtLogin": "登录时打开",
        "perm.need.launchAtLogin.hint": "重启后保持 Runly 运行，进程内调度才能触发（设置 → 登录时打开）。"
    ]
}

/// Convenience for SwiftUI views observing LocalizationStore.
struct LocalizedText: View {
    @Environment(LocalizationStore.self) private var localization
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        let _ = localization.revision
        Text(localization.tr(key))
    }
}
