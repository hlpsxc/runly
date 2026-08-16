import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } content: {
            DashboardView(viewModel: viewModel)
                .navigationTitle(viewModel.filter.title)
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $viewModel.searchText, prompt: "Search tasks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.editorRoute = .create
                } label: {
                    Label("New Task", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: [.command])
                .help("New Task")
            }
        }
        .onAppear {
            appState.bootstrap()
            viewModel.bind(appState: appState)
            applyPendingFocus()
        }
        .onChange(of: appState.pendingFocusTaskID) { _, _ in
            applyPendingFocus()
        }
        .onChange(of: appState.menuBarState.runningCount) { _, _ in
            viewModel.refresh()
        }
        .sheet(item: Binding(
            get: { appState.editorRoute },
            set: { appState.editorRoute = $0 }
        )) { route in
            TaskEditorView(route: route) {
                appState.refresh()
                viewModel.refresh()
                if case .create = route {
                    viewModel.select(viewModel.filteredTasks.first)
                }
            }
            .frame(minWidth: 560, minHeight: 680)
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: {
                    appState.errorMessage != nil
                        || viewModel.errorMessage != nil
                        || appState.launchdErrorMessage != nil
                },
                set: { if !$0 {
                    appState.errorMessage = nil
                    viewModel.errorMessage = nil
                    appState.launchdErrorMessage = nil
                } }
            )
        ) {
            Button("OK", role: .cancel) {
                appState.errorMessage = nil
                viewModel.errorMessage = nil
                appState.launchdErrorMessage = nil
            }
        } message: {
            Text(appState.errorMessage ?? viewModel.errorMessage ?? appState.launchdErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let task = viewModel.selectedTask {
            TaskDetailView(
                task: task,
                runSession: appState.session,
                logService: appState.logService,
                runService: appState.runService,
                onEdit: { appState.editorRoute = .edit(taskID: task.id) },
                onDelete: {
                    viewModel.delete(task)
                    appState.refresh()
                },
                onToggleEnabled: {
                    viewModel.toggleEnabled(task)
                    appState.refresh()
                },
                onRunNow: {
                    viewModel.runNow(task)
                },
                onRefresh: {
                    viewModel.refresh()
                    appState.refresh()
                },
                initialRunID: appState.pendingFocusRunID,
                onConsumeFocusRun: {
                    appState.pendingFocusRunID = nil
                }
            )
        } else if viewModel.filteredTasks.isEmpty {
            ContentUnavailableView {
                Label("No Tasks", systemImage: "terminal")
            } description: {
                Text("Create a task to schedule commands, scripts, or AI agents.\nRun anything. Automatically.")
                    .multilineTextAlignment(.center)
            } actions: {
                Button("New Task") {
                    appState.editorRoute = .create
                }
                .keyboardShortcut(.defaultAction)
            }
        } else {
            ContentUnavailableView(
                "Select a Task",
                systemImage: "sidebar.left",
                description: Text("Choose a task from the list to inspect details.")
            )
        }
    }

    private func applyPendingFocus() {
        guard let taskID = appState.pendingFocusTaskID else { return }
        viewModel.refresh()
        if let task = viewModel.tasks.first(where: { $0.id == taskID }) {
            viewModel.select(task)
        }
        // Keep pendingFocusRunID for TaskDetailView; clear task focus token.
        appState.pendingFocusTaskID = nil
    }
}

enum EditorRoute: Identifiable {
    case create
    case edit(taskID: UUID)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let taskID): "edit-\(taskID.uuidString)"
        }
    }
}
