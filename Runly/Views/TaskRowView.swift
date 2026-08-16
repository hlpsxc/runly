import SwiftUI

struct TaskRowView: View {
    let task: RunlyTask

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: task.type.systemImage)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(task.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                statusBadge
            }

            Text(task.scheduleSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                if let status = task.lastRunStatus {
                    Label(status.displayName, systemImage: status.systemImage)
                        .font(.caption2)
                        .foregroundStyle(statusColor(status))
                } else {
                    Text(task.enabled ? L10n.tr("not_run_yet") : L10n.tr("disabled"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                Text(RelativeTimeFormatter.string(from: task.lastRunAt, placeholder: ""))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .opacity(task.enabled ? 1 : 0.55)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if !task.enabled {
            Image(systemName: "pause.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
        } else if task.lastRunStatus == .running {
            Image(systemName: "circle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 7))
        }
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
