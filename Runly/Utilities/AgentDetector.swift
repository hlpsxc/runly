import Foundation

/// Local Claude Code / Codex / OpenClaw CLI discovery for setup hints.
struct AgentInstallStatus: Identifiable {
    var id: String { provider.rawValue }
    let provider: AgentProvider
    let executable: String
    let path: URL?
    let version: String?

    var isInstalled: Bool { path != nil }

    var pathDisplay: String {
        path?.path ?? "—"
    }
}

enum AgentDetector {
    /// Providers we can look up by a well-known executable name.
    static let detectableProviders: [AgentProvider] = [.claude, .codex, .openclaw]

    static func probeAll(
        environment: [String: String]? = nil,
        includeVersion: Bool = true
    ) -> [AgentInstallStatus] {
        let env = environment ?? mergedProbeEnvironment()
        return detectableProviders.map {
            probe($0, environment: env, includeVersion: includeVersion)
        }
    }

    static func probe(
        _ provider: AgentProvider,
        environment: [String: String]? = nil,
        includeVersion: Bool = true
    ) -> AgentInstallStatus {
        let env = environment ?? mergedProbeEnvironment()
        let executable = provider.defaultExecutable
        guard !executable.isEmpty else {
            return AgentInstallStatus(provider: provider, executable: executable, path: nil, version: nil)
        }
        let url = ShellPathResolver.resolveExecutable(executable, environment: env)
        let version = includeVersion ? url.flatMap { readVersion(at: $0) } : nil
        return AgentInstallStatus(provider: provider, executable: executable, path: url, version: version)
    }

    static func setupHint(for provider: AgentProvider) -> String {
        switch provider {
        case .claude:
            return L10n.tr("agent.setup.claude")
        case .codex:
            return L10n.tr("agent.setup.codex")
        case .openclaw:
            return L10n.tr("agent.setup.openclaw")
        case .custom:
            return L10n.tr("agent.setup.custom")
        }
    }

    // MARK: - Private

    private static func mergedProbeEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if LoginShellEnvironment.isEnabled {
            for (key, value) in LoginShellEnvironment.current() where env[key] == nil {
                env[key] = value
            }
        }
        env["PATH"] = ShellPathResolver.augmentedPATH(from: env["PATH"])
        return env
    }

    private static func readVersion(at url: URL) -> String? {
        let process = Process()
        process.executableURL = url
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(1.5)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return String(firstLine.prefix(120))
    }
}
