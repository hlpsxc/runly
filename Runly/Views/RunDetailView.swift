import SwiftUI

struct RunDetailView: View {
    let run: TaskRun
    let logText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                labeled("Status", run.status.displayName)
                labeled("Exit", run.exitCode.map(String.init) ?? "—")
                labeled("Duration", run.duration.map { String(format: "%.1fs", $0) } ?? "—")
                labeled("Started", run.startAt.formatted(date: .abbreviated, time: .standard))
            }

            LogViewer(text: logText, isLive: false)
                .frame(minHeight: 320)
        }
        .padding(20)
        .navigationTitle("Run")
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
