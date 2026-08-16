import Foundation

/// Lightweight draft checks shown inline in the task editor.
enum DraftValidator {
    enum Severity: Equatable {
        case info
        case success
        case warning
        case error
    }

    struct Message: Equatable, Identifiable {
        let id: String
        let severity: Severity
        let text: String
    }

    static func messages(for draft: TaskDraft, resolved: ResolvedCommand?) -> [Message] {
        var result: [Message] = []
        let command = draft.resolvedCommand.trimmingCharacters(in: .whitespacesAndNewlines)

        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(Message(id: "name", severity: .warning, text: L10n.tr("validate.name_empty")))
        }

        if command.isEmpty {
            result.append(Message(id: "command.empty", severity: .error, text: L10n.tr("validate.command_empty")))
        } else if draft.type != .script {
            let env = ProcessInfo.processInfo.environment
            if ShellPathResolver.resolveExecutable(command, environment: env) == nil, resolved == nil {
                result.append(Message(
                    id: "command.missing",
                    severity: .warning,
                    text: String(format: L10n.tr("validate.command_not_found"), locale: L10n.locale, command)
                ))
            }
        } else {
            let expanded = ShellPathResolver.expandedPath(command)
            if !FileManager.default.fileExists(atPath: expanded) {
                result.append(Message(
                    id: "script.missing",
                    severity: .warning,
                    text: String(format: L10n.tr("validate.script_missing"), locale: L10n.locale, command)
                ))
            }
        }

        if draft.type == .agent,
           draft.agentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           draft.arguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(Message(id: "agent.prompt", severity: .warning, text: L10n.tr("validate.agent_prompt_empty")))
        }

        if let quoteIssue = unbalancedQuotes(in: draft.arguments) {
            result.append(Message(id: "args.quotes", severity: .error, text: quoteIssue))
        }

        for (index, line) in draft.environment.split(whereSeparator: \.isNewline).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            if !trimmed.contains("=") {
                result.append(Message(
                    id: "env.\(index)",
                    severity: .error,
                    text: String(format: L10n.tr("validate.env_line"), locale: L10n.locale, trimmed)
                ))
                break
            }
            if trimmed.split(separator: "=", maxSplits: 1).first?.isEmpty == true {
                result.append(Message(
                    id: "env.key.\(index)",
                    severity: .error,
                    text: L10n.tr("validate.env_key_empty")
                ))
                break
            }
        }

        if !draft.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let path = ShellPathResolver.expandedPath(draft.workingDirectory)
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) || !isDir.boolValue {
                result.append(Message(
                    id: "cwd",
                    severity: .warning,
                    text: String(format: L10n.tr("validate.cwd_missing"), locale: L10n.locale, draft.workingDirectory)
                ))
            }
        }

        if draft.scheduleExpression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           draft.scheduleType != .once {
            result.append(Message(id: "schedule", severity: .warning, text: L10n.tr("validate.schedule_empty")))
        }

        if draft.timeout < 0 {
            result.append(Message(id: "timeout", severity: .error, text: L10n.tr("validate.timeout_negative")))
        }
        if draft.retryCount < 0 {
            result.append(Message(id: "retry", severity: .error, text: L10n.tr("validate.retry_negative")))
        }

        if draft.proxyEnabled {
            let anyProxy = [draft.httpProxy, draft.httpsProxy, draft.socksProxy]
                .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if !anyProxy {
                result.append(Message(id: "proxy", severity: .warning, text: L10n.tr("validate.proxy_empty")))
            }
        }

        return result
    }

    static func blockingErrors(for draft: TaskDraft, resolved: ResolvedCommand?) -> [Message] {
        messages(for: draft, resolved: resolved).filter { $0.severity == .error }
    }

    private static func unbalancedQuotes(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Arguments are one-per-line; check each line that looks quoted.
        for line in trimmed.split(whereSeparator: \.isNewline).map(String.init) {
            let tokenized = ShellQuoteTokenizer.tokenizeDetailed(line)
            if tokenized.inSingleQuote {
                return L10n.tr("validate.unbalanced_single")
            }
            if tokenized.inDoubleQuote {
                return L10n.tr("validate.unbalanced_double")
            }
        }
        return nil
    }
}
