import Foundation

enum TaskType: String, Codable, CaseIterable, Identifiable {
    case command
    case script
    case agent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .command: "Command"
        case .script: "Script"
        case .agent: "Agent"
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
