import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedTaskID },
            set: { id in
                viewModel.selectedTaskID = id
            }
        )) {
            ForEach(viewModel.filteredTasks, id: \.id) { task in
                TaskRowView(task: task)
                    .tag(task.id)
                    .contextMenu {
                        Button(task.enabled ? "Disable" : "Enable") {
                            viewModel.toggleEnabled(task)
                        }
                        Button("Delete", role: .destructive) {
                            viewModel.delete(task)
                        }
                    }
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
        .overlay {
            if viewModel.filteredTasks.isEmpty {
                ContentUnavailableView(
                    "No Matching Tasks",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try another filter or create a new task.")
                )
            }
        }
        .onAppear {
            if viewModel.selectedTask == nil {
                viewModel.select(viewModel.filteredTasks.first)
            }
        }
        .onChange(of: viewModel.filteredTasks.map(\.id)) { _, ids in
            if let selected = viewModel.selectedTaskID, ids.contains(selected) {
                return
            }
            viewModel.select(viewModel.filteredTasks.first)
        }
    }
}
