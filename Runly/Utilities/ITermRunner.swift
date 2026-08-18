import Foundation

enum ITermRunSettings {
    private static let storageKey = "runly.runTasksInITerm"

    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: "/Applications/iTerm.app")
            || FileManager.default.fileExists(atPath: "/Applications/iTerm2.app")
    }

    /// When enabled, task commands run inside iTerm so they inherit iTerm's TCC rights.
    static var isEnabled: Bool {
        get {
            guard isAvailable else { return false }
            if UserDefaults.standard.object(forKey: storageKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: storageKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }
}

/// Launches the command as an iTerm session (child of iTerm), then waits for exit.
enum ITermRunner {
    final class Session: @unchecked Sendable {
        let directory: URL
        let token: String
        let pidFile: URL
        let exitFile: URL
        let outFile: URL
        let errFile: URL
        private let lock = NSLock()
        private var cancelled = false
        private var timedOut = false
        private var windowID: Int?
        private var launchedITerm = false

        init(directory: URL) {
            self.directory = directory
            token = directory.lastPathComponent
            pidFile = directory.appendingPathComponent("pid")
            exitFile = directory.appendingPathComponent("exit")
            outFile = directory.appendingPathComponent("out.log")
            errFile = directory.appendingPathComponent("err.log")
        }

        var isCancelled: Bool {
            lock.lock(); defer { lock.unlock() }
            return cancelled
        }

        var didTimeOut: Bool {
            lock.lock(); defer { lock.unlock() }
            return timedOut
        }

        func markCancelled() {
            lock.lock(); cancelled = true; lock.unlock()
            terminate()
        }

        func markTimedOut() {
            lock.lock(); timedOut = true; lock.unlock()
            terminate()
        }

        func setWindow(id: Int?, launchedITerm: Bool) {
            lock.lock()
            windowID = id
            self.launchedITerm = launchedITerm
            lock.unlock()
        }

        /// True until this Swift session is released. PID can vanish (iTerm SIGHUP)
        /// while Runly is still waiting for the exit file.
        var isRunning: Bool {
            if FileManager.default.fileExists(atPath: exitFile.path) {
                if let pid = readPID(), pid > 0 {
                    return kill(pid, 0) == 0
                }
                return false
            }
            if let pid = readPID(), pid > 0, kill(pid, 0) == 0 {
                return true
            }
            // No exit file yet: still in flight even if the wrapper PID is gone.
            return true
        }

        func terminate() {
            guard let pid = readPID(), pid > 0 else { return }
            _ = killpg(pid, SIGTERM)
            kill(pid, SIGTERM)
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                _ = killpg(pid, SIGKILL)
                kill(pid, SIGKILL)
            }
        }

        func closeWindow() {
            lock.lock()
            let id = windowID
            let quitIfEmpty = launchedITerm
            lock.unlock()
            Self.closeITermWindow(id: id, sessionToken: token, quitIfEmpty: quitIfEmpty)
        }

        private func readPID() -> pid_t? {
            guard let text = try? String(contentsOf: pidFile, encoding: .utf8) else { return nil }
            return pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        private static func closeITermWindow(id: Int?, sessionToken: String, quitIfEmpty: Bool) {
            var lines: [String] = ["tell application \"iTerm\""]
            if let id {
                lines.append("  try")
                lines.append("    close window id \(id)")
                lines.append("  end try")
            }
            lines.append("  try")
            lines.append("    repeat with w in windows")
            lines.append("      try")
            lines.append("        if name of current session of w contains \(appleQuote("Runly-\(sessionToken)")) then")
            lines.append("          close w")
            lines.append("        end if")
            lines.append("      end try")
            lines.append("    end repeat")
            lines.append("  end try")
            if quitIfEmpty {
                lines.append("  try")
                lines.append("    if (count of windows) is 0 then quit")
                lines.append("  end try")
            }
            lines.append("end tell")
            let script = lines.joined(separator: "\n")
            let osa = Process()
            osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            osa.arguments = ["-e", script]
            osa.standardOutput = FileHandle.nullDevice
            osa.standardError = FileHandle.nullDevice
            do {
                try osa.run()
                osa.waitUntilExit()
            } catch {
                NSLog("Runly failed to close iTerm window: %@", error.localizedDescription)
            }
        }
    }

    static func run(
        _ spec: CommandSpec,
        session: Session,
        onStdout: (@Sendable (String) -> Void)?,
        onStderr: (@Sendable (String) -> Void)?
    ) async throws -> CommandResult {
        let fm = FileManager.default
        try? fm.removeItem(at: session.exitFile)
        try? fm.removeItem(at: session.pidFile)
        fm.createFile(atPath: session.outFile.path, contents: Data())
        fm.createFile(atPath: session.errFile.path, contents: Data())

        let scriptURL = session.directory.appendingPathComponent("run.sh")
        try writeScript(spec, session: session, to: scriptURL)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let command = "/bin/zsh \(scriptURL.path)"
        let apple = """
        set launchedFlag to "0"
        if application "iTerm" is not running then
          tell application "iTerm" to launch
          delay 0.8
          set launchedFlag to "1"
        end if
        tell application "iTerm"
          set newWin to create window with default profile command \(appleQuote(command))
          try
            set name of current session of newWin to \(appleQuote("Runly-\(session.token)"))
          end try
          return launchedFlag & " " & ((id of newWin) as text)
        end tell
        """
        let appleURL = session.directory.appendingPathComponent("launch.applescript")
        try apple.write(to: appleURL, atomically: true, encoding: .utf8)

        let osa = Process()
        osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        osa.arguments = [appleURL.path]
        let osaOut = Pipe()
        let osaErr = Pipe()
        osa.standardOutput = osaOut
        osa.standardError = osaErr
        do {
            try osa.run()
            osa.waitUntilExit()
        } catch {
            throw CommandExecutorError.failedToStart(error.localizedDescription)
        }
        if osa.terminationStatus != 0 {
            let err = String(data: osaErr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let trimmed = err.trimmingCharacters(in: .whitespacesAndNewlines)
            throw CommandExecutorError.failedToStart(
                trimmed.isEmpty
                    ? "iTerm AppleScript failed. Allow Runly to control iTerm in System Settings → Privacy & Security → Automation."
                    : trimmed
            )
        }
        let launchOut = String(data: osaOut.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let parts = launchOut.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: \.isWhitespace)
        let launched = parts.first.map(String.init) == "1"
        let windowID = parts.dropFirst().first.flatMap { Int($0) }
        session.setWindow(id: windowID, launchedITerm: launched)

        defer { session.closeWindow() }

        let startedAt = Date()
        var outOffset: UInt64 = 0
        var errOffset: UInt64 = 0
        var sawPID = false

        while true {
            if !sawPID, fm.fileExists(atPath: session.pidFile.path) {
                sawPID = true
            }
            drain(session.outFile, offset: &outOffset, into: onStdout)
            drain(session.errFile, offset: &errOffset, into: onStderr)

            if fm.fileExists(atPath: session.exitFile.path) {
                break
            }
            if session.isCancelled || session.didTimeOut {
                try? await Task.sleep(nanoseconds: 400_000_000)
                break
            }
            if spec.timeout > 0, Date().timeIntervalSince(startedAt) > spec.timeout {
                session.markTimedOut()
                try? await Task.sleep(nanoseconds: 400_000_000)
                break
            }
            if !sawPID, Date().timeIntervalSince(startedAt) > 15 {
                throw CommandExecutorError.failedToStart("iTerm did not start the task session.")
            }
            try await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled {
                session.markCancelled()
                break
            }
        }

        drain(session.outFile, offset: &outOffset, into: onStdout)
        drain(session.errFile, offset: &errOffset, into: onStderr)

        let codeText = (try? String(contentsOf: session.exitFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let exitCode = Int32(codeText) ?? (session.didTimeOut || session.isCancelled ? 15 : 1)
        let stdout = (try? String(contentsOf: session.outFile, encoding: .utf8)) ?? ""
        let stderr = (try? String(contentsOf: session.errFile, encoding: .utf8)) ?? ""

        return CommandResult(
            exitCode: exitCode,
            timedOut: session.didTimeOut,
            cancelled: session.isCancelled,
            stdout: stdout,
            stderr: stderr,
            duration: Date().timeIntervalSince(startedAt)
        )
    }

    private static func writeScript(_ spec: CommandSpec, session: Session, to url: URL) throws {
        var lines: [String] = [
            "#!/bin/zsh",
            "set -u",
            // iTerm may SIGHUP the wrapper when the agent (foreground PTY child) exits.
            "trap '' HUP",
            "print -r -- $$ > \(shQuote(session.pidFile.path))",
            "exit_status=1",
            "write_exit() { print -r -- \"$1\" > \(shQuote(session.exitFile.path)) }",
            "trap 'write_exit \"$exit_status\"' EXIT"
        ]
        if let cwd = spec.currentDirectoryURL {
            lines.append("cd -- \(shQuote(cwd.path)) || { exit_status=1; write_exit 1; exit 1 }")
        }
        for (key, value) in spec.environment.sorted(by: { $0.key < $1.key }) {
            guard !key.isEmpty else { continue }
            lines.append("export \(key)=\(shQuote(value))")
        }
        var command = shQuote(spec.executableURL.path)
        for arg in spec.arguments {
            command += " \(shQuote(arg))"
        }
        // Direct file redirect: no process-substitution/tee, so the wrapper stays
        // the session process and always gets to write the exit file.
        lines.append("set +e")
        lines.append("\(command) >\(shQuote(session.outFile.path)) 2>\(shQuote(session.errFile.path))")
        lines.append("exit_status=$?")
        lines.append("write_exit \"$exit_status\"")
        lines.append("exit \"$exit_status\"")
        try lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func shQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleQuote(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        + "\""
    }

    private static func drain(_ url: URL, offset: inout UInt64, into handler: (@Sendable (String) -> Void)?) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: offset)
            let data = handle.readDataToEndOfFile()
            offset += UInt64(data.count)
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            handler?(text)
        } catch {
            return
        }
    }
}
