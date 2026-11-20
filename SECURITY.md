# Security Policy

## Reporting a vulnerability

Please **do not open a public issue** for exploitable vulnerabilities. Use GitHub's private vulnerability reporting option (Security > Advisories > Report a vulnerability) if enabled; otherwise contact the maintainer privately using the contact method listed on their GitHub profile.

When reporting, include a reproduction, affected versions, severity, and a recommended mitigation if known. Please allow time for assessment before public disclosure.

## Threat model and known considerations

Runly executes arbitrary local programs with the current user's privileges. Treat every task, agent prompt, imported configuration, and executable path as potentially dangerous.

- Only schedule commands and AI agents you trust.
- Unattended agent execution must not implicitly enable permission-bypass flags.
- Environment variables may contain API tokens. Avoid printing them or including them in issue reports. Task logs are persisted locally.
- Shell pipelines and command strings can invoke a shell. Prefer structured executable/argument configuration where possible.
- Running in iTerm may inherit privileges granted to iTerm. Use this mode deliberately.
- Before distributing macOS binaries, validate code signing and notarization. GitHub Actions build artifacts without these steps are **unsigned testing builds**, not production-ready installers.

Security support currently follows the latest code on `main`; no formal long-term support policy is established.
