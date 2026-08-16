import Foundation

enum TaskType: String, Codable, CaseIterable, Identifiable {
    case command
    case script
    case agent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .command: L10n.tr("type.command")
        case .script: L10n.tr("type.script")
        case .agent: L10n.tr("type.agent")
        }
    }

    var systemImage: String {
        switch self {
        case .command: "terminal"
        case .script: "doc.text"
        case .agent: "sparkles"
        }
    }
}
