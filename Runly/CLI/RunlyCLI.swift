import AppKit
import Foundation
import SwiftData

/// Headless JSON/text CLI for agents (Cursor / Codex) and scripts.
enum RunlyCLI {
    @MainActor
    static func run(arguments: [String]) {
        let args = Array(arguments.dropFirst()) // drop executable
        let parsed: Parsed
        do {
            parsed = try Parser.parse(args)
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            fputs(Parser.usage, stderr)
            exit(2)
        }

        if case .help = parsed.command {
            fputs(Parser.usage, stdout)
            exit(0)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        Task { @MainActor in
            var code: Int32 = 0
            do {
                let container = try RunlyStore.makeContainer()
                let context = ModelContext(container)
                let session = RunSession()
                let logs = LogService()
                let tasks = TaskService(modelContext: context)
                let runs = RunService(modelContext: context, logService: logs, session: session)
                LaunchdService().uninstallAllAgents()
                let hub = CLIHub(
                    context: context,
                    taskService: tasks,
                    runService: runs,
                    json: parsed.json
                )
                try await hub.execute(parsed.command)
            } catch let err as CLIError {
                emitError(err.localizedDescription, json: parsed.json)
                code = err.exitCode
            } catch {
                emitError(error.localizedDescription, json: parsed.json)
                code = 1
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
            exit(code)
        }

        dispatchMain()
    }

    private static func emitError(_ message: String, json: Bool) {
        if json {
            let payload: [String: Any] = ["ok": false, "error": message]
            if let data = try? JSONSerialization.data(withJSONObject: payload),
               let text = String(data: data, encoding: .utf8) {
                fputs(text + "\n", stderr)
            }
        } else {
            fputs("error: \(message)\n", stderr)
        }
    }
}

enum CLIError: LocalizedError {
    case usage(String)
    case notFound(String)
    case invalid(String)
    case failed(String)

    var exitCode: Int32 {
        switch self {
        case .usage: 2
        case .notFound: 3
        case .invalid: 2
        case .failed: 1
        }
    }

    var errorDescription: String? {
        switch self {
        case .usage(let m), .notFound(let m), .invalid(let m), .failed(let m): m
        }
    }
}

private struct Parsed {
    var command: CLICommand
    var json: Bool
}

private enum CLICommand {
    case help
    case list
    case get(String)
    case create(CreateOptions)
    case run(String)
    case stop(String)
    case enable(String)
    case disable(String)
    case delete(String)
    case status
}

private struct CreateOptions {
    var name: String
    var type: TaskType
    var command: String
    var arguments: String
    var workingDirectory: String
    var scheduleType: ScheduleType
    var scheduleExpression: String
    var enabled: Bool
    var timeout: Int
    var agentProvider: AgentProvider
    var agentPrompt: String
}

private enum Parser {
    static let usage = """
    Runly CLI — manage tasks from Cursor / Codex / scripts

    Usage:
      Runly --cli <command> [options]

    Commands:
      help
      list [--json]
      get <id|name> [--json]
      create --name <name> --command <exe> [options] [--json]
      run <id|name> [--json]
      stop <id|name> [--json]
      enable <id|name> [--json]
      disable <id|name> [--json]
      delete <id|name> [--json]
      status [--json]

    Create options:
      --type command|script|agent          (default: command)
      --arg <value>                        (repeatable; one argv line each)
      --arguments <text>                   (newline-separated argv; \\n allowed)
      --cwd <path>
      --schedule-type once|interval|daily|weekly|weekdays
      --schedule <expression>              (default: Every day)
      --enabled / --disabled               (default: enabled)
      --timeout <seconds>                  (default: 300)
      --provider claude|codex|openclaw|custom
      --prompt <text>                      (agent)

    Examples:
      Runly --cli list --json
      Runly --cli create --name Hello --command echo --arg "hi" --json
      Runly --cli run Hello --json
      Runly --cli stop Hello --json

    """

    static func parse(_ args: [String]) throws -> Parsed {
        var rest = args
        // Accept `Runly --cli …` or `Runly cli …`
        if rest.first == "--cli" || rest.first == "cli" {
            rest.removeFirst()
        }
        var json = false
        rest = rest.filter { token in
            if token == "--json" {
                json = true
                return false
            }
            return true
        }

        guard let head = rest.first else {
            return Parsed(command: .help, json: json)
        }
        rest.removeFirst()

        switch head {
        case "help", "-h", "--help":
            return Parsed(command: .help, json: json)
        case "list":
            return Parsed(command: .list, json: json)
        case "status":
            return Parsed(command: .status, json: json)
        case "get":
            guard let id = rest.first else { throw CLIError.usage("get requires <id|name>") }
            return Parsed(command: .get(id), json: json)
        case "run":
            guard let id = rest.first else { throw CLIError.usage("run requires <id|name>") }
            return Parsed(command: .run(id), json: json)
        case "stop":
            guard let id = rest.first else { throw CLIError.usage("stop requires <id|name>") }
            return Parsed(command: .stop(id), json: json)
        case "enable":
            guard let id = rest.first else { throw CLIError.usage("enable requires <id|name>") }
            return Parsed(command: .enable(id), json: json)
        case "disable":
            guard let id = rest.first else { throw CLIError.usage("disable requires <id|name>") }
            return Parsed(command: .disable(id), json: json)
        case "delete":
            guard let id = rest.first else { throw CLIError.usage("delete requires <id|name>") }
            return Parsed(command: .delete(id), json: json)
        case "create":
            return Parsed(command: .create(try parseCreate(rest)), json: json)
        default:
            throw CLIError.usage("unknown command: \(head)")
        }
    }

    private static func parseCreate(_ args: [String]) throws -> CreateOptions {
        var name = ""
        var type: TaskType = .command
        var command = ""
        var argLines: [String] = []
        var argumentsBlob: String?
        var cwd = ""
        var scheduleType: ScheduleType = .interval
        var schedule = "Every day"
        var enabled = true
        var timeout = 300
        var provider: AgentProvider = .custom
        var prompt = ""

        var i = 0
        while i < args.count {
            let token = args[i]
            func needValue() throws -> String {
                i += 1
                guard i < args.count else { throw CLIError.usage("\(token) needs a value") }
                return args[i]
            }
            switch token {
            case "--name": name = try needValue()
            case "--type":
                let raw = try needValue()
                guard let value = TaskType(rawValue: raw) else {
                    throw CLIError.invalid("unknown type: \(raw)")
                }
                type = value
            case "--command", "--executable": command = try needValue()
            case "--arg": argLines.append(try needValue())
            case "--arguments":
                argumentsBlob = try needValue().replacingOccurrences(of: "\\n", with: "\n")
            case "--cwd", "--working-directory": cwd = try needValue()
            case "--schedule-type":
                let raw = try needValue()
                if raw == "cron" {
                    throw CLIError.invalid("cron is removed; use --schedule-type weekdays --schedule 08:00")
                }
                guard let value = ScheduleType(rawValue: raw) else {
                    throw CLIError.invalid("unknown schedule-type: \(raw)")
                }
                scheduleType = value
            case "--schedule": schedule = try needValue()
            case "--enabled": enabled = true
            case "--disabled": enabled = false
            case "--timeout":
                guard let value = Int(try needValue()) else {
                    throw CLIError.invalid("timeout must be an integer")
                }
                timeout = value
            case "--provider":
                let raw = try needValue()
                guard let value = AgentProvider(rawValue: raw) else {
                    throw CLIError.invalid("unknown provider: \(raw)")
                }
                provider = value
            case "--prompt": prompt = try needValue()
            default:
                throw CLIError.usage("unknown create option: \(token)")
            }
            i += 1
        }

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CLIError.usage("create requires --name")
        }
        if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, type != .agent {
            throw CLIError.usage("create requires --command")
        }
        if type == .agent, command.isEmpty {
            command = provider.defaultExecutable
        }

        let arguments: String
        if let argumentsBlob, !argumentsBlob.isEmpty {
            arguments = argumentsBlob
        } else {
            arguments = argLines.joined(separator: "\n")
        }

        return CreateOptions(
            name: name,
            type: type,
            command: command,
            arguments: arguments,
            workingDirectory: cwd,
            scheduleType: scheduleType,
            scheduleExpression: schedule,
            enabled: enabled,
            timeout: timeout,
            agentProvider: provider,
            agentPrompt: prompt
        )
    }
}

@MainActor
private final class CLIHub {
    let context: ModelContext
    let taskService: TaskService
    let runService: RunService
    let json: Bool

