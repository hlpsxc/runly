import Foundation

enum ShellPathResolver {
    /// Common locations GUI apps often miss compared to Terminal.
    static let preferredBinaryDirectories: [String] = [
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
    ]

    static func expandedPath(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    static func resolveExecutable(_ command: String, environment: [String: String]) -> URL? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("/") {
            let expanded = expandedPath(trimmed)
            let url = URL(fileURLWithPath: expanded)
            return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
        }

        let pathValue = environment["PATH"] ?? ProcessInfo.processInfo.environment["PATH"] ?? ""
        var searchPaths = pathValue.split(separator: ":").map(String.init)
        for directory in preferredBinaryDirectories where !searchPaths.contains(directory) {
            searchPaths.append(directory)
        }

        for directory in searchPaths {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(trimmed)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Merge process environment with optional PATH augmentation (does not replace user PATH).
    static func augmentedPATH(from existing: String?) -> String {
        var parts = (existing ?? ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        for directory in preferredBinaryDirectories where !parts.contains(directory) {
            parts.append(directory)
        }
        return parts.joined(separator: ":")
    }
}

enum ArgumentParser {
    /// One argument per line. Lines are not split on spaces (preserves prompts).
    static func parse(_ text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
