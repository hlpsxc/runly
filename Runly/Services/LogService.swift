import Foundation

struct LogHandle: Sendable {
    let fileName: String
    let stdoutFileName: String
    let stderrFileName: String
    let fileURL: URL
}

enum LogStream: String, Sendable {
    case out
    case err
    case meta
}

final class LogService: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let lock = NSLock()
    private var openCombined: [UUID: FileHandle] = [:]
    private var openStdout: [UUID: FileHandle] = [:]
    private var openStderr: [UUID: FileHandle] = [:]

    func beginRunLog(taskID: UUID, runID: UUID, startedAt: Date = .now) throws -> LogHandle {
        let directory = AppPaths.logsDirectory(for: taskID)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let stamp = "\(formatter.string(from: startedAt))-\(runID.uuidString.prefix(8))"
        let fileName = "\(stamp).log"
        let stdoutName = "\(stamp).out.log"
        let stderrName = "\(stamp).err.log"

        let combinedURL = directory.appendingPathComponent(fileName)
        let stdoutURL = directory.appendingPathComponent(stdoutName)
        let stderrURL = directory.appendingPathComponent(stderrName)

        for url in [combinedURL, stdoutURL, stderrURL] {
            fileManager.createFile(atPath: url.path, contents: nil)
        }

        let combined = try FileHandle(forWritingTo: combinedURL)
        let stdout = try FileHandle(forWritingTo: stdoutURL)
        let stderr = try FileHandle(forWritingTo: stderrURL)

        lock.lock()
        openCombined[runID] = combined
        openStdout[runID] = stdout
        openStderr[runID] = stderr
        lock.unlock()

        return LogHandle(
            fileName: fileName,
            stdoutFileName: stdoutName,
            stderrFileName: stderrName,
            fileURL: combinedURL
        )
    }

    func append(runID: UUID, stream: LogStream, text: String) {
        guard let data = text.data(using: .utf8) else { return }
        lock.lock()
        let combined = openCombined[runID]
        let stdout = openStdout[runID]
        let stderr = openStderr[runID]
        lock.unlock()

        switch stream {
        case .out:
            stdout?.write(data)
            if let marker = "[out] ".data(using: .utf8) {
                combined?.write(marker)
            }
            combined?.write(data)
        case .err:
            stderr?.write(data)
            if let marker = "[err] ".data(using: .utf8) {
                combined?.write(marker)
            }
            combined?.write(data)
        case .meta:
            combined?.write(data)
        }
    }

    func append(runID: UUID, text: String) {
        append(runID: runID, stream: .meta, text: text)
    }

    func endRunLog(runID: UUID) {
        lock.lock()
        let handles = [
            openCombined.removeValue(forKey: runID),
            openStdout.removeValue(forKey: runID),
            openStderr.removeValue(forKey: runID)
        ]
        lock.unlock()
        for handle in handles {
            try? handle?.synchronize()
            try? handle?.close()
        }
    }

    func readLog(taskID: UUID, fileName: String) -> String {
        let url = AppPaths.logsDirectory(for: taskID).appendingPathComponent(fileName)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func readLog(for run: TaskRun) -> String {
        guard let fileName = run.logFileName else { return "" }
        return readLog(taskID: run.taskID, fileName: fileName)
    }

    func readStdout(for run: TaskRun) -> String {
        guard let name = run.stdoutFileName else { return "" }
        return readLog(taskID: run.taskID, fileName: name)
    }

    func readStderr(for run: TaskRun) -> String {
        guard let name = run.stderrFileName else { return "" }
        return readLog(taskID: run.taskID, fileName: name)
    }

    func deleteLogs(for taskID: UUID) {
        let url = AppPaths.logsDirectory(for: taskID)
        try? fileManager.removeItem(at: url)
    }
}