    init(
        context: ModelContext,
        taskService: TaskService,
        runService: RunService,
        json: Bool
    ) {
        self.context = context
        self.taskService = taskService
        self.runService = runService
        self.json = json
    }

    func execute(_ command: CLICommand) async throws {
        _ = try taskService.reconcileNextRunTimes()
        switch command {
        case .help:
            break
        case .list:
            try listTasks()
        case .get(let key):
            try getTask(key)
        case .create(let options):
            try createTask(options)
        case .run(let key):
            try await runTask(key)
        case .stop(let key):
            try stopTask(key)
        case .enable(let key):
            try setEnabled(key, true)
        case .disable(let key):
            try setEnabled(key, false)
        case .delete(let key):
            try deleteTask(key)
        case .status:
            try status()
        }
    }

    private func listTasks() throws {
        let tasks = try taskService.fetchAll()
        if json {
            emit(tasks.map(taskDict))
        } else {
            if tasks.isEmpty {
                print("(no tasks)")
                return
            }
            for task in tasks {
                let flag = task.enabled ? "on" : "off"
                let status = task.lastRunStatus?.rawValue ?? "-"
                print("\(task.id.uuidString)  [\(flag)]  \(status)  \(task.name)")
            }
        }
    }

    private func getTask(_ key: String) throws {
        let task = try resolve(key)
        if json {
            emit(taskDict(task))
        } else {
            print(pretty(task))
        }
    }

