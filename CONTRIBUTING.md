# Contributing to Runly

Thanks for helping improve Runly, a local-first macOS task scheduler for commands, scripts, and AI agents.

## Development setup

- macOS 14 or newer, full Xcode 15 or newer.
- Open `Runly.xcodeproj` in Xcode, choose **My Mac**, and run.
- Alternatively:
  ```bash
  xcodebuild -project Runly.xcodeproj -scheme Runly -configuration Debug -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
  ```

## Before opening a pull request

1. Open an issue first for large behavior changes, especially scheduling, subprocess execution, security, or data migration.
2. Make a focused change with a clear problem statement and reproduction steps.
3. Build on macOS, test scheduling (including sleep/wake and timezone), task cancellation, environment variables, and logs as applicable.
4. Document user-facing behavior in both `README.md` and `README-CN.md` when relevant.
5. Include before/after screenshots for UI changes and note known risks.

## Design principles

- Local-first: no required accounts or cloud services.
- Treat external commands and agent prompts as untrusted; never silently bypass approvals.
- Prefer explicit arguments over shell-string interpolation.
- Avoid storing secrets in logs; redact tokens in error reports and screenshots.
- Keep schedule timezone and missed-run semantics explicit.
- Keep new dependencies minimal.

## Reporting bugs

Include macOS and Xcode versions, exact steps, expected and actual behavior, and **redacted** logs. Do not post credentials, private files or agent transcripts containing secrets.

## License

Contributions are made under the repository's MIT License.
