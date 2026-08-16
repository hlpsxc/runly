import Foundation
import SwiftData

/// Reusable notification command template shared by multiple tasks.
@Model
final class NotificationTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Shell / argv command with `{{task_name}}` etc. Empty = built-in macOS notification.
    var command: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        command: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var preview: String {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.tr("notification.default") : trimmed
    }
}
