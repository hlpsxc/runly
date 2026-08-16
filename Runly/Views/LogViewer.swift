import AppKit
import SwiftUI

struct LogViewer: View {
    let text: String
    var isLive: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text.isEmpty ? L10n.tr("waiting_output") : text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .id("log-bottom")
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .onChange(of: text) { _, _ in
                guard isLive else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("log-bottom", anchor: .bottom)
                }
            }
        }
    }
}
