import Foundation

enum EnvironmentResolver {
    static func buildEnvironment(for task: RunlyTask) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = ShellPathResolver.augmentedPATH(from: env["PATH"])

        for (key, value) in parseKeyValueLines(task.environment) {
            env[key] = TemplateEngine.render(
                value,
                values: TemplateEngine.baseValues(
                    taskName: task.name,
                    workingDirectory: ShellPathResolver.expandedPath(task.workingDirectory)
                )
            )
        }

        if task.proxyEnabled {
            if !task.httpProxy.isEmpty {
                env["HTTP_PROXY"] = task.httpProxy
                env["http_proxy"] = task.httpProxy
            }
            if !task.httpsProxy.isEmpty {
                env["HTTPS_PROXY"] = task.httpsProxy
                env["https_proxy"] = task.httpsProxy
            }
            if !task.socksProxy.isEmpty {
                env["ALL_PROXY"] = task.socksProxy
                env["all_proxy"] = task.socksProxy
            }
            if !task.noProxy.isEmpty {
                env["NO_PROXY"] = task.noProxy
                env["no_proxy"] = task.noProxy
            }
        }

        env["RUNLY_TASK_ID"] = task.id.uuidString
        env["RUNLY_TASK_NAME"] = task.name
        return env
    }

    static func parseKeyValueLines(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard let eq = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: eq)...])
            guard !key.isEmpty else { continue }
            result[key] = value
        }
        return result
    }
}
