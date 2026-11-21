import Foundation

@main
struct SecretRedactorSmoke {
    static func main() {
        func check(_ ok: @autoclosure () -> Bool, _ reason: String) {
            guard ok() else { fputs("FAIL: \(reason)\n", stderr); exit(1) }
        }

        check(SecretRedactor.isSensitiveKey("OPENAI_API_KEY"), "API_KEY marked sensitive")
        check(SecretRedactor.isSensitiveKey("GH_TOKEN"), "TOKEN marked sensitive")
        check(!SecretRedactor.isSensitiveKey("PATH"), "PATH not sensitive")
        check(!SecretRedactor.isSensitiveKey("HOME"), "HOME not sensitive")

        let env = SecretRedactor.redactEnvironmentText("""
        PATH=/usr/bin
        OPENAI_API_KEY=sk-live-secret-value
        NOTE=hello
        """)
        check(env.contains("OPENAI_API_KEY=\(SecretRedactor.redactedPlaceholder)"), "env key redacted")
        check(env.contains("PATH=/usr/bin"), "non-secret env kept")
        check(env.contains("NOTE=hello"), "plain note kept")
        check(!env.contains("sk-live-secret-value"), "secret value removed from env text")

        let out = SecretRedactor.redactOutput(
            "Bearer abcdEFGH1234567890 Authorization=xyzTOKEN Authorization: abcdefghijk OPENAI_API_KEY=supersecret sk-abcdefghijklmnopqrstuvwxyz AKIAIOSFODNN7EXAMPLE xoxb-1234567890-abcdefghij ghp_abcdefghijklmnopqrstuvwxyz12"
        )
        check(out.contains("Bearer \(SecretRedactor.redactedPlaceholder)"), "bearer redacted")
        check(out.contains("OPENAI_API_KEY=\(SecretRedactor.redactedPlaceholder)"), "assignment redacted")
        check(out.contains("sk-\(SecretRedactor.redactedPlaceholder)"), "sk- token redacted")
        check(out.contains("AKIA\(SecretRedactor.redactedPlaceholder)"), "AKIA redacted")
        check(out.contains("xox-\(SecretRedactor.redactedPlaceholder)"), "slack token redacted")
        check(out.contains("gh_\(SecretRedactor.redactedPlaceholder)"), "github token redacted")
        check(!out.contains("supersecret"), "raw secret gone")

        print("PASS: secret redaction smoke checks")
    }
}
