import AppKit
import SwiftData
import SwiftUI

@main
enum RunlyMain {
    static func main() {
        if ProcessInfo.processInfo.arguments.contains("--run-task") {
            HeadlessRunner.run()
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
            let schema = Schema([RunlyTask.self, TaskRun.self])
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
                .modelContainer(container)
        } label: {
            Image(systemName: appState.menuBarState.iconSystemName)
        }
        .menuBarExtraStyle(.window)

        Window("Runly", id: "main") {
            ContentView()
                .environment(appState)
        }
        .modelContainer(container)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    appState.requestNewTask()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environment(appState)
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
                let schema = Schema([RunlyTask.self, TaskRun.self])
                let configuration = ModelConfiguration(
                    "Runly",
                    schema: schema,
                    isStoredInMemoryOnly: false
                )
                let container = try ModelContainer(for: schema, configurations: [configuration])
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

        // Drive the main run loop so @MainActor work can complete.
        dispatchMain()
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var launchAtLogin = LoginItemService.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch Runly at login", isOn: Binding(
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
                Text("Independent from per-task launchd schedules.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("App", value: "Runly")
                LabeledContent("Tagline", value: "Run anything. Automatically.")
                LabeledContent("Mode", value: "Menu Bar First")
                LabeledContent("Tasks", value: "\(appState.menuBarState.totalTasks)")
            }

            Section("Paths") {
                LabeledContent("Support", value: AppPaths.applicationSupport.path)
                LabeledContent("Logs", value: AppPaths.logsRoot.path)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 320)
        .onAppear {
            launchAtLogin = LoginItemService.isEnabled
        }
    }
}
