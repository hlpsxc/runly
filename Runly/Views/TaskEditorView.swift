import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(LocalizationStore.self) private var localization

    private let editTaskID: UUID?
    var onSave: () -> Void

    @State private var draft = TaskDraft()
    @State private var editingTask: RunlyTask?
    @State private var errorMessage: String?
    @State private var testOutput: String = ""
    @State private var isTesting = false
    @State private var resolvedPreview: ResolvedCommand?
    @State private var pastedCommandLine: String = ""
    @State private var pasteParseNote: String?
    @State private var pasteParseSeverity: DraftValidator.Severity = .info
    @State private var notificationSource: TaskDraft.NotificationSource = .system
    @State private var fieldMessages: [DraftValidator.Message] = []


    init(route: EditorRoute, onSave: @escaping () -> Void) {
        self.onSave = onSave
        switch route {
        case .create:
            editTaskID = nil
        case .edit(let taskID):
            editTaskID = taskID
        }
    }

    var body: some View {
        let _ = localization.revision
        let t = localization
        NavigationStack {
            Form {
                Section(t.tr("basics")) {
                    TextField(t.tr("name"), text: $draft.name)
                    Picker(t.tr("type"), selection: $draft.type) {
                        ForEach(TaskType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .onChange(of: draft.type) { _, _ in refreshPreview() }
                    Toggle(t.tr("enabled"), isOn: $draft.enabled)
                }

                Section(t.tr("paste_cli")) {
                    TextField(
                        "",
                        text: $pastedCommandLine,
                        prompt: Text(t.tr("paste_cli.placeholder")),
                        axis: .vertical
                    )
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(4...12)
                    .onChange(of: pastedCommandLine) { _, newValue in
                        applyPastedCommandLine(newValue)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Button(t.tr("parse")) {
                            applyPastedCommandLine(pastedCommandLine, force: true)
                        }
                        .disabled(pastedCommandLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if let pasteParseNote {
                            Text(pasteParseNote)
                                .font(.caption)
                                .foregroundStyle(severityColor(pasteParseSeverity))
                        }
                    }

                    // Empty → show example hint; with input → replace with live status.
                    if pastedCommandLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(t.tr("paste_cli.example"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else if pasteParseNote == nil {
                        Text(t.tr("validate.has_input"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if draft.type == .agent {
                    Section(t.tr("type.agent")) {
                        Picker(t.tr("provider"), selection: $draft.agentProvider) {
                            ForEach(AgentProvider.allCases) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .onChange(of: draft.agentProvider) { _, provider in
                            let defaults = AgentProvider.allCases.map(\.defaultExecutable)
                            if draft.command.isEmpty || defaults.contains(draft.command) {
                                draft.command = provider.defaultExecutable
                            }
                            refreshPreview()
                        }

                        TextField(t.tr("executable"), text: $draft.command)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.command) { _, _ in refreshPreview() }
                        TextField(t.tr("prompt"), text: $draft.agentPrompt, axis: .vertical)
                            .lineLimit(3...6)
                            .onChange(of: draft.agentPrompt) { _, _ in refreshPreview() }
                        TextField(t.tr("extra_args"), text: $draft.arguments, axis: .vertical)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2...5)
                            .onChange(of: draft.arguments) { _, _ in refreshPreview() }
                        commandSectionFooter(
                            emptyHint: t.tr("templates.hint"),
                            hasInput: hasCommandInput
                        )
                    }
                } else if draft.type == .script {
                    Section(t.tr("type.script")) {
                        TextField(t.tr("script_path"), text: $draft.command)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.command) { _, _ in refreshPreview() }
                        TextField(t.tr("arguments"), text: $draft.arguments, axis: .vertical)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(3...8)
                            .onChange(of: draft.arguments) { _, _ in refreshPreview() }
                        commandSectionFooter(
                            emptyHint: t.tr("script.hint"),
                            hasInput: hasCommandInput
                        )
                    }
                } else {
                    Section(t.tr("type.command")) {
                        TextField(t.tr("command"), text: $draft.command)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.command) { _, _ in refreshPreview() }
                        TextField(t.tr("arguments"), text: $draft.arguments, axis: .vertical)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(3...8)
                            .onChange(of: draft.arguments) { _, _ in refreshPreview() }
                        commandSectionFooter(
                            emptyHint: t.tr("command.hint"),
                            hasInput: hasCommandInput
                        )
                    }
                }

                Section(t.tr("working_directory")) {
                    TextField(
                        "",
                        text: $draft.workingDirectory,
                        prompt: Text("~/Projects/…")
                    )
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: draft.workingDirectory) { _, _ in refreshPreview() }
                    feedbackLines(ids: ["cwd"], emptyHint: nil, hasInput: !draft.workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section(t.tr("schedule")) {
                    Picker(t.tr("type"), selection: $draft.scheduleType) {
                        ForEach(ScheduleType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .onChange(of: draft.scheduleType) { _, _ in refreshValidation() }
                    TextField(t.tr("expression"), text: $draft.scheduleExpression)
                        .onChange(of: draft.scheduleExpression) { _, _ in refreshValidation() }
                    let scheduleFilled = !draft.scheduleExpression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    feedbackLines(
                        ids: ["schedule"],
                        emptyHint: scheduleFilled ? nil : t.tr("schedule.hint"),
                        hasInput: scheduleFilled
                    )
                }

                Section(t.tr("environment")) {
                    TextField(
                        "",
                        text: $draft.environment,
                        prompt: Text(t.tr("env.placeholder")),
                        axis: .vertical
                    )
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(3...8)
                    .onChange(of: draft.environment) { _, _ in refreshPreview() }
                    feedbackLines(
                        ids: ["env"],
                        emptyHint: nil,
                        hasInput: !draft.environment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        idPrefixMatch: true
                    )
                }

                Section(t.tr("proxy")) {
                    Toggle(t.tr("enabled"), isOn: $draft.proxyEnabled)
                        .onChange(of: draft.proxyEnabled) { _, _ in refreshPreview() }
                    if draft.proxyEnabled {
                        TextField(t.tr("http"), text: $draft.httpProxy)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.httpProxy) { _, _ in refreshPreview() }
                        TextField(t.tr("https"), text: $draft.httpsProxy)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.httpsProxy) { _, _ in refreshPreview() }
                        TextField(t.tr("socks"), text: $draft.socksProxy)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.socksProxy) { _, _ in refreshPreview() }
                        TextField(t.tr("no_proxy"), text: $draft.noProxy)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.noProxy) { _, _ in refreshPreview() }
                    }
                }

                Section(t.tr("notifications")) {
                    Toggle(t.tr("enabled"), isOn: $draft.notificationEnabled)
                    if draft.notificationEnabled {
                        Picker(t.tr("trigger"), selection: $draft.notificationTrigger) {
                            ForEach(NotificationTrigger.allCases) { trigger in
                                Text(trigger.displayName).tag(trigger)
                            }
                        }

                        Picker(t.tr("notif_template.picker"), selection: $notificationSource) {
                            Text(t.tr("notif_template.source.system")).tag(TaskDraft.NotificationSource.system)
                            ForEach(appState.notificationTemplates, id: \.id) { template in
                                Text(template.name).tag(TaskDraft.NotificationSource.template(template.id))
                            }
                            Text(t.tr("notif_template.source.custom")).tag(TaskDraft.NotificationSource.custom)
                        }
                        .onChange(of: notificationSource) { _, source in
                            draft.notificationSource = source
                        }

                        switch notificationSource {
                        case .system:
                            Text(t.tr("notif_template.source.system_hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        case .template(let id):
                            if let template = appState.notificationTemplate(id: id) {
                                Text(template.preview)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                Text(t.tr("notif_template.source.template_hint"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(t.tr("notif_template.missing"))
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        case .custom:
                            TextField(
                                "",
                                text: $draft.notificationCommand,
                                prompt: Text(t.tr("notification.cmd_placeholder")),
                                axis: .vertical
                            )
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2...4)
                        }

                        if showsNotificationHints {
                            Text(t.tr("notification.vars"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(t.tr("limits")) {
                    TextField(t.tr("timeout_seconds"), value: $draft.timeout, format: .number)
                    TextField(t.tr("retry_count"), value: $draft.retryCount, format: .number)
                }

                Section(t.tr("command_preview")) {
                    Text("$ \(resolvedPreview?.preview ?? draft.previewLine)")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    labeledPreview(
                        t.tr("working_directory"),
                        resolvedPreview?.workingDirectory?.path
                            ?? (draft.workingDirectory.isEmpty ? t.tr("default") : draft.workingDirectory)
                    )
                    labeledPreview(
                        t.tr("schedule"),
                        "\(draft.scheduleType.displayName) · \(draft.scheduleExpression.isEmpty ? t.tr("em_dash") : draft.scheduleExpression)"
                    )
                    if let preview = resolvedPreview {
                        labeledPreview(t.tr("path_tail"), pathTail(preview.pathSummary))
                        labeledPreview(t.tr("proxy"), preview.proxySummary == "(none)" ? t.tr("none") : preview.proxySummary)
                    }

                    if !fieldMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(fieldMessages) { message in
                                Label(message.text, systemImage: severityIcon(message.severity))
                                    .font(.caption)
                                    .foregroundStyle(severityColor(message.severity))
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                        .padding(.top, 4)
                    }

                    if !testOutput.isEmpty {
                        Text(testOutput)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        Button(isTesting ? t.tr("testing") : t.tr("test_run")) {
                            Task { await testRun() }
                        }
                        .disabled(isTesting || !DraftValidator.blockingErrors(for: draft, resolved: resolvedPreview).isEmpty)
                        Spacer()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(editTaskID == nil ? t.tr("new_task") : t.tr("edit_task"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.tr("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t.tr("save")) { save() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!DraftValidator.blockingErrors(for: draft, resolved: resolvedPreview).isEmpty)
                }
            }
            .alert(
                DraftValidator.blockingErrors(for: draft, resolved: resolvedPreview).isEmpty
                    ? t.tr("could_not_save")
                    : t.tr("validate.fix_title"),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(t.tr("ok"), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear(perform: loadIfEditing)
        }
    }

    private func labeledPreview(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(.top, 2)
    }

    private func pathTail(_ path: String) -> String {
        let parts = path.split(separator: ":")
        if parts.count <= 6 { return path }
        return "…" + parts.suffix(6).joined(separator: ":")
    }

    private func loadIfEditing() {
        if let editTaskID, let task = appState.task(id: editTaskID) {
            editingTask = task
            draft = TaskDraft.from(task)
            notificationSource = draft.notificationSource
        } else if draft.type == .agent, draft.command.isEmpty {
            draft.command = draft.agentProvider.defaultExecutable
            notificationSource = draft.notificationSource
        } else {
            notificationSource = draft.notificationSource
        }
        refreshPreview()
    }

    private var hasCommandInput: Bool {
        !draft.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.arguments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.agentPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsNotificationHints: Bool {
        switch notificationSource {
        case .system:
            return true
        case .template:
            return false
        case .custom:
            return draft.notificationCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @ViewBuilder
    private func commandSectionFooter(emptyHint: String, hasInput: Bool) -> some View {
        feedbackLines(
            ids: ["command", "script", "agent", "args"],
            emptyHint: hasInput ? nil : emptyHint,
            hasInput: hasInput,
            idPrefixMatch: true
        )
    }

    @ViewBuilder
    private func feedbackLines(
        ids: [String],
        emptyHint: String?,
        hasInput: Bool,
        idPrefixMatch: Bool = false
    ) -> some View {
        let matched = fieldMessages.filter { message in
            ids.contains { id in
                idPrefixMatch ? message.id.hasPrefix(id) : message.id == id
            }
        }
        if !matched.isEmpty {
            ForEach(matched) { message in
                Text(message.text)
                    .font(.caption)
                    .foregroundStyle(severityColor(message.severity))
            }
        } else if let emptyHint, !hasInput {
            Text(emptyHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func severityColor(_ severity: DraftValidator.Severity) -> Color {
        switch severity {
        case .info: .secondary
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }

    private func severityIcon(_ severity: DraftValidator.Severity) -> String {
        switch severity {
        case .info: "info.circle"
        case .success: "checkmark.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }

    private func refreshPreview() {
        let temp = draft.makeTask()
        resolvedPreview = try? AgentService.resolve(temp)
        refreshValidation()
    }

    private func refreshValidation() {
        fieldMessages = DraftValidator.messages(for: draft, resolved: resolvedPreview)
    }

    private func applyPastedCommandLine(_ raw: String, force: Bool = false) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            pasteParseNote = nil
            pasteParseSeverity = .info
            return
        }

        // Avoid fighting tiny edits unless user hits Parse.
        let looksLikeCLI = force
            || trimmed.contains("\\")
            || trimmed.contains("\"")
            || trimmed.contains("'")
            || trimmed.contains("\n")
            || trimmed.split(whereSeparator: \.isWhitespace).count >= 2

        guard looksLikeCLI else {
            pasteParseNote = localization.tr("validate.has_input")
            pasteParseSeverity = .info
            // Still treat single token as command when forced or looks intentional.
            if force || trimmed.split(whereSeparator: \.isWhitespace).count == 1 {
                draft.command = trimmed
                draft.arguments = ""
                refreshPreview()
            }
            return
        }

        switch CommandLineParser.parseDetailed(trimmed) {
        case .failure(let error):
            pasteParseSeverity = .error
            pasteParseNote = parseErrorMessage(error)
        case .success(let parsed):
            draft.command = parsed.executable
            draft.arguments = parsed.argumentsText

            // Agent paste: keep prompt empty; argv already includes -p / prompt text.
            if draft.type == .agent {
                draft.agentPrompt = ""
                let known = ["claude", "codex", "openclaw", "agent"]
                if known.contains(parsed.executable.lowercased()) {
                    switch parsed.executable.lowercased() {
                    case "claude": draft.agentProvider = .claude
                    case "codex": draft.agentProvider = .codex
                    case "openclaw": draft.agentProvider = .openclaw
                    default: draft.agentProvider = .custom
                    }
                } else {
                    draft.agentProvider = .custom
                }
            }

            pasteParseSeverity = .success
            pasteParseNote = String(
                format: localization.tr("parse.ok"),
                locale: localization.language.locale,
                parsed.executable,
                parsed.arguments.count
            )
            refreshPreview()
        }
    }

    private func parseErrorMessage(_ error: CommandLineParser.ParseError) -> String {
        switch error {
        case .empty: localization.tr("parse.failed")
        case .unbalancedSingleQuote: localization.tr("parse.unbalanced_single")
        case .unbalancedDoubleQuote: localization.tr("parse.unbalanced_double")
        case .trailingEscape: localization.tr("parse.trailing_escape")
        case .noExecutable: localization.tr("parse.no_executable")
        }
    }

    private func save() {
        draft.notificationSource = notificationSource
        refreshValidation()
        let blockers = DraftValidator.blockingErrors(for: draft, resolved: resolvedPreview)
        guard blockers.isEmpty else {
            errorMessage = blockers.map(\.text).joined(separator: "\n")
            return
        }
        do {
            if let editingTask {
                try appState.updateTask(editingTask, with: draft)
            } else {
                _ = try appState.createTask(draft)
            }
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func testRun() async {
        refreshPreview()
        guard let preview = resolvedPreview else {
            testOutput = localization.tr("test.cannot_resolve")
            return
        }

        isTesting = true
        testOutput = String(format: localization.tr("test.running"), locale: localization.language.locale, preview.preview)
        defer { isTesting = false }

        let executor = CommandExecutor()
        let timeout = TimeInterval(min(max(draft.timeout, 1), 60))
        let spec = CommandSpec(
            executableURL: preview.executableURL,
            arguments: preview.arguments,
            environment: preview.environment,
            currentDirectoryURL: preview.workingDirectory,
            timeout: timeout
        )

        do {
            let result = try await executor.run(
                spec,
                onStdout: { text in
                    Task { @MainActor in testOutput += text }
                },
                onStderr: { text in
                    Task { @MainActor in testOutput += text }
                }
            )
            testOutput += "\nExit \(result.exitCode) · \(String(format: "%.1fs", result.duration))"
            if result.timedOut { testOutput += " (timeout)" }
        } catch {
            testOutput += "\nError: \(error.localizedDescription)"
        }
    }
}
