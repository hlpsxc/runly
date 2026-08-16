import Foundation
import SwiftData

/// Metadata for a single execution. Full stdout/stderr live on disk (Phase 3).
@Model
final class TaskRun {
    @Attribute(.unique) var id: UUID
    var taskID: UUID
    var startAt: Date
    var endAt: Date?
    var statusRaw: String
    var exitCode: Int?
    var logFileName: String?
    var stdoutFileName: String?
    var stderrFileName: String?
    var duration: Double?

    var status: RunStatus {
        get { RunStatus(rawValue: statusRaw) ?? .queued }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        taskID: UUID,
        startAt: Date = .now,
        endAt: Date? = nil,
        status: RunStatus = .queued,
        exitCode: Int? = nil,
        logFileName: String? = nil,
        stdoutFileName: String? = nil,
        stderrFileName: String? = nil,
        duration: Double? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.startAt = startAt
        self.endAt = endAt
        self.statusRaw = status.rawValue
        self.exitCode = exitCode
        self.logFileName = logFileName
        self.stdoutFileName = stdoutFileName
        self.stderrFileName = stderrFileName
        self.duration = duration
    }
}
