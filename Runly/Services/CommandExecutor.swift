import Foundation

struct CommandSpec: Sendable {
    var executableURL: URL
    var arguments: [String]
    var environment: [String: String]
    var currentDirectoryURL: URL?
    var timeout: TimeInterval
    var runInITerm: Bool = false
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
    private var iTermSession: ITermRunner.Session?
    private let cancelFlag = CancelFlag()

    /// True while a child `Process` is alive, or an iTerm run is still owned by this executor.
    var hasLiveProcess: Bool {
        lock.lock()
        defer { lock.unlock() }
        if activeProcess?.isRunning == true { return true }
        // Keep the run alive until `runInITerm` returns — the wrapper PID can
        // vanish (iTerm SIGHUP) before the exit file is written.
        return iTermSession != nil
    }

    func stop() {
        cancelFlag.markCancelled()
        lock.lock()
        let process = activeProcess
        let iTerm = iTermSession
        lock.unlock()
        iTerm?.markCancelled()
        guard let process, process.isRunning else { return }

        // SIGTERM first; escalate to SIGKILL if the process ignores it.
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak process] in
            guard let process, process.isRunning else { return }
            kill(process.processIdentifier, SIGKILL)
        }
    }

    func run(
        _ spec: CommandSpec,
        onStdout: (@Sendable (String) -> Void)? = nil,
        onStderr: (@Sendable (String) -> Void)? = nil
    ) async throws -> CommandResult {
        cancelFlag.reset()

        if spec.runInITerm, ITermRunSettings.isAvailable {
            return try await runInITerm(spec, onStdout: onStdout, onStderr: onStderr)
        }

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

            let finish: @Sendable (Process) -> Void = { [weak self] proc in
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

            process.terminationHandler = { proc in
                finish(proc)
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

            // If the child dies without a reliable terminationHandler callback,
            // force-complete so RunSession / SwiftData cannot stay on "running".
            DispatchQueue.global(qos: .utility).async {
                while !settle.isSettled {
                    Thread.sleep(forTimeInterval: 1.0)
                    if settle.isSettled { return }
                    if process.isRunning { continue }
                    // Brief grace so the normal handler can win the race.
                    Thread.sleep(forTimeInterval: 0.75)
                    if settle.isSettled { return }
                    finish(process)
                    return
                }
            }
        }
    }

    private func runInITerm(
        _ spec: CommandSpec,
        onStdout: (@Sendable (String) -> Void)?,
        onStderr: (@Sendable (String) -> Void)?
    ) async throws -> CommandResult {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("RunlyITerm", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        if dir.path.contains(where: { $0.isWhitespace || $0 == "\"" || $0 == "'" }) {
            throw CommandExecutorError.failedToStart("iTerm run directory path is not safe: \(dir.path)")
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let session = ITermRunner.Session(directory: dir)
        lock.lock()
        iTermSession = session
        lock.unlock()
        defer {
            lock.lock()
            iTermSession = nil
            lock.unlock()
        }
        return try await ITermRunner.run(
            spec,
            session: session,
            onStdout: onStdout,
            onStderr: onStderr
        )
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

    var isSettled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return settled
    }

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
