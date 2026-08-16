import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    @Environment(LocalizationStore.self) private var localization

    var body: some View {
        let _ = localization.revision
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
                        if viewModel.isRunning(task) {
                            Button(localization.tr("stop")) {
                                viewModel.stop(task)
                            }
                        }
                        Button(task.enabled ? localization.tr("disable") : localization.tr("enable")) {
                            viewModel.toggleEnabled(task)
                        }
                        Button(localization.tr("delete"), role: .destructive) {
                            viewModel.delete(task)
                        }
                    }
            }
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
        .overlay {
            if viewModel.filteredTasks.isEmpty {
                ContentUnavailableView(
                    localization.tr("no_matching"),
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(localization.tr("no_matching.desc"))
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
