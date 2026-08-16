import Foundation
import SwiftData

enum RunlyStore {
    static let schema = Schema([RunlyTask.self, TaskRun.self, NotificationTemplate.self])

    static func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Runly",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

extension Notification.Name {
    /// Posted by `Runly --cli stop` so a running GUI instance can stop an in-process run.
    static let runlyStopTask = Notification.Name("app.runly.Runly.stopTask")
    static let runlyRefresh = Notification.Name("app.runly.Runly.refresh")
}