    private func createTask(_ options: CreateOptions) throws {
        var draft = TaskDraft()
        draft.name = options.name
        draft.type = options.type
        draft.command = options.command
        draft.arguments = options.arguments
        draft.workingDirectory = options.workingDirectory
        draft.scheduleType = options.scheduleType
        draft.scheduleExpression = options.scheduleExpression
        draft.enabled = options.enabled
        draft.timeout = options.timeout
        draft.agentProvider = options.agentProvider
        draft.agentPrompt = options.agentPrompt
        draft.applyAgentDefaultsIfNeeded()

        let task = try taskService.create(draft)
        notifyRefresh()
        if json {
            emit(["ok": true, "task": taskDict(task)])
        } else {
            print("created \(task.id.uuidString)  \(task.name)")
        }
    }

    private func runTask(_ key: String) async throws {
        let task = try resolve(key)
        try await runService.runFromCLI(taskID: task.id)
        notifyRefresh()
        let refreshed = try resolve(task.id.uuidString)
        if json {
            emit([
                "ok": true,
                "taskID": refreshed.id.uuidString,
                "status": refreshed.lastRunStatus?.rawValue ?? "unknown",
                "duration": refreshed.lastRunDuration ?? 0
            ])
        } else {
            print("finished \(refreshed.name) → \(refreshed.lastRunStatus?.rawValue ?? "?")")
        }
    }

    private func stopTask(_ key: String) throws {
        let task = try resolve(key)
        // Ask GUI (if running) to stop its in-process session.
        DistributedNotificationCenter.default().post(
            name: .runlyStopTask,
            object: nil,
            userInfo: ["taskID": task.id.uuidString]
        )
        _ = HeadlessProcessProbe.terminate(taskID: task.id)

        // Mark open runs cancelled when no process remains.
        let open = try runService.fetchRuns(for: task.id, limit: 20).filter { $0.status == .running }
        for run in open {
            run.status = .cancelled
            run.endAt = .now
            run.duration = Date().timeIntervalSince(run.startAt)
            run.exitCode = run.exitCode ?? 15
        }
        if task.lastRunStatus == .running {
            task.lastRunStatus = .cancelled
            task.lastRunAt = .now
        }
        try context.save()
        _ = runService.reconcileOrphanedRuns()
        notifyRefresh()

        if json {
            emit(["ok": true, "taskID": task.id.uuidString, "stopped": true])
        } else {
            print("stopped \(task.name)")
        }
    }

    private func setEnabled(_ key: String, _ enabled: Bool) throws {
        let task = try resolve(key)
        try taskService.setEnabled(task, enabled: enabled)
        notifyRefresh()
        if json {
            emit(["ok": true, "taskID": task.id.uuidString, "enabled": enabled])
        } else {
            print("\(enabled ? "enabled" : "disabled") \(task.name)")
        }
    }

