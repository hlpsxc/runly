import Foundation
import SwiftData

@MainActor
final class NotificationTemplateService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [NotificationTemplate] {
        let descriptor = FetchDescriptor<NotificationTemplate>(
            sortBy: [
                SortDescriptor(\NotificationTemplate.name, order: .forward),
                SortDescriptor(\NotificationTemplate.updatedAt, order: .reverse)
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    func template(id: UUID) throws -> NotificationTemplate? {
        let all = try fetchAll()
        return all.first { $0.id == id }
    }

    @discardableResult
    func create(name: String, command: String) throws -> NotificationTemplate {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = NotificationTemplate(
            name: trimmedName.isEmpty ? L10n.tr("notif_template.untitled") : trimmedName,
            command: command
        )
        modelContext.insert(template)
        try modelContext.save()
        return template
    }

    func update(_ template: NotificationTemplate, name: String, command: String) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        template.name = trimmedName.isEmpty ? L10n.tr("notif_template.untitled") : trimmedName
        template.command = command
        template.updatedAt = .now
        try modelContext.save()
    }

    func delete(_ template: NotificationTemplate) throws {
        let id = template.id
        // Detach tasks that referenced this template.
        let tasks = try modelContext.fetch(FetchDescriptor<RunlyTask>())
        for task in tasks where task.notificationTemplateID == id {
            task.notificationTemplateID = nil
        }
        modelContext.delete(template)
        try modelContext.save()
    }
}
