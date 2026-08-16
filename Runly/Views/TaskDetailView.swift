import AppKit
import SwiftData
import SwiftUI

struct TaskDetailView: View {
    let task: RunlyTask
    var runSession: RunSession
    var logService: LogService
    var runService: RunService?
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onToggleEnabled: () -> Void
    var onRunNow: () -> Void
    var onRefresh: () -> Void
    var initialRunID: UUID? = nil
    var onConsumeFocusRun: (() -> Void)? = nil

    @State private var selectedTab: DetailTab = .overview
    @State private var runs: [TaskRun] = []
    @State private var selectedRunID: UUID?
    @State private var launchdLoaded = false

    private enum DetailTab: String, CaseIterable, Identifiable {
        case overview
        case runs
        case logs

        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: "Overview"
            case .runs: "Runs"
            case .logs: "Logs"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 12)

            Picker("Section", selection: $selectedTab) {
                ForEach(DetailTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 28)
            .padding(.bottom, 12)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .runs:
                        runsContent
                    case .logs:
                        logsContent
                    }
                }
                .padding(28)
                .frame(maxWidth: 900, alignment: .leading)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup {
                Button {
                    onRunNow()
                    selectedTab = .logs
                } label: {
                    Label("Run Now", systemImage: "play.fill")
                }
                .disabled(runSession.isRunning)
                .keyboardShortcut("r", modifiers: [.command])

                Button("Edit", action: onEdit)

                Menu {
                    Button(task.enabled ? "Disable" : "Enable", action: onToggleEnabled)
                    Button("Reload Schedule") {
                        let ok = LaunchdService().reload(task: task)
                        launchdLoaded = LaunchdService().isLoaded(taskID: task.id)
                        onRefresh()
                        if !ok {
                            // Surface via refresh cycle; AppState may also hold last error.
                        }
                    }
                    Divider()
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            reloadRuns()
            launchdLoaded = LaunchdService().isLoaded(taskID: task.id)
            if let initialRunID {
                selectedRunID = initialRunID
                selectedTab = .logs
                onConsumeFocusRun?()
            }
        }
        .onChange(of: task.id) { _, _ in
            selectedTab = .overview
            reloadRuns()
            launchdLoaded = LaunchdService().isLoaded(taskID: task.id)
        }
        .onChange(of: runSession.isRunning) { _, running in
            if !running {
                reloadRuns()
                onRefresh()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(task.name)
                    .font(.largeTitle.weight(.semibold))
                Spacer()
                Toggle(task.enabled ? "Enabled" : "Disabled", isOn: Binding(
                    get: { task.enabled },
                    set: { _ in onToggleEnabled() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                Text(task.enabled ? "Enabled" : "Disabled")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label(task.type.displayName, systemImage: task.type.systemImage)
                Text("·").foregroundStyle(.tertiary)
                Text(task.scheduleSummary)
                if launchdLoaded {
                    Text("·").foregroundStyle(.tertiary)
                    Label("launchd", systemImage: "gearshape.2")
                        .foregroundStyle(.secondary)
                }
                if runSession.isRunning, runSession.taskID == task.id {
                    Text("·").foregroundStyle(.tertiary)
                    Label("Running", systemImage: "circle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                metaCard(title: "Next Run", value: RelativeTimeFormatter.absolute(task.nextRunAt))
                metaCard(title: "Last Run", value: RelativeTimeFormatter.absolute(task.lastRunAt))
                metaCard(
                    title: "Status",
                    value: task.lastRunStatus?.displayName
                        ?? (task.enabled ? "Ready" : "Disabled")
                )
                metaCard(
                    title: "Duration",
                    value: task.lastRunDuration.map { String(format: "%.1fs", $0) }
                        ?? "—"
                )
                metaCard(title: "Timeout", value: "\(task.timeout)s")
                metaCard(title: "Retry", value: "\(task.retryCount)")
            }

            detailSection("Command") {
                Text("$ \(previewCommand)")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                if !task.workingDirectory.isEmpty {
                    labeled("Working Directory", task.workingDirectory)
                }
                if task.type == .agent {
                    labeled("Agent Provider", task.agentProvider.displayName)
                    if !task.agentPrompt.isEmpty {
                        labeled("Prompt", task.agentPrompt)
                    }
                }
            }

            detailSection("Schedule") {
                labeled("Type", task.scheduleType.displayName)
                labeled("Expression", task.scheduleExpression.isEmpty ? "—" : task.scheduleExpression)
                labeled("launchd Job", launchdLoaded ? "Loaded" : "Not loaded")
                labeled("Retry", "\(task.retryCount)")
            }

            detailSection("Environment") {
                if task.environment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No custom environment variables").foregroundStyle(.secondary)
                } else {
                    Text(task.environment)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            detailSection("Proxy") {
                labeled("Enabled", task.proxyEnabled ? "Yes" : "No")
                if task.proxyEnabled {
                    labeled("HTTP", blank(task.httpProxy))
                    labeled("HTTPS", blank(task.httpsProxy))
                    labeled("SOCKS / ALL_PROXY", blank(task.socksProxy))
                    labeled("NO_PROXY", blank(task.noProxy))
                }
            }

            detailSection("Notifications") {
                labeled("Enabled", task.notificationEnabled ? "Yes" : "No")
                if task.notificationEnabled {
                    labeled("Trigger", task.notificationTrigger.displayName)
                    labeled("Command", blank(task.notificationCommand, fallback: "Default osascript"))
                }
            }
        }
    }

    private var runsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if runs.isEmpty {
                ContentUnavailableView(
                    "No Runs Yet",
                    systemImage: "clock",
                    description: Text("Press Run Now to execute this task.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ForEach(runs, id: \.id) { run in
                    Button {
                        selectedRunID = run.id
                        selectedTab = .logs
                    } label: {
                        HStack {
                            Image(systemName: run.status.systemImage)
                                .foregroundStyle(statusColor(run.status))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(run.startAt.formatted(date: .abbreviated, time: .standard))
                                    .foregroundStyle(.primary)
                                Text(run.status.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let duration = run.duration {
                                Text(String(format: "%.1fs", duration))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            if let code = run.exitCode {
                                Text("exit \(code)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var logsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if runSession.isRunning, runSession.taskID == task.id {
                Label("Live output", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.orange)
                LogViewer(text: runSession.liveOutput, isLive: true)
                    .frame(minHeight: 360)
            } else if let run = selectedRun ?? runs.first {
                HStack {
                    Text(run.startAt.formatted(date: .abbreviated, time: .standard))
                        .font(.headline)
                    Spacer()
                    Text(run.status.displayName)
                        .foregroundStyle(statusColor(run.status))
                }
                LogViewer(text: logService.readLog(for: run), isLive: false)
                    .frame(minHeight: 360)
                if run.stdoutFileName != nil || run.stderrFileName != nil {
                    Text("Also on disk: .out.log / .err.log beside the combined log.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                ContentUnavailableView(
                    "No Logs",
                    systemImage: "doc.text",
                    description: Text("Run the task to capture stdout and stderr.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
    }

    private var selectedRun: TaskRun? {
        if let selectedRunID {
            return runs.first { $0.id == selectedRunID }
        }
        return nil
    }

    private var previewCommand: String {
        (try? AgentService.resolve(task).preview) ?? task.commandPreview
    }

    private func reloadRuns() {
        guard let runService else {
            runs = []
            return
        }
        runs = (try? runService.fetchRuns(for: task.id)) ?? []
        if selectedRunID == nil {
            selectedRunID = runs.first?.id
        }
    }

    private func metaCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.medium))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.semibold))
            content()
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body).textSelection(.enabled)
        }
    }

    private func blank(_ value: String, fallback: String = "—") -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value
    }

    private func statusColor(_ status: RunStatus) -> Color {
        switch status {
        case .running: .orange
        case .success: .green
        case .failed, .timeout: .red
        case .cancelled, .queued: .secondary
        }
    }
}
