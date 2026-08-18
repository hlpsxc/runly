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
    var onSetEnabled: ((Bool) -> Void)? = nil
    var onRunNow: () -> Void
    var onStop: () -> Void
    var onRefresh: () -> Void
    var initialRunID: UUID? = nil
    var onConsumeFocusRun: (() -> Void)? = nil

    @Environment(AppState.self) private var appState
    @State private var selectedTab: DetailTab = .overview
    @State private var runs: [TaskRun] = []
    @State private var selectedRunID: UUID?

    private var isThisTaskRunning: Bool {
        (runSession.isRunning && runSession.taskID == task.id)
            || task.lastRunStatus == .running
    }

    private enum DetailTab: String, CaseIterable, Identifiable {
        case overview
        case runs
        case logs

        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: L10n.tr("overview")
            case .runs: L10n.tr("runs")
            case .logs: L10n.tr("logs")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 12)

            Picker("", selection: $selectedTab) {
                ForEach(DetailTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
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
                Menu {
                    Button(L10n.tr("delete"), role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            reloadRuns()
            if let initialRunID {
                selectedRunID = initialRunID
                selectedTab = .logs
                onConsumeFocusRun?()
            }
        }
        .onChange(of: task.id) { _, _ in
            selectedTab = .overview
            reloadRuns()
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
            HStack(alignment: .center, spacing: 16) {
                Text(task.name)
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(0)

                // Keep clear of the trailing toolbar (⋯); title yields space first.
                HStack(spacing: 8) {
                    if isThisTaskRunning {
                        Button {
                            onStop()
                            selectedTab = .logs
                        } label: {
                            Label(L10n.tr("stop"), systemImage: "stop.fill")
                        }
                        .tint(.red)
                        .keyboardShortcut(".", modifiers: [.command])
                    } else {
                        Button {
                            onRunNow()
                            selectedTab = .logs
                        } label: {
                            Label(L10n.tr("run_now"), systemImage: "play.fill")
                        }
                        .disabled(runSession.isRunning)
                        .keyboardShortcut("r", modifiers: [.command])
                    }

                    Button(L10n.tr("edit"), action: onEdit)

                    Toggle(task.enabled ? L10n.tr("enabled") : L10n.tr("disabled"), isOn: Binding(
                        get: { task.enabled },
                        set: { newValue in
                            guard newValue != task.enabled else { return }
                            if let onSetEnabled {
                                onSetEnabled(newValue)
                            } else {
                                onToggleEnabled()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel(task.enabled ? L10n.tr("enabled") : L10n.tr("disabled"))
                    Text(task.enabled ? L10n.tr("enabled") : L10n.tr("disabled"))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .padding(.trailing, 36)
            }

            HStack(spacing: 12) {
                Label(task.type.displayName, systemImage: task.type.systemImage)
                Text("·").foregroundStyle(.tertiary)
                Text(task.scheduleSummary)
                if runSession.isRunning, runSession.taskID == task.id {
                    Text("·").foregroundStyle(.tertiary)
                    Label(L10n.tr("status.running"), systemImage: "circle.fill")
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
                metaCard(title: L10n.tr("next_run"), value: RelativeTimeFormatter.absolute(task.nextRunAt))
                metaCard(title: L10n.tr("last_run"), value: RelativeTimeFormatter.absolute(task.lastRunAt))
                metaCard(
                    title: L10n.tr("status"),
                    value: task.lastRunStatus?.displayName
                        ?? (task.enabled ? L10n.tr("status.ready") : L10n.tr("disabled"))
                )
                metaCard(
                    title: L10n.tr("duration"),
                    value: task.lastRunDuration.map { String(format: "%.1fs", $0) }
                        ?? "—"
                )
                metaCard(title: L10n.tr("timeout"), value: "\(task.timeout)s")
                metaCard(title: L10n.tr("retry"), value: "\(task.retryCount)")
            }

            detailSection(L10n.tr("command")) {
                Text("$ \(previewCommand)")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                if !task.workingDirectory.isEmpty {
                    labeled(L10n.tr("working_directory"), task.workingDirectory)
                }
                if task.type == .agent {
                    labeled(L10n.tr("agent_provider"), task.agentProvider.displayName)
                    if !task.agentPrompt.isEmpty {
                        labeled(L10n.tr("prompt"), task.agentPrompt)
                    }
                }
            }

            detailSection(L10n.tr("schedule")) {
                labeled(L10n.tr("type"), task.scheduleType.displayName)
                labeled(L10n.tr("expression"), task.scheduleExpression.isEmpty ? "—" : task.scheduleExpression)
                labeled(L10n.tr("retry"), "\(task.retryCount)")
            }

            detailSection(L10n.tr("environment")) {
                if task.environment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(L10n.tr("env.empty")).foregroundStyle(.secondary)
                } else {
                    Text(task.environment)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            detailSection(L10n.tr("proxy")) {
                labeled(L10n.tr("enabled"), task.proxyEnabled ? L10n.tr("yes") : L10n.tr("no"))
                if task.proxyEnabled {
                    labeled(L10n.tr("http"), blank(task.httpProxy))
                    labeled(L10n.tr("https"), blank(task.httpsProxy))
                    labeled(L10n.tr("socks"), blank(task.socksProxy))
                    labeled(L10n.tr("no_proxy"), blank(task.noProxy))
                }
            }

            detailSection(L10n.tr("notifications")) {
                labeled(L10n.tr("enabled"), task.notificationEnabled ? L10n.tr("yes") : L10n.tr("no"))
                if task.notificationEnabled {
                    labeled(L10n.tr("trigger"), task.notificationTrigger.displayName)
                    if let template = appState.notificationTemplate(id: task.notificationTemplateID) {
                        labeled(L10n.tr("notif_template.picker"), template.name)
                        labeled(L10n.tr("notification_command"), template.preview)
                    } else {
                        labeled(
                            L10n.tr("notification_command"),
                            blank(task.notificationCommand, fallback: L10n.tr("notification.default"))
                        )
                    }
                }
            }
        }
    }

    private var runsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if runs.isEmpty {
                ContentUnavailableView(
                    L10n.tr("no_runs"),
                    systemImage: "clock",
                    description: Text(L10n.tr("no_runs.desc"))
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
                                Text(RelativeTimeFormatter.absolute(run.startAt))
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
            if isThisTaskRunning {
                HStack {
                    Label(L10n.tr("live_output"), systemImage: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button {
                        onStop()
                    } label: {
                        Label(L10n.tr("stop"), systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                }
                if runSession.isRunning, runSession.taskID == task.id {
                    LogViewer(text: runSession.liveOutput, isLive: true)
                        .frame(minHeight: 360)
                } else if let run = selectedRun ?? runs.first {
                    LogViewer(text: logService.readLog(for: run), isLive: false)
                        .frame(minHeight: 360)
                } else {
                    ContentUnavailableView(
                        L10n.tr("waiting_output"),
                        systemImage: "hourglass",
                        description: Text(L10n.tr("stop.hint"))
                    )
                    .frame(minHeight: 200)
                }
            } else if let run = selectedRun ?? runs.first {
                HStack {
                    Text(RelativeTimeFormatter.absolute(run.startAt))
                        .font(.headline)
                    Spacer()
                    Text(run.status.displayName)
                        .foregroundStyle(statusColor(run.status))
                }
                LogViewer(text: logService.readLog(for: run), isLive: false)
                    .frame(minHeight: 360)
                if run.stdoutFileName != nil || run.stderrFileName != nil {
                    Text(L10n.tr("logs.disk_hint"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                ContentUnavailableView(
                    L10n.tr("no_logs"),
                    systemImage: "doc.text",
                    description: Text(L10n.tr("no_logs.desc"))
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
