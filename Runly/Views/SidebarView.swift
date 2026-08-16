import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        List(selection: $viewModel.filter) {
            Section("Library") {
                ForEach(SidebarFilter.allCases) { filter in
                    Label {
                        HStack {
                            Text(filter.title)
                            Spacer()
                            Text("\(viewModel.count(for: filter))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    } icon: {
                        Image(systemName: filter.systemImage)
                    }
                    .tag(filter)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Runly")
                    .font(.headline)
                Text("Run anything. Automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .onChange(of: viewModel.filter) { _, _ in
            if let selected = viewModel.selectedTask, viewModel.filter.matches(selected) {
                return
            }
            viewModel.select(viewModel.filteredTasks.first)
        }
    }
}
