import Foundation

/// Loads environment variables from the user's login shell startup files
/// (e.g. `~/.zshrc`), which GUI scheduled runs do not source.
enum LoginShellEnvironment {
    private static let lock = NSLock()
    private static var cached: [String: String]?
    private static var cachedAt: Date?
    private static let ttl: TimeInterval = 300
    private static let storageKey = "runly.mergeLoginShellEnvironment"

    /// When enabled (default), task runs merge login-shell exports such as API keys.
    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: storageKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: storageKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: storageKey)
            invalidateCache()
        }
    }

    static func invalidateCache() {
        lock.lock()
        cached = nil
        cachedAt = nil
        lock.unlock()
    }

    /// Warm the cache off the critical UI path.
    static func warmCacheInBackground() {
        guard isEnabled else { return }
        DispatchQueue.global(qos: .utility).async {
            _ = current(forceRefresh: true)
        }
    }

    static func current(forceRefresh: Bool = false) -> [String: String] {
        guard isEnabled else { return [:] }

        lock.lock()
        if !forceRefresh,
           let cached,
           let cachedAt,
           Date().timeIntervalSince(cachedAt) < ttl {
            let hit = cached
            lock.unlock()
            return hit
        }
        lock.unlock()

        let loaded = loadFromShell() ?? [:]

        lock.lock()
        cached = loaded
        cachedAt = Date()
        lock.unlock()
        return loaded
    }

    private static let skippedKeys: Set<String> = [
        "_", "PWD", "OLDPWD", "SHLVL", "PS1", "PROMPT", "PROMPT_EOL_MARK",
        "TERM_SESSION_ID", "TERM_PROGRAM", "TERM_PROGRAM_VERSION",
        "XPC_SERVICE_NAME", "XPC_FLAGS", "SECURITYSESSIONID",
        "LaunchInstanceID", "__CFBundleIdentifier", "CFBundleIdentifier"
    ]

    private static func loadFromShell() -> [String: String]? {
        let shellPath = ProcessInfo.processInfo.environment["SHELL"]
            ?? "/bin/zsh"
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent.lowercased()

        let script: String
        switch shellName {
        case "zsh":
            script = """
            source "$HOME/.zshenv" 2>/dev/null
            source "$HOME/.zprofile" 2>/dev/null
            source "$HOME/.zshrc" 2>/dev/null
            source "$HOME/.zlogin" 2>/dev/null
            /usr/bin/env -0
            """
        case "bash":
            script = """
            source "$HOME/.bash_profile" 2>/dev/null || source "$HOME/.profile" 2>/dev/null
            source "$HOME/.bashrc" 2>/dev/null
            /usr/bin/env -0
            """
        default:
            // Best-effort login shell dump (may skip interactive-only rc files).
            script = "/usr/bin/env -0"
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        if shellName == "zsh" || shellName == "bash" {
            process.arguments = ["-c", script]
        } else {
            process.arguments = ["-lc", script]
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            NSLog("Runly login shell env: failed to start %@ — %@", shellPath, error.localizedDescription)
            return nil
        }

        // Cap wait so a hanging rc file cannot block task runs forever.
        let deadline = Date().addingTimeInterval(8)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            NSLog("Runly login shell env: timed out loading %@", shellPath)
            return nil
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty else { return [:] }
        return parseNullSeparatedEnv(data)
    }

    private static func parseNullSeparatedEnv(_ data: Data) -> [String: String] {
        var result: [String: String] = [:]
        for chunk in data.split(separator: 0) {
            guard let line = String(data: Data(chunk), encoding: .utf8) else { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq])
            guard !key.isEmpty, !skippedKeys.contains(key) else { continue }
            result[key] = String(line[line.index(after: eq)...])
        }
        return result
    }
}
