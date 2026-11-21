import Foundation

/// Best-effort redaction for logs, notifications, and UI. Not a security boundary —
/// full command stdout may still contain secrets the child process prints.
enum SecretRedactor {
    static let redactedPlaceholder = "***"

    private static let sensitiveKeyMarkers: [String] = [
        "KEY", "TOKEN", "SECRET", "PASSWORD", "PASSWD", "PASSPHRASE",
        "AUTHORIZATION", "AUTH", "CREDENTIAL", "PRIVATE", "COOKIE",
        "SESSION", "API_KEY", "ACCESS_KEY", "CLIENT_SECRET"
    ]

    /// Env key names that should never be shown in clear text in the UI.
    static func isSensitiveKey(_ key: String) -> Bool {
        let upper = key.uppercased()
        if upper == "AUTH" || upper.hasSuffix("_AUTH") { return true }
        return sensitiveKeyMarkers.contains { marker in
            upper == marker || upper.contains("_\(marker)") || upper.hasPrefix("\(marker)_") || upper.hasSuffix("_\(marker)")
        }
    }

    /// Redact `KEY=value` lines (task environment editor / detail).
    static func redactEnvironmentText(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            let raw = String(line)
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { return raw }
            guard let eq = trimmed.firstIndex(of: "=") else { return raw }
            let key = String(trimmed[..<eq])
            guard isSensitiveKey(key) else { return raw }
            let prefix = raw.prefix(while: { $0.isWhitespace })
            return "\(prefix)\(key)=\(redactedPlaceholder)"
        }
        .joined(separator: "\n")
    }

    /// Redact free-form process output / error strings before logging or notifying.
    static func redactOutput(_ text: String) -> String {
        var result = text
        result = redactBearerTokens(in: result)
        result = redactAssignmentPatterns(in: result)
        result = redactKnownTokenShapes(in: result)
        return result
    }

    // MARK: - Private

    private static func redactBearerTokens(in text: String) -> String {
        // Bearer <token>
        let pattern = #/(?i)\bBearer\s+[A-Za-z0-9\-._~+/]+=*/#
        return text.replacing(pattern) { _ in "Bearer \(redactedPlaceholder)" }
    }

    private static func redactAssignmentPatterns(in text: String) -> String {
        // KEY=value or KEY: value when KEY looks sensitive
        let pattern = #/(?i)\b([A-Z][A-Z0-9_]{1,64})\s*([:=])\s*([^\s"'\\]{4,})/#
        return text.replacing(pattern) { match in
            let key = String(match.1)
            guard isSensitiveKey(key) else { return String(match.0) }
            return "\(key)\(match.2)\(redactedPlaceholder)"
        }
    }

    private static func redactKnownTokenShapes(in text: String) -> String {
        var result = text
        // OpenAI / similar sk-… keys
        result = result.replacing(#/\bsk-[A-Za-z0-9]{16,}\b/#) { _ in "sk-\(redactedPlaceholder)" }
        // AWS access key id
        result = result.replacing(#/\bAKIA[0-9A-Z]{16}\b/#) { _ in "AKIA\(redactedPlaceholder)" }
        // Slack bot tokens
        result = result.replacing(#/\bxox[baprs]-[A-Za-z0-9-]{10,}\b/#) { _ in "xox-\(redactedPlaceholder)" }
        // GitHub classic / fine-grained style prefixes
        result = result.replacing(#/\bgh[pousr]_[A-Za-z0-9]{20,}\b/#) { _ in "gh_\(redactedPlaceholder)" }
        return result
    }
}
