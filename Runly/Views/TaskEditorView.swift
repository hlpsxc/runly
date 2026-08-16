import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private let editTaskID: UUID?
    var onSave: () -> Void

    @State private var draft = TaskDraft()
    @State private var editingTask: RunlyTask?
    @State private var errorMessage: String?
    @State private var testOutput: String = ""
    @State private var isTesting = false
    @State private var resolvedPreview: ResolvedCommand?

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
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $draft.name)
                    Picker("Type", selection: $draft.type) {
                        ForEach(TaskType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .onChange(of: draft.type) { _, _ in refreshPreview() }
                    Toggle("Enabled", isOn: $draft.enabled)
                }

                if draft.type == .agent {
                    Section("Agent") {
                        Picker("Provider", selection: $draft.agentProvider) {
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

                        TextField("Executable", text: $draft.command)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.command) { _, _ in refreshPreview() }
                        TextField("Prompt", text: $draft.agentPrompt, axis: .vertical)
                            .lineLimit(3...6)
                            .onChange(of: draft.agentPrompt) { _, _ in refreshPreview() }
                        TextField("Extra Arguments (one per line, optional)", text: $draft.arguments, axis: .vertical)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2...5)
                            .onChange(of: draft.arguments) { _, _ in refreshPreview() }
                        Text("Templates: {{date}} {{time}} {{task_name}} {{working_directory}} {{prompt}}")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if draft.type == .script {
                    Section("Script") {
                        TextField("Script Path", text: $draft.command)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.command) { _, _ in refreshPreview() }
                        TextField("Arguments (one per line)", text: $draft.arguments, axis: .vertical)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(3...8)
                            .onChange(of: draft.arguments) { _, _ in refreshPreview() }
                        Text("Runs the file directly if executable; otherwise picks python3/node/zsh/… from the extension.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Command") {
                        TextField("Command", text: $draft.command)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.command) { _, _ in refreshPreview() }
                        TextField("Arguments (one per line)", text: $draft.arguments, axis: .vertical)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(3...8)
                            .onChange(of: draft.arguments) { _, _ in refreshPreview() }
                        Text("Supports items, claude, python3, … — resolved via PATH (+ Homebrew).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Working Directory") {
                    TextField("~/Projects/…", text: $draft.workingDirectory)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: draft.workingDirectory) { _, _ in refreshPreview() }
                }

                Section("Schedule") {
                    Picker("Type", selection: $draft.scheduleType) {
                        ForEach(ScheduleType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    TextField("Expression", text: $draft.scheduleExpression)
                    Text("Once: 2026-08-20 09:00 · Interval: Every 3 days · Daily: 23:00 · Weekly: Mon 09:00 · Cron: 0 8 * * 1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Environment") {
                    TextField("KEY=VALUE per line", text: $draft.environment, axis: .vertical)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(3...8)
                        .onChange(of: draft.environment) { _, _ in refreshPreview() }
                }

                Section("Proxy") {
                    Toggle("Enabled", isOn: $draft.proxyEnabled)
                        .onChange(of: draft.proxyEnabled) { _, _ in refreshPreview() }
                    if draft.proxyEnabled {
                        TextField("HTTP Proxy", text: $draft.httpProxy)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.httpProxy) { _, _ in refreshPreview() }
                        TextField("HTTPS Proxy", text: $draft.httpsProxy)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.httpsProxy) { _, _ in refreshPreview() }
                        TextField("SOCKS Proxy", text: $draft.socksProxy)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.socksProxy) { _, _ in refreshPreview() }
                        TextField("NO_PROXY", text: $draft.noProxy)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: draft.noProxy) { _, _ in refreshPreview() }
                    }
                }

                Section("Notification") {
                    Toggle("Enabled", isOn: $draft.notificationEnabled)
                    if draft.notificationEnabled {
                        Picker("Trigger", selection: $draft.notificationTrigger) {
                            ForEach(NotificationTrigger.allCases) { trigger in
                                Text(trigger.displayName).tag(trigger)
                            }
                        }
                        TextField("Command (empty = macOS notification)", text: $draft.notificationCommand, axis: .vertical)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2...4)
                        Text("Vars: {{task_name}} {{status}} {{exit_code}} {{duration}} {{stdout}}")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Limits") {
                    TextField("Timeout (seconds)", value: $draft.timeout, format: .number)
                    TextField("Retry Count", value: $draft.retryCount, format: .number)
                }

                Section("Command Preview") {
                    Text("$ \(resolvedPreview?.preview ?? draft.previewLine)")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    labeledPreview("Working Directory", resolvedPreview?.workingDirectory?.path ?? (draft.workingDirectory.isEmpty ? "(default)" : draft.workingDirectory))
                    labeledPreview("Schedule", "\(draft.scheduleType.displayName) · \(draft.scheduleExpression.isEmpty ? "—" : draft.scheduleExpression)")
                    if let preview = resolvedPreview {
                        labeledPreview("PATH (tail)", pathTail(preview.pathSummary))
                        labeledPreview("Proxy", preview.proxySummary)
                    }
                    if !testOutput.isEmpty {
                        Text(testOutput)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        Button(isTesting ? "Testing…" : "Test Run") {
                            Task { await testRun() }
                        }
                        .disabled(isTesting)
                        Spacer()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(editTaskID == nil ? "New Task" : "Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .alert(
                "Could not save",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
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
        } else if draft.type == .agent, draft.command.isEmpty {
            draft.command = draft.agentProvider.defaultExecutable
        }
        refreshPreview()
    }

    private func refreshPreview() {
        let temp = draft.makeTask()
        resolvedPreview = try? AgentService.resolve(temp)
    }

    private func save() {
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
            testOutput = "Cannot resolve command. Check executable / script path."
            return
        }

        isTesting = true
        testOutput = "Running test…\n$ \(preview.preview)\n"
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
