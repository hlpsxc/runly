import Foundation

struct ResolvedCommand: Sendable {
    var executable: String
    var executableURL: URL
    var arguments: [String]
    var workingDirectory: URL?
    var environment: [String: String]
    var preview: String

    var proxySummary: String {
        var parts: [String] = []
        if let http = environment["HTTP_PROXY"] ?? environment["http_proxy"], !http.isEmpty {
            parts.append("HTTP_PROXY=\(http)")
        }
        if let https = environment["HTTPS_PROXY"] ?? environment["https_proxy"], !https.isEmpty {
            parts.append("HTTPS_PROXY=\(https)")
        }
        if let all = environment["ALL_PROXY"] ?? environment["all_proxy"], !all.isEmpty {
            parts.append("ALL_PROXY=\(all)")
        }
        if let no = environment["NO_PROXY"] ?? environment["no_proxy"], !no.isEmpty {
            parts.append("NO_PROXY=\(no)")
        }
        return parts.isEmpty ? "(none)" : parts.joined(separator: "\n")
    }

    var pathSummary: String {
        environment["PATH"] ?? "(default)"
    }
}

enum AgentService {
    static func resolve(_ task: RunlyTask) throws -> ResolvedCommand {
        let env = EnvironmentResolver.buildEnvironment(for: task)
        let values = TemplateEngine.baseValues(
            taskName: task.name,
            workingDirectory: ShellPathResolver.expandedPath(task.workingDirectory)
        )

        var executableName = task.command.trimmingCharacters(in: .whitespacesAndNewlines)
        if task.type == .agent, executableName.isEmpty {
            executableName = task.agentProvider.defaultExecutable
        }

        var arguments = ArgumentParser.parse(task.arguments).map {
            TemplateEngine.render($0, values: values)
        }

        if task.type == .agent {
            let prompt = TemplateEngine.render(
                task.agentPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
                values: values
            )
            if arguments.isEmpty, !prompt.isEmpty {
                arguments = defaultArguments(for: task.agentProvider, prompt: prompt)
            } else if !prompt.isEmpty {
                arguments = arguments.map {
                    $0.replacingOccurrences(of: "{{prompt}}", with: prompt)
                }
            }
        }

        executableName = TemplateEngine.render(executableName, values: values)

        if task.type == .script {
            let resolved = try resolveScript(
                scriptPath: executableName,
                extraArguments: arguments,
                environment: env
            )
            return finalize(
                executableName: resolved.executableName,
                url: resolved.url,
                arguments: resolved.arguments,
                task: task,
                env: env
            )
        }

        guard let url = ShellPathResolver.resolveExecutable(executableName, environment: env) else {
            throw CommandExecutorError.executableNotFound(executableName.isEmpty ? "<empty>" : executableName)
        }

        return finalize(
            executableName: executableName,
            url: url,
            arguments: arguments,
            task: task,
            env: env
        )
    }

    private static func finalize(
        executableName: String,
        url: URL,
        arguments: [String],
        task: RunlyTask,
        env: [String: String]
    ) -> ResolvedCommand {
        var cwd: URL?
        let wd = task.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !wd.isEmpty {
            cwd = URL(fileURLWithPath: ShellPathResolver.expandedPath(wd), isDirectory: true)
        }

        let previewArgs = arguments.joined(separator: " ")
        let preview = previewArgs.isEmpty ? url.path : "\(url.path) \(previewArgs)"

        return ResolvedCommand(
            executable: executableName,
            executableURL: url,
            arguments: arguments,
            workingDirectory: cwd,
            environment: env,
            preview: preview
        )
    }

    /// Script tasks: `command` is a script path. Use direct exec when executable,
    /// otherwise pick an interpreter from the file extension.
    private static func resolveScript(
        scriptPath: String,
        extraArguments: [String],
        environment: [String: String]
    ) throws -> (executableName: String, url: URL, arguments: [String]) {
        let expanded = ShellPathResolver.expandedPath(scriptPath)
        let scriptURL = URL(fileURLWithPath: expanded)

        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            // Fall back to PATH lookup (e.g. user typed a bare script name).
            if let url = ShellPathResolver.resolveExecutable(scriptPath, environment: environment) {
                return (scriptPath, url, extraArguments)
            }
            throw CommandExecutorError.executableNotFound(scriptPath.isEmpty ? "<script>" : scriptPath)
        }

        if FileManager.default.isExecutableFile(atPath: scriptURL.path) {
            return (scriptURL.path, scriptURL, extraArguments)
        }

        let ext = scriptURL.pathExtension.lowercased()
        let interpreter: String
        switch ext {
        case "py": interpreter = "python3"
        case "js", "mjs", "cjs": interpreter = "node"
        case "rb": interpreter = "ruby"
        case "pl": interpreter = "perl"
        case "sh": interpreter = "/bin/sh"
        case "zsh": interpreter = "/bin/zsh"
        case "bash": interpreter = "/bin/bash"
        case "swift": interpreter = "swift"
        default:
            // Non-executable unknown script — try /bin/zsh as a last resort.
            interpreter = "/bin/zsh"
        }

        guard let interpURL = ShellPathResolver.resolveExecutable(interpreter, environment: environment) else {
            throw CommandExecutorError.executableNotFound(interpreter)
        }
        return (interpreter, interpURL, [scriptURL.path] + extraArguments)
    }

    private static func defaultArguments(for provider: AgentProvider, prompt: String) -> [String] {
        switch provider {
        case .claude:
            return ["-p", prompt]
        case .codex:
            return ["exec", prompt]
        case .openclaw, .custom:
            return [prompt]
        }
    }
}
