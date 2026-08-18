import SwiftUI

struct RunDetailView: View {
    let run: TaskRun
    let logText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                labeled(L10n.tr("status"), run.status.displayName)
                labeled(L10n.tr("exit"), run.exitCode.map(String.init) ?? L10n.tr("em_dash"))
                labeled(L10n.tr("duration"), run.duration.map { String(format: "%.1fs", $0) } ?? L10n.tr("em_dash"))
                labeled(L10n.tr("started"), RelativeTimeFormatter.absolute(run.startAt))
            }

            LogViewer(text: logText, isLive: false)
                .frame(minHeight: 320)
        }
        .padding(20)
        .navigationTitle(L10n.tr("run"))
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