    private func deleteTask(_ key: String) throws {
        let task = try resolve(key)
        let id = task.id.uuidString
        let name = task.name
        try taskService.delete(task)
        notifyRefresh()
        if json {
            emit(["ok": true, "deleted": id, "name": name])
        } else {
            print("deleted \(name)")
        }
    }

    private func status() throws {
        let tasks = try taskService.fetchAll()
        let running = tasks.filter { $0.lastRunStatus == .running }
        let failed = tasks.filter { $0.lastRunStatus == .failed || $0.lastRunStatus == .timeout }
        let payload: [String: Any] = [
            "ok": true,
            "total": tasks.count,
            "enabled": tasks.filter(\.enabled).count,
            "running": running.map { ["id": $0.id.uuidString, "name": $0.name] },
            "failed": failed.prefix(10).map { ["id": $0.id.uuidString, "name": $0.name, "status": $0.lastRunStatus?.rawValue ?? ""] }
        ]
        if json {
            emit(payload)
        } else {
            print("tasks=\(tasks.count) enabled=\(tasks.filter(\.enabled).count) running=\(running.count) failed=\(failed.count)")
            for task in running {
                print("  running  \(task.id.uuidString)  \(task.name)")
            }
        }
    }

    private func resolve(_ key: String) throws -> RunlyTask {
        let tasks = try taskService.fetchAll()
        if let id = UUID(uuidString: key), let match = tasks.first(where: { $0.id == id }) {
            return match
        }
        let exact = tasks.filter { $0.name == key }
        if exact.count == 1 { return exact[0] }
        if exact.count > 1 {
            throw CLIError.invalid("multiple tasks named \(key); use UUID")
        }
        let fuzzy = tasks.filter { $0.name.localizedCaseInsensitiveContains(key) }
        if fuzzy.count == 1 { return fuzzy[0] }
        if fuzzy.count > 1 {
            throw CLIError.invalid("ambiguous name \(key); use UUID")
        }
        throw CLIError.notFound("task not found: \(key)")
    }

    private func taskDict(_ task: RunlyTask) -> [String: Any] {
        [
            "id": task.id.uuidString,
            "name": task.name,
            "enabled": task.enabled,
            "type": task.type.rawValue,
            "command": task.command,
            "arguments": task.argumentList,
            "workingDirectory": task.workingDirectory,
            "scheduleType": task.scheduleType.rawValue,
            "scheduleExpression": task.scheduleExpression,
            "timeout": task.timeout,
            "retryCount": task.retryCount,
            "lastRunStatus": task.lastRunStatus?.rawValue ?? "",
            "lastRunAt": task.lastRunAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "nextRunAt": task.nextRunAt.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "agentProvider": task.agentProvider.rawValue,
            "agentPrompt": task.agentPrompt
        ]
    }

    private func pretty(_ task: RunlyTask) -> String {
        """
        id:        \(task.id.uuidString)
        name:      \(task.name)
        enabled:   \(task.enabled)
        type:      \(task.type.rawValue)
        command:   \(task.command)
        args:      \(task.argumentList.joined(separator: " | "))
        schedule:  \(task.scheduleType.rawValue) · \(task.scheduleExpression)
        status:    \(task.lastRunStatus?.rawValue ?? "-")
        next:      \(task.nextRunAt.map { $0.description } ?? "-")
        """
    }

    private func emit(_ value: Any) {
        let normalized = normalizeJSON(value)
        guard JSONSerialization.isValidJSONObject(normalized),
              let data = try? JSONSerialization.data(withJSONObject: normalized, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            print(String(describing: value))
            return
        }
        print(text)
    }

    private func normalizeJSON(_ value: Any) -> Any {
        switch value {
        case let dict as [String: Any]:
            var out: [String: Any] = [:]
            for (k, v) in dict {
                if v is NSNull { continue }
                out[k] = normalizeJSON(v)
            }
            return out
        case let array as [Any]:
            return array.map(normalizeJSON)
        case let uuid as UUID:
            return uuid.uuidString
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case is NSNull:
            return NSNull()
        default:
            return value
        }
    }

    private func notifyRefresh() {
        DistributedNotificationCenter.default().post(name: .runlyRefresh, object: nil)
    }
}
