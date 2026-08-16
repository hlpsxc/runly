import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalizationStore.self) private var localization
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @State private var screen: MenuBarScreen = .home
    @State private var runSearch = ""

    private enum MenuBarScreen {
        case home
        case runPicker
    }

    var body: some View {
        let _ = localization.revision
        Group {
            switch screen {
            case .home:
                homeContent
            case .runPicker:
                runPickerContent
            }
        }
        .frame(width: 360)
        .onAppear {
            appState.bootstrap()
        }
        .onChange(of: appState.pendingOpenMain) { _, pending in
            guard pending else { return }
            openMainWindow()
            appState.pendingOpenMain = false
        }
    }

    private var state: MenuBarState { appState.menuBarState }
    private var t: LocalizationStore { localization }

    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !state.failedHighlights.isEmpty {
                        failedSection
                    }
                    if !state.runningTasks.isEmpty {
                        runningSection
                    }
                    if !state.recentRuns.isEmpty {
                        recentSection
                    }
                    if !state.upcomingTasks.isEmpty {
                        upcomingSection
                    }
                    if state.totalTasks == 0 {
                        emptyHint
                    }
                }
                .padding(12)
            }
            .frame(maxHeight: 420)

            Divider()
            actions
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.tr("app.name"))
                    .font(.headline)
                Text(state.summaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help(t.tr("settings"))
        }
        .padding(12)
    }

    private var failedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(t.tr("mb.failed_section"))
            ForEach(state.failedHighlights) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: item.status.systemImage)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.taskName)
                                .font(.subheadline.weight(.medium))
                            Text("\(item.status.displayName) · \(RelativeTimeFormatter.string(from: item.at))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let code = item.exitCode {
                                Text(String(format: t.tr("mb.exit_code"), code))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 8) {
                        Button(t.tr("mb.view_logs")) {
                            appState.openRun(taskID: item.taskID, runID: item.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(t.tr("mb.run_again")) {
                            appState.runTask(id: item.taskID)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button(t.tr("mb.dismiss")) {
                            appState.dismissFailed(runID: item.id)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
                .padding(8)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var runningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(t.tr("mb.running_section"))
            ForEach(state.runningTasks) { item in
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.orange)
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                        }
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(String(format: t.tr("mb.running_elapsed"), elapsed(from: item.startedAt, to: context.date)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        appState.stopTask(id: item.id)
                    } label: {
                        Label(t.tr("mb.stop"), systemImage: "stop.fill")
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(t.tr("mb.recent_section"))
            ForEach(state.recentRuns) { item in
                Button {
                    appState.openRun(taskID: item.taskID, runID: item.id)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: item.status.systemImage)
                            .foregroundStyle(statusColor(item.status))
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.taskName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("\(item.status.displayName) · \(RelativeTimeFormatter.string(from: item.at))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarRowButtonStyle())
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(t.tr("mb.up_next_section"))
            ForEach(state.upcomingTasks) { item in
                Button {
                    appState.openTask(item.id)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(upcomingLabel(item.nextRunAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarRowButtonStyle())
            }

            if state.totalTasks > state.upcomingTasks.count {
                Button {
                    appState.openDashboard()
                } label: {
                    Text(t.tr("mb.view_all"))
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarRowButtonStyle())
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
        }
    }

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t.tr("mb.empty_title"))
                .font(.subheadline.weight(.medium))
            Text(t.tr("mb.empty_desc"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            menuButton(t.tr("new_task"), systemImage: "plus") {
                appState.requestNewTask()
            }
            menuButton(t.tr("mb.run_task"), systemImage: "play.fill") {
                runSearch = ""
                screen = .runPicker
            }
            .disabled(appState.allTasks.isEmpty || appState.session.isRunning)

            Divider().padding(.vertical, 4)

            menuButton(t.tr("mb.open_runly"), systemImage: "macwindow") {
                appState.openDashboard()
            }
            menuButton(t.tr("settings"), systemImage: "gearshape") {
                openSettings()
            }

            Divider().padding(.vertical, 4)

            menuButton(t.tr("mb.quit"), systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var runPickerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    screen = .home
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text(t.tr("mb.run_task"))
                    .font(.headline)
                Spacer()
            }
            .padding(12)

            TextField(t.tr("search"), text: $runSearch)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredTasks, id: \.id) { task in
                        Button {
                            appState.runTask(task)
                            screen = .home
                        } label: {
                            HStack {
                                Image(systemName: task.type.systemImage)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.name)
                                        .font(.subheadline.weight(.medium))
                                    Text(task.commandPreview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(MenuBarRowButtonStyle())
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 360)
        }
    }

    private var filteredTasks: [RunlyTask] {
        let query = runSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.allTasks }
        return appState.allTasks.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.command.localizedCaseInsensitiveContains(query)
        }
    }

    private func menuButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(MenuBarRowButtonStyle())
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
    }

    private func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let rem = seconds % 60
        if minutes < 60 { return "\(minutes)m \(rem)s" }
        let hours = minutes / 60
        return "\(hours)h \(minutes % 60)m"
    }

    private func upcomingLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) {
            return String(format: t.tr("mb.today"), time)
        }
        if calendar.isDateInTomorrow(date) {
            return String(format: t.tr("mb.tomorrow"), time)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func statusColor(_ status: RunStatus) -> Color {
        switch status {
        case .success: .green
        case .failed, .timeout: .red
        case .cancelled: .secondary
        case .running: .orange
        case .queued: .secondary
        }
    }
}

/// Hover + press highlight for Menu Bar list/action rows (`.plain` has none).
private struct MenuBarRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuBarRowButton(configuration: configuration)
    }

    private struct MenuBarRowButton: View {
        let configuration: ButtonStyle.Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(fillColor)
                }
                .onHover { hovering in
                    isHovered = hovering
                }
        }

        private var fillColor: Color {
            if configuration.isPressed {
                return Color.accentColor.opacity(0.35)
            }
            if isHovered {
                return Color.primary.opacity(0.08)
            }
            return .clear
        }
    }
}
