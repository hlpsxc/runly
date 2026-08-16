import Foundation

enum NotificationService {
    private static let executor = CommandExecutor()

    static func maybeNotify(
        task: RunlyTask,
        status: RunStatus,
        exitCode: Int?,
        duration: TimeInterval?,
        stdout: String
    ) async {
        guard task.notificationEnabled else { return }
        guard shouldNotify(trigger: task.notificationTrigger, status: status) else { return }

        let values = TemplateEngine.runValues(
            taskName: task.name,
            workingDirectory: ShellPathResolver.expandedPath(task.workingDirectory),
            status: status,
            exitCode: exitCode,
            duration: duration,
            stdout: stdout
        )

        let commandTemplate = task.notificationCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let env = ProcessInfo.processInfo.environment

        let spec: CommandSpec
        if commandTemplate.isEmpty {
            let body = TemplateEngine.render(
                "Task {{task_name}} finished: {{status}}",
                values: values
            )
            let script = "display notification \"\(escapeForAppleScript(body))\" with title \"Runly\""
            let url = ShellPathResolver.resolveExecutable("osascript", environment: env)
                ?? URL(fileURLWithPath: "/usr/bin/osascript")
            spec = CommandSpec(
                executableURL: url,
                arguments: ["-e", script],
                environment: env,
                currentDirectoryURL: nil,
                timeout: 30
            )
        } else {
            let rendered = TemplateEngine.render(commandTemplate, values: values)
            if let structured = structuredNotificationSpec(rendered, environment: env) {
                spec = structured
            } else {
                // Last resort for complex one-liners (pipes, redirects).
                spec = CommandSpec(
                    executableURL: URL(fileURLWithPath: "/bin/zsh"),
                    arguments: ["-lc", rendered],
                    environment: env,
                    currentDirectoryURL: nil,
                    timeout: 30
                )
            }
        }

        _ = try? await executor.run(spec)
    }

    /// Prefer newline argv, then quote-aware tokenization, before shell.
    private static func structuredNotificationSpec(
        _ rendered: String,
        environment: [String: String]
    ) -> CommandSpec? {
        if rendered.contains("\n") {
            let lines = ArgumentParser.parse(rendered)
            guard let first = lines.first,
                  let url = ShellPathResolver.resolveExecutable(first, environment: environment) else {
                return nil
            }
            return CommandSpec(
                executableURL: url,
                arguments: Array(lines.dropFirst()),
                environment: environment,
                currentDirectoryURL: nil,
                timeout: 30
            )
        }

        let tokens = ShellQuoteTokenizer.tokenize(rendered)
        guard let first = tokens.first,
              let url = ShellPathResolver.resolveExecutable(first, environment: environment),
              !rendered.contains("|"),
              !rendered.contains(">"),
              !rendered.contains("<"),
              !rendered.contains("&&"),
              !rendered.contains("||") else {
            return nil
        }

        return CommandSpec(
            executableURL: url,
            arguments: Array(tokens.dropFirst()),
            environment: environment,
            currentDirectoryURL: nil,
            timeout: 30
        )
    }

    private static func shouldNotify(trigger: NotificationTrigger, status: RunStatus) -> Bool {
        switch trigger {
        case .always: true
        case .onSuccess: status == .success
        case .onFailure: status == .failed || status == .cancelled
        case .onTimeout: status == .timeout
        }
    }

    private static func escapeForAppleScript(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

enum ShellQuoteTokenizer {
    /// Lightweight tokenizer: splits on whitespace, respects single/double quotes.
    static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingle = false
        var inDouble = false

        for char in input {
            switch char {
            case "'" where !inDouble:
                inSingle.toggle()
            case "\"" where !inSingle:
                inDouble.toggle()
            case let c where c.isWhitespace && !inSingle && !inDouble:
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            default:
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
}
