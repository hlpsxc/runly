import Foundation

struct CommandSpec: Sendable {
    var executableURL: URL
    var arguments: [String]
    var environment: [String: String]
    var currentDirectoryURL: URL?
    var timeout: TimeInterval
}

struct CommandResult: Sendable {
    var exitCode: Int32
    var timedOut: Bool
    var cancelled: Bool
    var stdout: String
    var stderr: String
    var duration: TimeInterval
}

enum CommandExecutorError: LocalizedError {
    case executableNotFound(String)
    case failedToStart(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let name):
            return "Executable not found: \(name)"
        case .failedToStart(let message):
            return "Failed to start process: \(message)"
        }
    }
}

/// Runs a process with structured arguments (no shell string concatenation).
final class CommandExecutor: @unchecked Sendable {
    private let lock = NSLock()
    private weak var activeProcess: Process?
    private let cancelFlag = CancelFlag()

    func stop() {
        cancelFlag.markCancelled()
        lock.lock()
        let process = activeProcess
        lock.unlock()
        if let process, process.isRunning {
            process.terminate()
        }
    }

    func run(
        _ spec: CommandSpec,
        onStdout: (@Sendable (String) -> Void)? = nil,
        onStderr: (@Sendable (String) -> Void)? = nil
    ) async throws -> CommandResult {
        cancelFlag.reset()

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = spec.executableURL
            process.arguments = spec.arguments
            process.environment = spec.environment
            process.currentDirectoryURL = spec.currentDirectoryURL

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.standardInput = FileHandle.nullDevice

            let stdoutData = LockedData()
            let stderrData = LockedData()
            let timeoutFlag = TimeoutFlag()
            let startedAt = Date()
            let settle = SettleOnce()

            lock.lock()
            activeProcess = process
            lock.unlock()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                stdoutData.append(chunk)
                if let text = String(data: chunk, encoding: .utf8) {
                    onStdout?(text)
                }
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                guard !chunk.isEmpty else { return }
                stderrData.append(chunk)
                if let text = String(data: chunk, encoding: .utf8) {
                    onStderr?(text)
                }
            }

            var timeoutItem: DispatchWorkItem?

            process.terminationHandler = { [weak self] proc in
                let outRemain = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errRemain = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                if !outRemain.isEmpty {
                    stdoutData.append(outRemain)
                    if let text = String(data: outRemain, encoding: .utf8) {
                        onStdout?(text)
                    }
                }
                if !errRemain.isEmpty {
                    stderrData.append(errRemain)
                    if let text = String(data: errRemain, encoding: .utf8) {
                        onStderr?(text)
                    }
                }

                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                timeoutItem?.cancel()

                self?.lock.lock()
                self?.activeProcess = nil
                self?.lock.unlock()

                let result = CommandResult(
                    exitCode: proc.terminationStatus,
                    timedOut: timeoutFlag.timedOut,
                    cancelled: self?.cancelFlag.isCancelled ?? false,
                    stdout: String(data: stdoutData.data, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData.data, encoding: .utf8) ?? "",
                    duration: Date().timeIntervalSince(startedAt)
                )
                settle.finish(continuation, .success(result))
            }

            do {
                try process.run()
            } catch {
                lock.lock()
                activeProcess = nil
                lock.unlock()
                settle.finish(
                    continuation,
                    .failure(CommandExecutorError.failedToStart(error.localizedDescription))
                )
                return
            }

            if cancelFlag.isCancelled {
                process.terminate()
            }

            if spec.timeout > 0 {
                let item = DispatchWorkItem { [weak self] in
                    timeoutFlag.markTimedOut()
                    if process.isRunning {
                        process.terminate()
                    }
                    _ = self
                }
                timeoutItem = item
                DispatchQueue.global().asyncAfter(deadline: .now() + spec.timeout, execute: item)
            }
        }
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }
}

private final class TimeoutFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var timedOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func markTimedOut() {
        lock.lock()
        value = true
        lock.unlock()
    }
}

private final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func reset() {
        lock.lock()
        value = false
        lock.unlock()
    }

    func markCancelled() {
        lock.lock()
        value = true
        lock.unlock()
    }
}

private final class SettleOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var settled = false

    func finish(
        _ continuation: CheckedContinuation<CommandResult, Error>,
        _ result: Result<CommandResult, Error>
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard !settled else { return }
        settled = true
        continuation.resume(with: result)
    }
}
