import AppKit
import SwiftData
import SwiftUI

@main
enum RunlyMain {
    static func main() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--run-task") {
            HeadlessRunner.run()
        } else if args.contains("--cli") || args.dropFirst().first == "cli" {
            RunlyCLI.run(arguments: args)
        } else {
            RunlyApp.main()
        }
    }
}

struct RunlyApp: App {
    @State private var appState: AppState
    private let container: ModelContainer

    init() {
        do {
            let schema = RunlyStore.schema
            let configuration = ModelConfiguration(
                "Runly",
                schema: schema,
                isStoredInMemoryOnly: false
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            self.container = container
            _appState = State(initialValue: AppState(container: container))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .environment(LocalizationStore.shared)
                .environment(\.locale, LocalizationStore.shared.language.locale)
                .id(LocalizationStore.shared.revision)
                .modelContainer(container)
        } label: {
            Image(systemName: appState.menuBarState.iconSystemName)
        }
        .menuBarExtraStyle(.window)

        Window("Runly", id: "main") {
            ContentView()
                .environment(appState)
                .environment(LocalizationStore.shared)
                .environment(\.locale, LocalizationStore.shared.language.locale)
                .id(LocalizationStore.shared.revision)
        }
        .modelContainer(container)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.tr("new_task")) {
                    appState.requestNewTask()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
                .environment(LocalizationStore.shared)
                .environment(\.locale, LocalizationStore.shared.language.locale)
                .id(LocalizationStore.shared.revision)
        }
    }
}

/// launchd entry: `Runly --run-task <uuid>`
enum HeadlessRunner {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--run-task"),
              args.indices.contains(index + 1),
              let taskID = UUID(uuidString: args[index + 1]) else {
            fputs("usage: Runly --run-task <uuid>\n", stderr)
            exit(2)
        }

        Task { @MainActor in
            var code: Int32 = 0
            do {
                let container = try RunlyStore.makeContainer()
                let context = ModelContext(container)
                let session = RunSession()
                let logs = LogService()
                let service = RunService(modelContext: context, logService: logs, session: session)
                try await service.runHeadless(taskID: taskID)
            } catch {
                NSLog("Runly headless run failed: %@", error.localizedDescription)
                code = 1
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            exit(code)
        }

        dispatchMain()
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalizationStore.self) private var localization
    @State private var launchAtLogin = LoginItemService.isEnabled
    @State private var loginError: String?
    @State private var editingTemplate: TemplateEditorState?

    var body: some View {
        let _ = localization.revision
        let t = localization
        Form {
            Section(t.tr("settings.general")) {
                Picker(t.tr("language"), selection: Binding(
                    get: { localization.language },
                    set: { localization.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.pickerLabel).tag(language)
                    }
                }
                Text(t.tr("language.footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(t.tr("settings.launch_at_login"), isOn: Binding(
                    get: { launchAtLogin },
                    set: { enabled in
                        do {
                            try LoginItemService.setEnabled(enabled)
                            launchAtLogin = LoginItemService.isEnabled
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = LoginItemService.isEnabled
                        }
                    }
                ))
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text(t.tr("settings.launch_at_login.footer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if appState.notificationTemplates.isEmpty {
                    Text(t.tr("notif_template.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.notificationTemplates, id: \.id) { template in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(.body.weight(.medium))
                                Text(template.preview)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            Button(t.tr("edit")) {
                                editingTemplate = .edit(template)
                            }
                            .buttonStyle(.borderless)
                        }
                        .contextMenu {
                            Button(t.tr("edit")) {
                                editingTemplate = .edit(template)
                            }
                            Button(t.tr("delete"), role: .destructive) {
                                appState.deleteNotificationTemplate(template)
                            }
                        }
                    }
                }

                Button {
                    editingTemplate = .create
                } label: {
                    Label(t.tr("notif_template.add"), systemImage: "plus")
                }
            } header: {
                Text(t.tr("notif_template.section"))
            } footer: {
                Text(t.tr("notif_template.footer"))
            }

            Section(t.tr("settings.about")) {
                LabeledContent("App", value: "Runly")
                Text(t.tr("app.tagline"))
                    .foregroundStyle(.secondary)
                LabeledContent(t.tr("settings.mode"), value: t.tr("settings.mode.value"))
                LabeledContent(t.tr("settings.tasks"), value: "\(appState.menuBarState.totalTasks)")
            }

            Section(t.tr("settings.paths")) {
                LabeledContent(t.tr("settings.support"), value: AppPaths.applicationSupport.path)
                LabeledContent(t.tr("settings.logs"), value: AppPaths.logsRoot.path)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 520)
        .onAppear {
            launchAtLogin = LoginItemService.isEnabled
            appState.refresh()
        }
        .sheet(item: $editingTemplate) { state in
            NotificationTemplateEditorSheet(state: state) {
                editingTemplate = nil
            }
            .environment(appState)
            .environment(localization)
        }
    }
}

private enum TemplateEditorState: Identifiable {
    case create
    case edit(NotificationTemplate)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let template): template.id.uuidString
        }
    }
}

private struct NotificationTemplateEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(LocalizationStore.self) private var localization
    @Environment(\.dismiss) private var dismiss

    let state: TemplateEditorState
    var onDone: () -> Void

    @State private var name: String = ""
    @State private var command: String = ""

    var body: some View {
        let t = localization
        NavigationStack {
            Form {
                TextField(t.tr("name"), text: $name)
                TextField(
                    "",
                    text: $command,
                    prompt: Text(t.tr("notification.cmd_placeholder")),
                    axis: .vertical
                )
                .font(.system(.body, design: .monospaced))
                .lineLimit(3...8)

                if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(t.tr("notification.vars"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(t.tr("notif_template.command_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.tr("cancel")) {
                        onDone()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t.tr("save")) {
                        save()
                        onDone()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(width: 480, height: 340)
        .onAppear {
            switch state {
            case .create:
                name = ""
                command = ""
            case .edit(let template):
                name = template.name
                command = template.command
            }
        }
    }

    private var title: String {
        switch state {
        case .create: localization.tr("notif_template.add")
        case .edit: localization.tr("notif_template.edit")
        }
    }

    private func save() {
        switch state {
        case .create:
            appState.createNotificationTemplate(name: name, command: command)
        case .edit(let template):
            appState.updateNotificationTemplate(template, name: name, command: command)
        }
    }
}
